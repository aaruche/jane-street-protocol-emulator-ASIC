# Roadmap: Protocol Emulator ASIC

*Replaces the earlier `Docs/astra_plan.md`. Last revised 2026-09-26.*
Architectural boundaries and coding rules live in [`../CLAUDE.md`](../CLAUDE.md).

---

## 1. Goal and definition of done

**One programmable protocol engine, verified credibly, that fits 6×4 tiles on
IHP SG13CMOS5L and runs UART, SPI and I2C purely from loaded firmware.**

The central demo, on unchanged hardware (simulation, then FPGA):

> load UART firmware → demo UART → load SPI firmware → demo SPI → load I2C firmware → demo I2C

### Scope

| Level | Contents |
|---|---|
| **Baseline (must ship)** | UART 8N1 TX + RX (half-duplex: one direction at a time), e.g. 9600 and 115200 baud. SPI controller, mode 0 (modes 1–3 as firmware-only variants). I2C controller: 7-bit addressing, read/write, ACK/NACK, repeated START, clock stretching, stuck-bus timeout. SPI-slave host loader. |
| **Stretch (firmware-only, only after G3)** | Logic-analyzer / protocol-sniffer mode, PS/2, JTAG or SWD, UART at unusual baud rates. A **2nd engine** only if G4 synthesis shows area < ~50% used. |
| **Excluded** | USB, 10M Ethernet, CAN in hardware; pipelines, caches, SRAM macros, interrupts; UART loader; C compiler for the engine. |

"Satisfactory" means that each baseline item has spec, model, cocotb tests,
FPGA evidence and a clean GDS. It does not mean more protocols.

---

## 2. Decision log

| # | Date | Decision | Why |
|---|---|---|---|
| D1 | 2026-09-26 | **Single-cycle, unpipelined engine**; fixed cycles per instruction, stalls only on WAIT/PULL/PUSH | Deterministic timing is the product. No hazards means less to verify, and the model is trivially cycle-exact. |
| D2 | 2026-09-26 | **Flip-flop program memory**, combinational read, `IMEM_DEPTH` param (target 128×16); no SRAM | An SRAM's synchronous read would force a fetch stage (breaking D1), and the SRAM integration path is a risk. |
| D3 | 2026-09-26 | **cocotb 2.0.1 + Icarus**; **Verilator `--lint-only`** | Icarus is the template default and what the gate-level CI uses; Verilator lint is fast and strict. |
| D4 | 2026-09-26 | **Formal with SymbiYosys** (OSS CAD Suite), immediate assertions | Free; no JasperGold license available. |
| D5 | 2026-09-26 | **SPI-slave loader only** | One loader to verify; easy to bit-bang from the DE1-SoC HPS and from the TT demo board's microcontroller. |
| D6 | 2026-09-26 | **1 engine taped out**, `NUM_ENGINES` parameter | Keeps scope small but leaves a cheap upgrade path if area allows. |
| D7 | 2026-09-26 | **DE1-SoC HPS Linux is the remote test host** | The HPS programs the FPGA and bit-bangs the loader; this teaches embedded Linux, SSH and HW-in-the-loop testing. |
| D8 | 2026-09-26 | **Remote access via campus VPN** (Tailscale as fallback only) | Team preference; confirm with IT that the lab subnet is reachable over VPN. |
| D9 | 2026-09-26 | Verilog-2005 (not Hardcaml / SystemVerilog) in `src/` | Team expertise; runs on every open-source tool. |

Add a row whenever a boundary in `CLAUDE.md` §3/§4 changes.

---

## 3. Team roles

| Who | Owns | Reviews |
|---|---|---|
| **A: architecture and firmware** | ISA + timing spec, engine RTL, assembler, UART/SPI/I2C firmware | B's model and timing tests |
| **B: verification** | cocotb environment, Python reference model, formal proofs, regressions, random tests | A's instruction semantics; host-protocol corner cases |
| **C: integration and physical** | Host SPI loader, top/pin block, TT template + CI, `pd_log.md`, Quartus/DE1-SoC top, HPS loader tool | Reset, I/O behavior, clock assumptions |
| **Board owner (side track)** | DE1-SoC Linux, SSH, campus-VPN access, remote scripts | Never blocks a gate |

Ownership is not isolation. By G4 **everyone** must be able to: run the full
regression, read a formal counterexample, load firmware on the FPGA, and explain
one real timing path from the STA report.

Suggested cadence: one 45-minute sync per week (demo what passed, look at one
waveform or report together, update the gate checklist).

---

## 4. Timeline and gates

Weeks start on Mondays. A gate is passed when its exit condition is demonstrated
to the other two teammates, not when the code is "mostly done".

### Weeks 1–2 (Sep 28 – Oct 11): Toolchain, learning, spec

