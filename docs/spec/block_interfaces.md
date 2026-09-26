# Block interfaces: first RTL blocks

> **Status:** v1 for `pe_fifo` and `pe_imem` (ISA-independent, ready to code).
> §3 (engine ↔ shifter) is a **draft** until `isa.md` is frozen at G0.
> This file is the contract: the RTL author and the test author both work
> **only from this text**. If something here is ambiguous, fix the text first
> (and tell your partner), then the code. Boundaries: [`../../CLAUDE.md`](../../CLAUDE.md) §3.

---

## 1. `pe_fifo`: show-ahead synchronous FIFO

Used twice: TX FIFO (host → engine) and RX FIFO (engine → host), see
[diagram 01](../diagrams/01_chip_top.svg).

```verilog
module pe_fifo #(
    parameter integer WIDTH   = 8,
    parameter integer DEPTH   = 8,                   // power of 2, >= 2
    parameter integer LEVEL_W = $clog2(DEPTH + 1)    // derived: do not override
) (
    input  wire               clk,
    input  wire               rst_n,       // synchronous, active low

    input  wire               push,
    input  wire [WIDTH-1:0]   push_data,
    input  wire               pop,

    output wire [WIDTH-1:0]   pop_data,    // valid whenever !empty (show-ahead)
    output wire               full,
    output wire               empty,
    output wire [LEVEL_W-1:0] level,       // 0 .. DEPTH
    output reg                overflow,    // 1-cycle pulse: push rejected (was full)
    output reg                underflow    // 1-cycle pulse: pop ignored (was empty)
);
```

### Behavior

"Full", "empty" and "level" below always mean the value at the **start** of
the cycle, i.e. the registered state before the clock edge.

| Situation | Result after the clock edge |
|---|---|
| Reset (`rst_n = 0`) | `level = 0`, `empty = 1`, `full = 0`, pointers = 0, `overflow = underflow = 0`. The storage array is **not** reset. |
| `push`, not full | `push_data` stored at the tail; `level + 1` |
| `push`, full | Push **rejected**, contents unchanged; `overflow` = 1 for one cycle |
| `pop`, not empty | Head entry removed; `level − 1` |
| `pop`, empty | Ignored; `underflow` = 1 for one cycle |
| `push` + `pop`, neither full nor empty | Both accepted; `level` unchanged; order preserved |
| `push` + `pop`, **full** | Pop accepted, push **rejected** (`overflow` pulses). There is deliberately no pass-through; it's a simpler rule to verify. |
| `push` + `pop`, **empty** | Push accepted, pop ignored (`underflow` pulses) |

Outputs:
- `pop_data = mem[rd_ptr]`, **combinational** from the storage flops. It is
  valid whenever `empty = 0`, and don't-care when empty.
- `full = (level == DEPTH)`, `empty = (level == 0)`. They are derived from
  registered state only, never from this cycle's `push`/`pop`.
- `level` needs `DEPTH + 1` distinct values (0..8 for DEPTH = 8), so it is
  **4 bits**, not 3. This is the classic off-by-one.

**Why show-ahead (first-word-fall-through):** the engine is single-cycle
(decision D1). `PULL` must read the byte **and** pop it in the same cycle. A
FIFO that presents data one cycle *after* `pop` would add a hidden cycle to
every PULL and break the timing rules in `isa.md`.

### Implementation hints (author's choice)

- Registers: `rd_ptr`, `wr_ptr` (`$clog2(DEPTH)` bits, wrap naturally because
  DEPTH is a power of 2) plus a `level` counter. Using the counter for
  full/empty avoids the "extra pointer bit" trick and gives you `level` for
  free.
- Storage: `reg [WIDTH-1:0] mem [0:DEPTH-1];` written in a clocked block with
  no reset.

### Test checklist (written by the partner, `test/unit/pe_fifo/`)

- [ ] Reset values of every output.
- [ ] Fill to full: `level` counts 1..8, then `full = 1`; one more push → `overflow` pulse, contents unchanged.
- [ ] Drain to empty: data comes out in order; one more pop → `underflow` pulse.
- [ ] `pop_data` is visible **before** `pop` (show-ahead) once not empty.
- [ ] Simultaneous push + pop at level 0, at a middle level, and at full.
- [ ] `level` checked every cycle, not just at the end.
- [ ] Seeded random push/pop for ≥ 10,000 cycles against a Python `collections.deque` model; the seed is printed.

### Formal checklist (RTL author, `formal/pe_fifo.sby`)

- [ ] `full == (level == DEPTH)`, `empty == (level == 0)`, never `full && empty`.
- [ ] `level` equals a shadow counter of accepted pushes minus accepted pops.
- [ ] Ordering: the "two tagged values" technique. Let the solver pick any two
      values pushed in order (A then B) and assert B is never popped before A.
- [ ] `cover`: reach full, and reach empty after having been full.
- [ ] Inject one bug (e.g. accept a push when full), run, and read the counterexample.

---

## 2. `pe_imem`: flip-flop program memory

```verilog
module pe_imem #(
    parameter integer DEPTH = 128,                   // power of 2
    parameter integer WIDTH = 16,
    parameter integer AW    = $clog2(DEPTH)          // derived: do not override
) (
    input  wire             clk,

    // Write port: driven only by pe_ctrl
    input  wire             we,
    input  wire [AW-1:0]    waddr,
    input  wire [WIDTH-1:0] wdata,

    // Read port: shared by the engine (PC) and host readback
    input  wire [AW-1:0]    raddr,
    output wire [WIDTH-1:0] rdata          // = mem[raddr], combinational
);
```

