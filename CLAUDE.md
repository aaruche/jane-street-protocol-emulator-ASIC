# CLAUDE.md — Protocol Emulator ASIC

Guidance for anyone (human or Claude) working in this repository. Read this
before writing RTL, tests or firmware. The architectural boundaries in §3 and
§4 were agreed by the team; **crossing one needs a team decision**, recorded in
[`docs/ROADMAP.md`](docs/ROADMAP.md) §2 (Decision log).

## 1. What this project is

A small, open-source, **programmable protocol engine** for the Jane Street
protocol-emulator ASIC challenge: a tiny single-cycle CPU whose instruction set
is designed for driving/sampling pins with exact cycle timing, so that UART, SPI
and I2C are implemented **in firmware** and new protocols can be loaded after
fabrication. Inspired by RP2040 PIO and TI PRU.

Team: three grad students (Verilog / architecture / embedded C background;
learning cocotb, formal and physical design on this project). The goal is
satisfactory, well-verified work — **not** maximum features.

**Status:** pre-RTL. Spec phase. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for
the schedule and gates, [`docs/spec/`](docs/spec/) for specs, and
[`docs/diagrams/`](docs/diagrams/) for block diagrams (all v0 / provisional).

## 2. Hard constraints (from the challenge and Tiny Tapeout)