- **Everyone:** install OSS CAD Suite (yosys, sby, solvers, iverilog, verilator,
  gtkwave) and a Python venv with `cocotb==2.0.1`, or use the template's
  `.devcontainer`. Run the template's example test.
- **C:** import the CMOS5L template at the repo root; set `tiles: "6x4"`, the top
  name and a stub design; get the `gds`, `test` and precheck workflows green;
  open the GDS viewer; find the area, utilization and timing reports; create
  `docs/pd_log.md`.
- **B:** port `peripherals_blocks/UART/sim/tb_TX.v` to cocotb, working against a
  design whose behavior you already know. Then prove a small counter with SBY,
  inject a bug, and read the counterexample trace.
- **A:** replace `docs/spec/isa_v0_strawman.md` with `docs/spec/isa.md`
  (encoding, per-instruction cycle count, pin-update and sample points,
  behavior when stalled) and a hand trace of a 10-instruction pulse program.
- **B + A:** Python model skeleton that runs that trace.
- **RTL warm-up (two people, ISA-independent):** `pe_fifo` and `pe_imem` per
  [`spec/block_interfaces.md`](spec/block_interfaces.md). Each person writes
  one block's RTL and the cocotb test for the **other** block; FIFO gets the
  first SBY proof; imem gets the first Yosys area numbers.
- **Person 3 (host interface):** finalize the skeleton
  [`spec/host_protocol.md`](spec/host_protocol.md) (command bytes, register
  bits, error rules); build `pe_host_spi` and a cocotb SPI-master driver per
  [`spec/block_interfaces.md`](spec/block_interfaces.md) §6. Learn from the
  2-FF synchronizer and edge detection in `peripherals_blocks/UART/RX.v`.
- **Board owner:** S1 and the IT question in S2 (see §5.4).

**G0 (Oct 11):** everyone has run a cocotb test and an SBY proof (pass and
fail); CI green on the 6×4 stub; ISA, timing table and host protocol specs
reviewed by all three.

### Weeks 3–4 (Oct 12 – 25): Minimal engine + loader

- Engine subset: `SET`, `JMP` (unconditional + 1–2 conditions), delay field,
  `WAIT pin`, `HALT`; program memory; PC.
- Engine split (one owner per file, see
  [`spec/block_interfaces.md`](spec/block_interfaces.md) §3–4): Person 1 owns
  `pe_engine` (PC, decode, next-PC, stall, delay); Person 2 owns `pe_shifter`
  (OSR/ISR), integrated at G2. Freeze the seam signal table at G0.
- SPI-slave loader (Person 3): `pe_ctrl` per
  [`spec/block_interfaces.md`](spec/block_interfaces.md) §7 (imem
  write/readback, run, halt, single-step, status, FIFO push/pop), tested with
  the real `pe_fifo`/`pe_imem` and a fake engine until the engine is ready.
- Assembler v0 (`sw/asm/`); `sw/host/protocol.py` (command encoding, Person 3).
- cocotb: host driver that uses `protocol.py`; lockstep compare of PC and pins
  against the model every cycle.
- First full GDS run of the real design; first `pd_log.md` entry with measured
  imem area (revisit `IMEM_DEPTH` now).
- Quartus: DE1-SoC top wrapper compiles; HPS prototype toggles one PIO pin.

**G1 (Oct 25):** two different programs load, read back and run through the SPI
loader in cocotb, matching the model cycle for cycle. The design passes
GDS + precheck at 6×4. Pin map frozen in `info.yaml`.

### Weeks 5–6 (Oct 26 – Nov 8): Datapath + UART

- X/Y registers, OSR/ISR shift registers, `IN`, `OUT`, `PUSH`, `PULL`,
  TX/RX FIFOs, `WAIT` with timeout, `MOV`.
- UART TX and RX firmware.
- Formal: FIFO (occupancy + ordering), delay completes on the specified cycle,
  stalled instruction has no side effects.
- HPS loader tool (C, `mmap` of the lightweight bridge, which drives PIO lines
  to the real SPI loader in the FPGA).

**G2 (Nov 8):** UART passes pin-level tests: back-to-back frames, random input
phase, framing error, documented baud tolerance (target ±2%). UART demo on the
DE1-SoC talking to a USB-UART adapter, with firmware loaded from the HPS.

### Weeks 7–8 (Nov 9 – 22): SPI + I2C

- SPI firmware: mode 0, then modes 1–3 as firmware variants (this shows off
  flexibility for free).
- I2C firmware using open-drain pins, with a cocotb I2C target model that ACKs
  and NACKs, stretches the clock, and can hold SDA low (stuck bus).
- FPGA demos start with real parts (e.g. an I2C EEPROM or sensor, SPI flash).

