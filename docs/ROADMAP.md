# Roadmap: Protocol Emulator ASIC

*Last revised 2026-11-12: the project is now **solo and verification-first**
(decisions D10–D13). Earlier revisions planned for three people with roles
A/B/C and Persons 1–3; those no longer apply.*
Architectural boundaries, coding rules and the Claude/developer division of
labour live in [`../CLAUDE.md`](../CLAUDE.md).

---

## 1. Goal and definition of done

**One programmable protocol engine, verified credibly, that fits 6×4 tiles on
IHP SG13CMOS5L and runs UART, SPI and I2C purely from loaded firmware.**

The central demo, on unchanged hardware, in simulation:

> load UART firmware → check UART → load SPI firmware → check SPI → load I2C firmware → check I2C

### Scope

| Level | Contents |
|---|---|
| **Baseline (must ship)** | UART 8N1 TX + RX (half-duplex: one direction at a time), e.g. 9600 and 115200 baud. SPI controller, mode 0 (modes 1–3 as firmware-only variants). I2C controller: 7-bit addressing, read/write, ACK/NACK, repeated START, clock stretching, stuck-bus timeout. SPI-slave host loader. |
| **Stretch (only if ahead of schedule)** | UVM register-layer (RAL) model of the host register map. Firmware-only extras (protocol-sniffer mode, PS/2). |
| **Excluded** | USB, 10M Ethernet, CAN in hardware; pipelines, caches, SRAM macros, interrupts; UART loader; C compiler for the engine; FPGA demos and the remote lab (D13). |

"Satisfactory" means that every block has a spec, a vplan, a testbench that
reaches its coverage goals, a bug hunt and a sign-off; the system tests pass
for all three protocols; and the GDS is clean. It does not mean more protocols.

---

## 2. Decision log

| # | Date | Decision | Why |
|---|---|---|---|
| D1 | 2026-09-26 | **Single-cycle, unpipelined engine**; fixed cycles per instruction, stalls only on WAIT/PULL/PUSH | Deterministic timing is the product. No hazards means less to verify, and the model is trivially cycle-exact. |
| D2 | 2026-09-26 | **Flip-flop program memory**, combinational read, `IMEM_DEPTH` param (target 128×16); no SRAM | An SRAM's synchronous read would force a fetch stage (breaking D1), and the SRAM integration path is a risk. |
| D3 | 2026-09-26 | cocotb 2.0.1 + Icarus; Verilator `--lint-only` | Icarus is the template default and what the gate-level CI uses. *Narrowed by D12: cocotb is now only the thin CI layer.* |
| D4 | 2026-09-26 | **Formal with SymbiYosys** (OSS CAD Suite), immediate assertions | Free; no commercial formal license available. |
| D5 | 2026-09-26 | **SPI-slave loader only** | One loader to verify; easy to drive from a testbench and from the TT demo board's microcontroller. |
| D6 | 2026-09-26 | **1 engine taped out**, `NUM_ENGINES` parameter | Keeps scope small but leaves a cheap upgrade path if area allows. |
| D7 | 2026-09-26 | ~~DE1-SoC HPS Linux is the remote test host~~ | *Superseded by D13.* |
| D8 | 2026-09-26 | ~~Remote access via campus VPN~~ | *Superseded by D13.* |
| D9 | 2026-09-26 | Verilog-2005 (not Hardcaml / SystemVerilog) in `src/` | Runs on every open-source tool. SystemVerilog is used in `verif/` only. |
| D10 | 2026-11-12 | **Solo project** | The other two teammates left. Same scope (UART, SPI, I2C), same deadline. |
| D11 | 2026-11-12 | **Verification-first division of labour:** Claude drafts most RTL from the spec; the developer writes short concept cores (host-SPI sync/edges, engine stall/next-PC, pins open-drain/OE), all reference models and all verification | The main learning goal is industry-style verification. Independent reference models also give a real check on AI-drafted RTL. |
| D12 | 2026-11-12 | **SystemVerilog UVM 1.2 + SVA + covergroups on EDA Playground** as the main verification stack; thin cocotb tests only for Tiny Tapeout CI and gate-level sim | UVM/SVA/coverage are the industry standard. EDA Playground gives free access to a commercial simulator; Icarus cannot run UVM. |
| D13 | 2026-11-12 | **FPGA and remote-lab (SSH) track dropped** | Solo time goes to verification; the board owner left. Simulation, formal and the GDS flow are the evidence. |

Add a row whenever a boundary in `CLAUDE.md` §3/§4 changes.

---

## 3. Working model

See [`../CLAUDE.md`](../CLAUDE.md) §10 for the full table. In short:

