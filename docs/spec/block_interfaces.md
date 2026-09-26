# Block interfaces: first RTL blocks

> **Status:** v1 for `pe_fifo`, `pe_imem` and `pe_host_spi` (ISA-independent,
> ready to code). §3 (engine ↔ shifter) and §7 (`pe_ctrl` boundary) are
> **drafts** until `isa.md` and `host_protocol.md` are frozen at G0.
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

| When | Person 1 | Person 2 | Person 3 (host interface) |
|---|---|---|---|
| **Now** (Weeks 1–2) | `pe_fifo` RTL + SBY proof | `pe_imem` RTL + Yosys area numbers | Finalize [`host_protocol.md`](host_protocol.md); `pe_host_spi` RTL (§6) |
| **Now** (Weeks 1–2) | cocotb test for **`pe_imem`** | cocotb test for **`pe_fifo`** | cocotb SPI-master driver + `pe_host_spi` loopback test |
| **After G0** (Weeks 3–4) | `pe_engine`: PC, next-PC mux, decode, condition mux, delay counter, stall logic, clock enable. G1 subset: SET, JMP, WAIT, delay, CTRL HALT | `pe_shifter` (OSR/ISR, bit counts, direction) with its own unit tests | `sw/host/protocol.py`; `pe_ctrl` (§7) with the real FIFO/imem; top-level load-and-run test for G1 |
| **Weeks 5–6** | Engine integration and review | IN / OUT / PUSH / PULL wired into the engine with Person 1 | HPS loader tool on the DE1-SoC (ROADMAP §5.4, S4) |

Persons 1 and 2 each write the RTL for one block and the **test for the
other's**, working only from this document. A test written by someone else
doesn't share the RTL author's assumptions, so misreadings of the spec show up
as failures. Person 3 has no partner block yet; ask Person 1 or 2 to review
the `pe_host_spi` test against §6.

**Still to assign at G0:** the Python reference model from `isa.md`. It must
be written by someone other than the engine author (Person 1), so Person 2 or
Person 3. The engine's lockstep tests need it by Week 3.

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

---

## 6. `pe_host_spi`: SPI-slave receiver (host loader, physical layer)

Owner: Person 3. This block **only moves bytes**; it never interprets them
(that is `pe_ctrl`, §7). Pads per the CLAUDE.md §3 pin map: `ui_in[0]` SCLK,
`ui_in[1]` CS_N, `ui_in[2]` MOSI, `uo_out[0]` MISO. Command bytes and framing
are defined in [`host_protocol.md`](host_protocol.md).

```verilog
module pe_host_spi (
    input  wire       clk,
    input  wire       rst_n,         // synchronous, active low

    // Raw pads, asynchronous to clk: synchronized ONLY inside this module
    input  wire       sclk_pad,
    input  wire       cs_n_pad,
    input  wire       mosi_pad,
    output reg        miso,          // straight from a flop; 0 while CS_N is high

    // Byte interface to pe_ctrl (clk domain)
    output reg        frame_start,   // 1-cycle pulse: CS_N fell
    output reg        frame_end,     // 1-cycle pulse: CS_N rose (complete or aborted)
    output reg  [7:0] rx_byte,       // last complete MOSI byte (valid from the rx_valid cycle on)
    output reg        rx_valid,      // 1-cycle pulse: rx_byte just updated
    input  wire [7:0] tx_byte        // sampled when frame_start or rx_valid is high
);
```

### How it works, and why

- **SCLK is data, not a clock** (CLAUDE.md §3: one clock domain). Each pad
  goes through a 2-FF synchronizer, plus one more register to detect edges
  (`sclk_rise = sclk_s & ~sclk_prev`). This is the same pattern as
  `peripherals_blocks/UART/RX.v` (its 2-FF synchronizer and `start_edge`).
- **SCLK, CS_N and MOSI get the same synchronizer depth,** so their delayed
  copies stay aligned. In mode 0 the host changes MOSI on falling edges, so MOSI
  is stable around every rising edge. Sampling the *synchronized* MOSI in the
  cycle the *synchronized* SCLK rise is detected therefore captures the right bit.
- **Detection lag:** the chip notices any pad edge about 2–3 clk after it
  happens. Every timing rule below follows from that.

### What happens on each host event

| Host does | Chip does (≈ 3 clk later) |
|---|---|
| CS_N falls | `frame_start` pulses; `tx_byte` is sampled (byte 0 of MISO); `miso` = its bit 7 |
| SCLK rising edge *k* of a byte (k = 1…8) | Shift the synchronized MOSI bit into the RX shift register, **and** move `miso` to the next bit |
| … after rising edge 8 | `rx_byte` updated, `rx_valid` pulses; `tx_byte` is sampled in that same cycle and its bit 7 goes on `miso` |
| SCLK falling edge | Nothing |
| CS_N rises (anywhere, even mid-byte) | `frame_end` pulses; bit counter reset; partial byte discarded; `miso` = 0 |

**Why MISO changes after the *rising* edge, not the falling edge.** At the
maximum rate (SCLK = clk/8) each half-period is only 4 clk.
- If MISO changed on the *detected falling* edge, the new bit would appear
  about 3 clk after the falling edge. That is right when the host samples on
  the next rising edge, leaving 0–1 clk of margin.
- Changing it on the *detected rising* edge moves it about 3 clk after the edge
  where the host just captured the old bit. The new bit then sits stable for
  about 5 clk before the next rising edge.

Both are legal in mode 0, where the host only cares that MISO is stable at the
rising edge, but only the rising-edge choice has real margin.