**G3 (Nov 22):** all three protocols pass in simulation, including **one test
that loads UART → SPI → I2C firmware into the same DUT instance** (the central
demo in sim).

### Weeks 9–10 (Nov 23 – Dec 6): Evidence + hardening

- FPGA demos for all three protocols, with scope or logic-analyzer captures
  saved in `docs/evidence/`.
- Error, reset and timeout tests; loader error recovery.
- Constrained-random program generator vs model (random legal programs,
  lockstep compare). This is the random-constrained / AI-assisted verification
  story: AI can propose programs and properties, and the model decides
  pass/fail.
- Remaining formal: reset/halt → all `uio_oe = 0`; open-drain pins never drive
  1; imem is never written while running.
- Gate-level sim passing in CI.
- **Stretch decision:** 2nd engine (only if area < ~50%), or one firmware-only
  extra (sniffer mode first).

**G4 (Dec 6): feature freeze.** After this, only bug fixes, verification and
physical closure.

### Weeks 11–12 (Dec 7 – 20): Closure (exam season, so plan light)

Timing and area closure, gate-level regressions, precheck clean, and the
`docs/info.md` datasheet (pinout, how to load firmware, example programs).

**G5 (Dec 20):** release candidate. `test`, `gds`, precheck and `gl_test` are
all green on one commit.

### Weeks 13–15 (Dec 21 – Jan 10): Reproduce and package

Contingency. A teammate who **did not** build a given part reproduces the whole
flow (tests, formal, GDS, FPGA demo) from a clean checkout using only the docs.
Assemble the evidence pack.

**G6 (Jan 10):** submission-ready release tag.

### Jan 11 – 18: Buffer

Submission-blocking fixes only.

---

## 5. Learning tracks

### 5.1 cocotb (owner B; everyone does steps 1–3)

Use the **v2.0.1 docs**. Many tutorials online are cocotb 1.x and differ in
details (for example `Clock(..., unit="us")`).