| Claude | Developer |
|---|---|
| Drafts specs and most RTL; template, CI, assembler, firmware; diagrams; scaffolding; reviews; bug-hunt mutants | Reviews specs and RTL; writes concept cores; writes **all** verification: vplans, UVM environments, reference models, SVA, formal properties, coverage closure, sign-offs |

Rule of thumb: whenever Claude writes a piece of RTL, the developer verifies it
with a reference model Claude did not write.

---

## 4. Timeline and gates

Done before this revision: spec v0 (ISA strawman, block contracts, host
protocol skeleton), diagrams, `pe_fifo` RTL. The earlier gates G0–G3 are
superseded by the gates below.

| Weeks | Claude | Developer | Gate |
|---|---|---|---|
| **Nov 12–22** | This restructure; import the TT template (`src/`, `test/`, `info.yaml` 6×4, CI); `pe_imem` RTL; drafts of `isa.md` v1 and final `host_protocol.md` | FIFO steps 0–4 ([`../verif/README.md`](../verif/README.md)); review both specs | **Specs signed off** |
| **Nov 23–29** | `pe_host_spi` (with the sync/edge concept core), `pe_ctrl`, engine G1 subset (SET, JMP, WAIT, delay, HALT; with the stall/next-PC concept core), assembler | FIFO steps 5–8; `pe_imem` testbench (reuses the FIFO patterns); fill the two concept cores | **FIFO signed off** |
| **Nov 30–Dec 6** | Full ISA, `pe_pins` (with the open-drain/OE concept core), top-level integration, first full GDS run | UVM **SPI host agent** (driver with timing knobs, monitor) + host-loader environment; **SV ISA reference model** for the engine scoreboard | **G1:** a program loads and runs over SPI in simulation; GDS + precheck green |
| **Dec 7–13** | UART / SPI / I2C firmware | Protocol monitors and responders (UART, SPI target, I2C target with stretching and NACK); system tests: load firmware → check bus traffic and timing; the UART→SPI→I2C reload test | **Feature freeze (Dec 13)** |
| **Dec 14–27** | Timing/area fixes, gate-level sim, precheck; mutants for engine and loader | Coverage closure; top-level SVA; formal (stall has no side effects, open-drain never drives 1, no imem write while running); bug hunts | **Release candidate:** all checks green on one commit |
| **Dec 28–Jan 10** | `docs/info.md` datasheet; clean-checkout reproduction of CI and GDS | Sign-off documents for every block; rerun every UVM test from a clean copy | **Submission-ready (Jan 10)** |
| Jan 11–18 | Buffer: submission-blocking fixes only | | Submit |

Assumes about 15–20 hours per week. The FIFO goes deep because it is where the
methodology is learned; later blocks reuse its patterns and go faster.

---

## 5. Learning tracks

### 5.1 Verification (primary)

Every block climbs the same ladder, defined in
[`../verif/README.md`](../verif/README.md):

0. design review → 1. vplan → 2. thin cocotb smoke test → 3. UVM environment
→ 4. SVA → 5. formal → 6. coverage closure → 7. bug hunt → 8. sign-off.

UVM learning order, applied to the FIFO first:

1. SystemVerilog for verification: classes, `rand` / `constraint`,
   queues and associative arrays, `covergroup` / `coverpoint` / `cross`,
   interfaces and clocking blocks.
2. UVM components and phases: `uvm_test`, `uvm_env`, `uvm_agent`, `uvm_driver`,
   `uvm_monitor`, `uvm_sequencer`, `uvm_scoreboard`, `uvm_subscriber`;
   `build_phase` / `connect_phase` / `run_phase` / `report_phase`; objections.
3. Transactions and stimulus: `uvm_sequence_item`, sequences,
   `start_item` / `finish_item`, layered sequences, constraint biasing.
4. Plumbing: analysis ports and TLM FIFOs, `uvm_config_db`, the factory and
   type overrides, reporting and verbosity.
5. Closure: coverage goals, hole analysis, seeds, regression summaries.
6. Stretch: the UVM register layer (RAL) for the host register map.

### 5.2 Formal