**Byte-boundary contract with `pe_ctrl`:** `tx_byte` must hold the correct next
MISO byte in the cycle `frame_start` pulses (byte 0, proposed to be STATUS)
and in every cycle `rx_valid` pulses (the byte after the one just received).
`rx_byte` is already valid in that `rx_valid` cycle, so `pe_ctrl` may compute
`tx_byte` combinationally from it, or use the protocol's turnaround byte to
register it (see `host_protocol.md` §3).

### Host timing requirements

`t_clk` is the core clock period (40 ns at 25 MHz).

| Parameter | Minimum | At 25 MHz |
|---|---|---|
| SCLK high time | 4 t_clk | 160 ns |
| SCLK low time | 4 t_clk | 160 ns (so SCLK ≤ 3.125 MHz) |
| CS_N fall → first SCLK rising edge | 8 t_clk | 320 ns |
| Last SCLK falling edge → CS_N rise | 4 t_clk | 160 ns |
| CS_N high between frames | 8 t_clk | 320 ns |

The chip guarantees that MISO is stable at every host sampling edge when these
are met. Verify these numbers in simulation (below) before freezing them in
`host_protocol.md`.

### Implementation hints (author's choice)

About 40 flops: 3 × 3 sync/edge registers, a 3-bit bit counter, an 8-bit RX
shift register, an 8-bit TX shift register, and the output flops. No FSM
needed beyond "in frame / not in frame". Nothing survives CS_N high.

### Test checklist (`test/unit/pe_host_spi/`)

The test needs a **cocotb SPI-master driver**: an async function such as
`spi_xfer(dut, mosi_bytes, half_period_ns) -> miso_bytes` that toggles
`sclk_pad`, `cs_n_pad` and `mosi_pad` with `Timer`s and samples `miso` at each
rising edge, exactly like a real host. For the loopback tests, let the test
drive `tx_byte` (e.g. echo the previous `rx_byte`).

- [ ] Bytes in = `rx_byte` sequence; `rx_valid` count equals bytes sent.
- [ ] MISO bytes = the `tx_byte` values presented at `frame_start` / `rx_valid`.
- [ ] SCLK half-period **not** a multiple of `t_clk` (e.g. 173 ns with 40 ns clk) and a random start phase, repeated with several seeds.
- [ ] SCLK exactly at the maximum rate from the table above.
- [ ] **Timing check:** `miso` does not change within ±1 t_clk of any SCLK rising edge.
- [ ] CS_N raised mid-byte: no `rx_valid`, `frame_end` pulses, next frame works normally.
- [ ] Back-to-back frames with the minimum CS_N high time.
- [ ] `miso = 0` whenever CS_N is high, including after reset.

---

## 7. `pe_ctrl` boundary (draft)

Owner: Person 3. `pe_ctrl` interprets the bytes from §6 according to
[`host_protocol.md`](host_protocol.md) and holds the host-visible registers
from [diagram 03](../diagrams/03_engine_state_and_regs.svg). The **engine**
rows are a draft: agree on them with Person 1 when the engine interface is
defined at G0. Names below are suggestions.

| Neighbor | Signal | Dir (from `pe_ctrl`) | Width | Meaning |
|---|---|---|---|---|
| `pe_host_spi` | `frame_start`, `frame_end`, `rx_byte`, `rx_valid` | in | 1, 1, 8, 1 | §6 |
| | `tx_byte` | out | 8 | §6 byte-boundary contract |
| `pe_imem` | `imem_we`, `imem_waddr`, `imem_wdata` | out | 1, AW, 16 | Write port (§2). **Only while halted.** |
| | `host_raddr` | out | AW | Goes to the top-level read mux: `raddr = eng_active ? pc : host_raddr` |
| | `imem_rdata` | in | 16 | Shared read data |
| TX FIFO | `txf_push`, `txf_push_data` | out | 1, 8 | PUSH_TX bytes |
| | `txf_full`, `txf_overflow`, `txf_level` | in | 1, 1, 4 | `txf_overflow` is latched into ERROR |
| RX FIFO | `rxf_pop` | out | 1 | POP_RX: pop in the same cycle the byte is handed to `tx_byte` (show-ahead makes this work) |
| | `rxf_pop_data`, `rxf_empty`, `rxf_underflow`, `rxf_level` | in | 8, 1, 1, 4 | `rxf_underflow` is latched into ERROR |
| Engine *(draft)* | `eng_run`, `eng_halt`, `eng_step`, `eng_soft_reset` | out | 1 each | 1-cycle pulses from CTRL writes |
| | `cfg_clkdiv`, `cfg_start_pc`, `cfg_out_base`, `cfg_out_cnt`, `cfg_set_base`, `cfg_set_cnt`, `cfg_in_base`, `cfg_jmp_pin`, `cfg_od_mask`, `cfg_shift_dir` | out | 16, AW, 4, 4, 4, 4, 4, 4, 8, 2 | Config registers (writable only while halted) |
| | `eng_running`, `eng_halted`, `eng_pc`, `eng_timeout`, `eng_attn`, `eng_attn_code`, `eng_active` | in | 1, 1, AW, 1, 1, 8, 1 | STATUS / PC / ATTN_CODE sources |
| Top level → pads | `running`, `attn` | out | 1, 1 | `uo_out[1]`, `uo_out[2]` |

Rules `pe_ctrl` must enforce (details in `host_protocol.md` §5):
- `imem_we` is **never** high while `eng_running`. The write is dropped and
  `WR_WHILE_RUN` is set. This becomes a top-level formal property.
- "W (halted)" config registers ignore writes while running.
- All command state resets on `frame_end`; an incomplete command has no effect.

**Testing before the engine exists:** instantiate `pe_host_spi` + `pe_ctrl` +
real `pe_fifo` ×2 + `pe_imem` in a small test wrapper. Drive the engine inputs
(`eng_running`, …) from Python as a fake engine, and check the `eng_*` pulses
and `cfg_*` values the host commands produce.