| Item | Constraint |
|---|---|
| Process | IHP SG13CMOS5L (130 nm) via Tiny Tapeout |
| Template | [`TinyTapeout/ttihp-verilog-template`](https://github.com/TinyTapeout/ttihp-verilog-template/tree/cmos5l) branch `cmos5l`, imported at the **repo root** (Week 1 task) |
| Area | `info.yaml` → `tiles: "6x4"` (24 tiles, ~0.7 mm² nominal, ~24K cells rule-of-thumb). Do not plan for 8×4 unless officially announced. |
| Top module | `tt_um_*` (provisional name: `tt_um_aaruche_protoemu`) with the standard TT ports `ui_in`, `uo_out`, `uio_in`, `uio_out`, `uio_oe`, `ena`, `clk`, `rst_n` |
| Sources | Every synthesizable file lives in `src/` and is listed in **both** `info.yaml` `source_files` and `test/Makefile` `PROJECT_SOURCES` |
| Toolchain | cocotb 2.0.1 + Icarus (template-pinned); LibreLane via the template's GitHub Actions |
| Deadline | Submit by **2027-01-18**; internal target **2027-01-10** |

Area budget (estimates only; **replace with measured synthesis numbers at G1**):

| Block | Est. cells | Notes |
|---|---|---|
| Program memory 128×16 flops + read mux | ~5K | Biggest single item; drop to 64 deep if needed |
| Engine (decode, PC, X/Y, OSR/ISR, counters) | ~3K | |
| TX/RX FIFOs 8×8 each | ~0.7K | |
| Host SPI loader + control/status | ~1K | |
| Pin block (8 bidir + sync) | ~0.3K | |
| **Total** | **~10K** | ~40% of budget; the rest is margin for routing/CTS, and possibly a 2nd engine |

## 3. Architectural boundaries (decided)

**Clocking and reset**
- **One clock domain**: TT `clk`. No derived, divided or gated clocks. Slower
  rates use **clock enables**.
- `rst_n` passes through a 2-FF reset synchronizer at the top; every flop uses
  **synchronous active-low reset** (`always @(posedge clk) if (!rst_n) ...`),
  matching the existing UART code.
- Every pad input (`ui_in`, `uio_in`, host SPI lines) passes through a 2-FF
  synchronizer **in exactly one place** (pin block / host loader). No other
  module samples pads directly.

**Engine**
- **Single-cycle, unpipelined.** One instruction per (enabled) clock plus its
  delay field. No hazards, no flush logic, no speculation.
- Every instruction's cycle count is a **fixed function of its encoding**, except
  documented stalls: `WAIT` (until condition or timeout), `PULL` on empty TX
  FIFO, `PUSH` on full RX FIFO.
- A stalled instruction has **no side effects** until the cycle it completes
  (formal property).
- `NUM_ENGINES` is a parameter; **one engine is taped out**. The engine is a
  self-contained module (own PC, registers, FIFO ports), so a second instance
  is a top-level change plus one more imem read port.
- Datapath 8-bit; loop/delay counters 16-bit; FIFOs 8 entries × 8 bits. All sizes
  are parameters.

**Program memory**
- **Flip-flop array**, `IMEM_DEPTH` × 16 (target 128), **combinational read**
  (this is what makes single-cycle possible). **No SRAM macro**.
- Written **only** by the host loader and **only while the engine is halted**;
  writes while running are rejected and flagged in status.
- Not reset (saves area). Contents are undefined until loaded; the model treats
  them as X.

**Protocol logic**
- **Protocol behavior lives only in firmware.** No UART/SPI/I2C peripheral
  blocks in `src/`.
- The only fixed protocol block is the **host loader: SPI slave, mode 0, MSB
  first**, oversampled in the core clock domain (SCLK ≤ clk/8). No UART loader.
- Host command set: imem write / imem read, control (run / halt / single-step /
  soft reset), status (running, halted, PC, error flags, FIFO levels), TX-FIFO
  push, RX-FIFO pop. Exact encoding: `docs/spec/host_protocol.md` (G0
  deliverable).

**Pins**
- `uio[7:0]` = 8 bidirectional protocol pins, each with output value, output
  enable and an **open-drain mode that never drives 1** (for I2C).
- After reset: engine halted, all `uio_oe = 0`, all engine outputs 0.
- Provisional pin map (frozen in `info.yaml` at G1):

| Pin | Use |
|---|---|
| `ui[0]` / `ui[1]` / `ui[2]` | Host SPI `SCLK` / `CS_N` / `MOSI` |
| `ui[7:3]` | Engine input-only pins `IN0`–`IN4` |
| `uo[0]` | Host SPI `MISO` |
| `uo[1]` / `uo[2]` | `RUNNING` / `ATTN` (host should service FIFOs or read an error) |
| `uo[7:3]` | Engine output-only pins `OUT0`–`OUT4` |
| `uio[7:0]` | Engine bidirectional protocol pins `P0`–`P7` |

## 4. Out of scope (do not add without a team decision)

Pipelining, caches, SRAM macros, interrupts, multiple clock domains, a C
compiler for the engine, fixed UART/SPI/I2C peripheral blocks, USB or Ethernet
PHY-like hardware, a UART host loader, and SystemVerilog-only constructs in
`src/`. Stretch goals (see ROADMAP) are **firmware-only** unless the team
decides otherwise at G4.

## 5. Repository layout (target)

```
info.yaml               TT project config (tiles "6x4")          [Week 1]
src/                    synthesizable RTL only; project.v = tt_um_* pin mapping
  config.json           LibreLane config from the template
test/                   cocotb (template Makefile, tb.v, test_*.py)
  model/                Python reference model (ISA interpreter) — the golden
formal/                 SymbiYosys .sby files (+ formal-only wrappers)
sw/asm/                 Python assembler
sw/firmware/            protocol programs (UART, SPI, I2C, ...)
sw/host/                host loader library; protocol.py shared by cocotb and HPS
fpga/de1soc/            Quartus project, FPGA top wrapper, HPS scripts
docs/ROADMAP.md         schedule, gates, decision log
docs/spec/              ISA, timing table, host protocol
docs/diagrams/          Excalidraw block diagrams
docs/reference/         datasheets and background PDFs
docs/info.md            TT datasheet page (from template)
peripherals_blocks/     LEARNING SANDBOX (standalone UART). Not submitted.
```

`peripherals_blocks/` is the team's warm-up UART. **Never reference it from
`src/`, and never copy it into `src/`**: that would violate §3 "Protocol logic".
It may be used as a peer/checker in a testbench or FPGA loopback.

## 6. RTL conventions

- Verilog-2005 (must pass Yosys, Icarus and Verilator lint). Start every file
  with `` `default_nettype none ``.
- One module per file; the filename equals the module name. Non-top modules are
  prefixed `pe_` (e.g. `pe_engine`, `pe_imem`, `pe_fifo`, `pe_host_spi`,
  `pe_pins`).
- Nonblocking (`<=`) in clocked blocks; blocking (`=`) in `always @(*)` with
  defaults assigned first, so there are no latches.
- No `initial` blocks or `#` delays in `src/` (formal-only code excepted, inside
  `` `ifdef FORMAL ``).
- Explicit widths on every constant and port; sizes come from parameters.
- Comment the *why* and the interface rules (the style used in
  `peripherals_blocks/UART/TX.v` is good).

## 7. Verification conventions

- **The Python model in `test/model/` is the golden reference.** It is written
  from the spec by someone other than the RTL author, and reviewed.
- Every ISA feature lands with: a spec update → a model update → a cocotb test
  → the RTL change. The spec comes first.
- Engine tests compare RTL against the model **cycle by cycle** (PC and pins),
  not just final results.
- Protocol tests check **edge timing** (cycles between edges, setup/sample
  points), not only received bytes.
- Random tests must log and accept a seed; a failure is reproducible from its
  seed.
- Formal: SymbiYosys from OSS CAD Suite, immediate `assert` / `assume` /
  `cover` inside `` `ifdef FORMAL `` with a `f_past_valid` guard for `$past`.
  Record for every proof: assumptions, depth, and whether it is **bounded (BMC)
  or unbounded (prove)**.
- **Never weaken an assertion, delete a test or add a waiver just to get
  green.** Understand the counterexample first.

## 8. Commands

Commands marked *planned* do not exist until the named milestone.

```sh
# RTL simulation (cocotb + Icarus)                          [after Week 1]
cd test && make -B
# Gate-level simulation (netlist from the gds workflow)     [after Week 1]
cd test && make -B GATES=yes
# Lint                                                       [planned, G1]
verilator --lint-only -Wall -Isrc src/*.v --top-module tt_um_aaruche_protoemu
# Formal (writes into build/)                                [planned, G2]
sby -f formal/pe_fifo.sby -d build/formal/pe_fifo
# Assemble firmware                                          [planned, G1]
python3 sw/asm/pasm.py sw/firmware/uart_tx.pasm -o build/uart_tx.hex
# Waveforms
gtkwave test/tb.fst      # or surfer
```

## 9. Physical design rules

- The template's CI `gds` workflow (build → precheck → gl_test) is the source
  of truth. Local hardening follows the
  [TT local hardening guide](https://www.tinytapeout.com/guides/local-hardening/).
- Log every significant build in `docs/pd_log.md`: commit, cell count/area,
  utilization, worst setup/hold slack, corners, precheck status.
- Never add timing exceptions, disable checks, or edit `src/config.json` below
  its "DO NOT CHANGE" line to get a pass. Setup failures can be fixed by
  simplifying logic or lowering the declared clock; hold failures cannot be fixed
  by lowering the clock.
- Run the flow early and after every significant change (memory size, engine
  features, pin map).

## 10. How Claude should work in this repo

- This is a **learning project**: explain and review rather than bulk-generate.
  When asked to write RTL, keep modules small and explain the design choices.
- Before crossing any boundary in §3/§4, stop and ask.
- Spec first: if a change alters instruction behavior or timing, update
  `docs/spec/` and the model before touching RTL.
- Match the team's habit of marking AI-assisted work in commit messages
  ("(ai assisted)"); a human owner reviews it.
- Keep diagrams in `docs/diagrams/` in sync when the architecture changes.
- Do not modify `peripherals_blocks/` unless asked.