Tools: SymbiYosys + Yosys + a solver (Yices / Bitwuzla / Boolector), all in the
OSS CAD Suite. Start from the
[SBY docs](https://yosyshq.readthedocs.io/projects/sby/en/latest/) and use
**immediate** assertions in `` `ifdef FORMAL `` blocks. Don't assume full
concurrent-SVA support in the open-source frontend. A useful exercise is to
write the same property both ways: SVA for simulation, immediate + `$past`
for SBY.

For **every** property: get a pass → inject a bug → read the counterexample →
add a `cover` that proves the interesting case is reachable → write down the
assumptions and whether it is bounded or unbounded.

Target proof groups:

1. FIFO occupancy, full/empty and accept/reject behavior.
2. FIFO data ordering is preserved.
3. A stalled instruction does not advance the PC or duplicate side effects.
4. The delay/loop counter completes on exactly the specified cycle.
5. Reset/halt: `uio_oe = 0`; open-drain pins never drive 1; no imem write
   while running.

### 5.3 cocotb (thin)

Only what the Tiny Tapeout CI needs: a smoke test per block in `test/unit/`
and one top-level test that loads and runs a program (also used for gate-level
simulation). Use the **v2.0.1 docs**; many tutorials online are cocotb 1.x.

### 5.4 Physical design (understand, don't own)

Claude runs the flow; the developer should still be able to read the reports
and explain one real timing path:

| Stage | What to understand |
|---|---|
| Synthesis | Cell count/area; how the imem and its read mux map; unexpected latches or huge muxes |
| Floorplan / placement | Utilization, `PL_TARGET_DENSITY_PCT`, congestion |
| CTS | Clock buffers added, skew |
| STA | Setup/hold slack, the critical path (expect: PC → imem read mux → decode → next-PC) |
| DRC / LVS / precheck | Layout rules; layout matches netlist; Tiny Tapeout integration rules |

Keep `docs/pd_log.md` with one row per significant build. **Never hide
failures with exceptions.**

---

## 6. Verification plan (summary)

| Level | Required scenarios | Where | Timing checked? |
|---|---|---|---|
| `pe_fifo` | Fill/drain, overflow/underflow, simultaneous push/pop at empty/mid/full, show-ahead data, pointer wrap | UVM + SVA + formal | Yes (cycle of flag changes) |
| `pe_imem` | Every address, no disturbance, read-during-write, `we` = 0 | UVM | Yes (combinational read) |
| Host loader (`pe_host_spi` + `pe_ctrl`) | Load / readback / run / halt / step / reset; write-while-running rejected; malformed and aborted frames; SCLK at max rate and odd ratios to `clk` | UVM SPI agent + SVA | Yes (MISO stable at host sample edges) |
| Engine | Every instruction; both branch outcomes; WAIT hit/timeout; stalls; exact pin-update cycle | UVM + SV ISA model (lockstep) + formal | Yes (lockstep) |
| `pe_pins` | Open-drain never drives 1; reset → all inputs; pin-space mapping | UVM/SVA + formal | Yes |
| UART | Known patterns, back-to-back, random input phase, framing error, baud tolerance | System UVM | Yes (bit widths, sample point) |
| SPI | First/last bit, CPOL/CPHA edges, CS setup/hold, received data | System UVM | Yes |
| I2C | Write/read, ACK/NACK, repeated START, clock stretching, stuck-line timeout, open-drain only | System UVM | Yes (vs 100 kHz spec) |
| System | Real firmware loaded through the real loader; UART→SPI→I2C reload on one DUT; recovery after errors | System UVM + thin cocotb (CI) | Yes |
| Random | Seeded random legal programs vs the ISA model | UVM | Yes (lockstep) |
| Gate level | Smoke + load-and-run on the post-layout netlist | cocotb in CI | Functional |

---

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Solo bandwidth | Claude drafts RTL and tooling; depth on the FIFO, then reuse patterns; stretch items only if ahead |
| UVM learning curve | Learn it on the smallest block (FIFO) first; one concept per step; Claude reviews each component |
| EDA Playground is manual and run-time limited | Keep each test short; log results in `verif/<block>/results/`; thin cocotb + formal + lint run in CI automatically |
| Bugs in AI-drafted RTL | Developer-written reference models, SVA, formal and bug hunts: this is exactly what the verification work is for |
| Flop imem too large or congested | Measure at G1. Drop `IMEM_DEPTH` to 64, or investigate latch-based storage; compact firmware |
| Single-cycle critical path too slow | Declare a lower clock. 10–25 MHz gives ≥ 100 cycles per I2C/UART bit |
| Hold violations after CTS | Use the flow's resizer hold margins per the template config comments. A lower clock does **not** fix hold |
| Scope creep | Stretch items only after the release candidate |
| Exam season (December) | Feature freeze on Dec 13; the rest of December is verification closure |

---

## 8. Final acceptance checklist

1. The same hardware runs all three loaded protocol programs in simulation.
2. The SPI loader works and recovers correctly from documented errors.
3. Every block has a vplan, a testbench at its coverage goals, a bug hunt and
   a signed-off `signoff.md`.
4. The selected formal proofs pass, with bounded/unbounded status recorded.
5. Thin cocotb tests (RTL + gate level) pass in CI.
6. The design fits 6×4 and passes the required implementation checks (GDS,
   precheck, STA at the declared clock).
7. Source, firmware, GDS, reports, tool versions and verification results are
   tied to **one** tagged release, and a clean checkout reproduces them from
   the documentation alone.