1. Clock, reset, drive inputs, `assert` on outputs (the template's `test.py`).
2. Sampling correctly: when a value is visible after `RisingEdge` vs `ReadOnly`.
3. Reusable async driver functions (`spi_write_word`, `uart_expect_byte`).
4. Concurrent monitors with `cocotb.start_soon` (protocol monitor + scoreboard).
5. Seeded randomness, timeouts (`with_timeout`), and useful failure logs.

Testbench shape: **one host driver, one reference model, one scoreboard,
protocol peers/monitors** (UART, SPI target, I2C target).

### 5.2 Formal (owner B; everyone runs at least one)

Tools: SymbiYosys + Yosys + a solver (Yices / Bitwuzla / Boolector), all in
the OSS CAD Suite. Start from the
[SBY docs](https://yosyshq.readthedocs.io/projects/sby/en/latest/) and use
**immediate** assertions in `` `ifdef FORMAL `` blocks. Don't assume full
concurrent-SVA support in the open-source frontend.

Ladder: counter → FIFO → engine properties. For **every** property: get a
pass → inject a bug → read the counterexample → add a `cover` that proves the
interesting case is reachable → write down the assumptions and whether it is
bounded or unbounded.

Target proof groups (5):

1. The delay/loop counter completes on exactly the specified cycle.
2. FIFO occupancy, full/empty and accept/reject behavior.
3. FIFO data ordering is preserved.
4. A stalled instruction does not advance the PC or duplicate side effects.
5. Reset/halt: `uio_oe = 0`; open-drain pins never drive 1; no imem write
   while running.

A handful of understood proofs is a good contribution. A whole-chip proof is
out of scope.

### 5.3 Physical design (owner C; everyone explains one report)

Walk the template CI's reports stage by stage, using **your own** design:

| Stage | What to understand |
|---|---|
| Synthesis | Cell count/area; how the imem and its read mux map; unexpected latches or huge muxes |
| Floorplan | Die area, utilization, `PL_TARGET_DENSITY_PCT` |
| Placement | Congestion, where the imem lands |
| CTS | Clock buffers added, skew |
| Routing / extraction | Wire RC, congestion overflow |
| STA | Setup/hold slack, the critical path (expect: PC → imem read mux → decode → next-PC) |
| DRC / LVS | Geometry rules; layout matches netlist |
| Precheck | Tiny Tapeout integration rules |

Keep `docs/pd_log.md` with one row per significant build: commit, cells,
utilization, WNS/WHS, corners, precheck. In weekly syncs, explain **one real
timing path**.

Rules of thumb: if memory dominates, shrink it or compact the firmware. If a
path is too slow, simplify it or declare a lower clock (10–25 MHz is plenty for
the baseline protocols). If routing is congested, reduce logic before raising
density. **Never hide failures with exceptions.**

### 5.4 DE1-SoC remote test host + SSH (board owner; C helps with FPGA parts)

This track never blocks a chip gate. The in-lab FPGA flow keeps working
without it.

| Step | Target week | What | Done when |
|---|---|---|---|
| **S1** | 1–2 | Flash a Terasic DE1-SoC Linux image to microSD; boot; log in over the USB-UART serial console (115200); bring up Ethernet; create 3 user accounts; `sshd` with **key-only** auth (`PasswordAuthentication no`, `PermitRootLogin no`) | All three can `ssh` from the lab LAN |
| **S2** | 1–3 | Ask campus IT whether the lab subnet is reachable from the campus VPN. Get a DHCP reservation/static IP. Add a shared `~/.ssh/config` host alias. *Fallback if IT says no:* Tailscale | All three can `ssh` from home over VPN |
| **S3** | 3–5 | On a laptop, Quartus Prime Lite builds `.sof` and converts it to `.rbf`; `scp` it to the board; load it through the HPS **FPGA manager** (method depends on the image's kernel; set the MSEL switches per the DE1-SoC manual). Start from Terasic's GHRD (HPS + lightweight bridge + PIO). Script: `fpga/de1soc/scripts/program.sh` | One command programs the FPGA remotely. *Fallback:* local USB-Blaster |
| **S4** | 5–8 | HPS loader tool: C program `mmap`s the lightweight bridge and bit-bangs the SPI loader through PIO lines; command encoding shared with cocotb via `sw/host/protocol.py` | `ssh board 'pe-host load uart_tx.hex && pe-host run'` works |
| **S5** *(optional)* | 8+ | USB logic analyzer (sigrok-compatible) on the HPS USB port; `sigrok-cli` with UART/SPI/I2C decoders | Remote decoded captures saved to `docs/evidence/` |

Security basics: key-only SSH, no shared passwords, no services exposed beyond
the VPN, and keep the board image's packages updated where possible.

---

## 6. Verification plan (summary)

| Level | Required scenarios | Timing checked? |
|---|---|---|
| Blocks | Counter boundaries, shifts, reset, FIFO empty/full, simultaneous push/pop | Yes (cycle of flag changes) |
| Instructions | Every instruction; both branch outcomes; WAIT hit/timeout; stalls; exact pin-update cycle | Yes (lockstep with model) |
| Host loader | Load / readback / run / halt / step / reset; write-while-running rejected; malformed frames; SCLK at max rate | Yes |
| UART | Known patterns, back-to-back, random input phase, framing error, baud tolerance | Yes (bit widths, sample point) |
| SPI | First/last bit, CPOL/CPHA edges, CS setup/hold, received data | Yes |
| I2C | Write/read, ACK/NACK, repeated START, clock stretching, stuck-line timeout, open-drain only | Yes (setup/hold vs 100 kHz spec) |
| System | Real firmware loaded through the real loader; UART→SPI→I2C reload on one DUT; recovery after errors | Yes |
| Random | Seeded random legal programs vs model | Yes (lockstep) |
| Formal | 5 proof groups (§5.2) | — |
| Gate level | Smoke + protocol tests on the post-layout netlist in CI | Functional |

---

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Flop imem too large or congested | Measure at G1. Drop `IMEM_DEPTH` to 64, or investigate latch-based storage; compact firmware |
| Single-cycle critical path too slow | Declare a lower clock. 10–25 MHz gives ≥ 100 cycles per I2C/UART bit |
| Hold violations after CTS | Use the flow's resizer hold margins per the template config comments. A lower clock does **not** fix hold |
| FPGA-manager path on the HPS stalls | Fall back to local USB-Blaster programming; S3 is a side track |
| Campus VPN can't reach the lab | Tailscale (free), approved by the board owner |
| cocotb 1.x vs 2.x confusion | Pin 2.0.1; read only the matching docs |
| Scope creep ("just one more protocol") | Stretch items are firmware-only and start after G3; the 2nd engine is decided only at G4 |
| 8×4 tiles announced | Does not change scope; at most enables the 2nd engine |
| Exam season (December) | Feature freeze on Dec 6; December is closure only |

---

## 8. Final acceptance checklist

1. The same hardware runs all three loaded protocol programs (sim + FPGA).
2. The SPI loader works and recovers correctly from documented errors.
3. cocotb regressions (RTL + gate level) and the selected formal proofs pass.
4. FPGA evidence includes representative scope/logic-analyzer captures.
5. The design fits 6×4 and passes the required implementation checks
   (GDS, precheck, STA at the declared clock).
6. Source, firmware, GDS, reports and tool versions are tied to **one** tagged
   release.
7. A teammate reproduces the build and demos from the documentation alone.