### Behavior

| Situation | Result |
|---|---|
| `we = 1` at a clock edge | `mem[waddr] <= wdata`; no other address changes |
| `we = 0` | Nothing changes |
| Read | `rdata = mem[raddr]` **combinationally**, in the same cycle (this is what makes the single-cycle engine possible) |
| Read the address being written this cycle | Returns the **old** value until the clock edge, then the new one |
| After power-up, before any write | Contents undefined (X in simulation) |

- **No `rst_n` port.** This is the documented exception in CLAUDE.md §3: the
  array is not reset, to save area. The loader must write every address a
  program uses.
- **One shared read port.** The address mux lives **outside** this module, in
  the top level or `pe_ctrl`:
  `raddr = engine_active ? pc : host_readback_addr`.
  Host readback is only allowed while halted, so the two never collide. A
  second read port would cost another 128:1 × 16 mux (~2K cells, ~8% of the
  area budget) just for a debug feature.
- **"No write while running"** is enforced in `pe_ctrl` (a single enforcement
  point), not here. It is checked by a formal property at top level later.

### Test checklist (written by the partner, `test/unit/pe_imem/`)

- [ ] Write a unique value to every address, then read every address back.
- [ ] A write does not disturb any other address.
- [ ] `we = 0` with changing `waddr`/`wdata` changes nothing.
- [ ] Read-during-write to the same address: old value before the edge, new value after.
- [ ] `rdata` follows `raddr` with **no** clock edge in between (combinational read).
- [ ] Seeded random writes/reads against a Python list model.

### Area task (RTL author)

Get the first real area number for G1. Yosys generic synthesis is enough for
relative sizing:

```sh
yosys -p "read_verilog src/pe_imem.v; chparam -set DEPTH 64 pe_imem; synth -top pe_imem; stat"
yosys -p "read_verilog src/pe_imem.v; synth -top pe_imem; stat"          # DEPTH 128
```

Record both cell counts in `docs/pd_log.md` (create it). They feed the
`IMEM_DEPTH` decision.

---

## 3. Draft: `pe_engine` ↔ `pe_shifter` seam (finalize at G0)

After G0 the engine is split into two files with **one owner each**: the
decoder/control in `pe_engine`, and the OSR/ISR datapath in `pe_shifter`,
instantiated by `pe_engine`. The signal list below is a **starting point
only**; fix names, widths and exact semantics once `isa.md` is frozen.

| Signal | Dir (from `pe_engine`) | Width | Candidate meaning |
|---|---|---|---|
| `osr_load` | out | 1 | Load OSR from `osr_load_data` (PULL, MOV OSR); reset bit count to full |
| `osr_load_data` | out | 8 | Byte to load |
| `osr_shift` | out | 1 | Shift `shift_n` bits out (OUT) |
| `shift_n` | out | 4 | Bit count for OUT/IN (1–8) |
| `osr_out_bits` | in | 8 | The bits shifted out this cycle (right-aligned) |
| `osr_empty` | in | 1 | No bits left (for `JMP !OSRE`) |
| `isr_shift` | out | 1 | Shift `shift_n` bits in (IN) |
| `isr_in_bits` | out | 8 | Bits to shift in (right-aligned) |
| `isr_clear` | out | 1 | Clear ISR and its count (after PUSH) |
| `isr_data` | in | 8 | ISR contents (for PUSH, MOV) |
| `shift_dir` | out | 2 | OSR / ISR LSB- or MSB-first (from SHIFT_CFG) |
| `en` | out | 1 | Engine clock enable; the shifter updates only when high |

---

## 4. Work split

| When | Person 1 | Person 2 |
|---|---|---|
| **Now** (Weeks 1–2) | `pe_fifo` RTL + SBY proof | `pe_imem` RTL + Yosys area numbers |
| **Now** (Weeks 1–2) | cocotb test for **`pe_imem`** | cocotb test for **`pe_fifo`** |
| **After G0** (Weeks 3–4) | `pe_engine`: PC, next-PC mux, decode, condition mux, delay counter, stall logic, clock enable. G1 subset: SET, JMP, WAIT, delay, CTRL HALT | `pe_shifter` (OSR/ISR, bit counts, direction) with its own unit tests |
| **Weeks 5–6** | Engine integration and review | IN / OUT / PUSH / PULL wired into the engine with Person 1 |

Each person writes the RTL for one block and the **test for the other's**,
working only from this document. A test written by someone else doesn't share
the RTL author's assumptions, so misreadings of the spec show up as failures.
Meanwhile the third teammate writes the Python reference model from `isa.md`;
the engine's lockstep tests need it.

---

## 5. Per-block definition of done

1. RTL in `src/pe_<block>.v`, following CLAUDE.md §6 (Verilog-2005,
   `` `default_nettype none ``, one module per file, synchronous active-low reset).
2. `verilator --lint-only -Wall src/pe_<block>.v` is clean.
3. The partner's cocotb test in `test/unit/pe_<block>/` passes (own
   `Makefile`: `SIM = icarus`, `TOPLEVEL = pe_<block>`,
   `COCOTB_TEST_MODULES = test_pe_<block>`).
4. FIFO only: the SBY proof passes, **and** one deliberately injected bug was
   caught and its counterexample inspected.
5. Pull request reviewed by the partner; any AI-assisted commit is tagged
   "(ai assisted)".
