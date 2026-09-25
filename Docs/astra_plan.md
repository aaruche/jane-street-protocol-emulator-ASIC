# Main roadmap: build, verify and submit your protocol emulator ASIC

## 1. Define a small, complete chip

**Your main objective is a programmable protocol engine that demonstrably runs UART, SPI and I²C firmware, fits the allotted ASIC area, and comes with credible verification evidence.**

Use your existing Verilog skills. Learn cocotb, practical formal verification and physical implementation while building the design.

Plan around **15 team-hours per week**, using the lower end of your stated availability. Additional hours should go toward debugging and verification. Target a complete release by **January 10**, ahead of the official **January 18, 2027 deadline**. The verified allocation remains **6×4 tiles**. [Competition brief](https://blog.janestreet.com/protocol-emulator-asic-competition/)

Lock this baseline:

| Feature | Required capability |
|---|---|
| Programmability | Load new instructions after fabrication |
| Execution | One engine running one selected protocol |
| UART | 8N1, 9,600 baud; separate transmit and receive programs |
| SPI | Controller, mode 0, 100 kHz; transmit and receive |
| I²C | Single controller, 7-bit addressing, 100 kHz; reads/writes, repeated START, ACK/NACK and clock stretching |
| Data handling | Short transactions that fit the available buffers |
| Host control | UART and SPI loaders sharing one command interface; selected at reset |
| Validation | Simulation, selected formal proofs, FPGA demonstrations and physical implementation checks |

Exclude additional protocols, concurrent engines, full-duplex UART, caches, pipelines, operating systems and a C compiler for your instruction engine.

Your central demonstration is:

**Load UART firmware → demonstrate UART → load SPI firmware → demonstrate SPI → load I²C firmware → demonstrate I²C, all on unchanged hardware.**

## 2. Design the architecture around precise timing

Start with an unpipelined engine containing a program counter, instruction decoder, small data registers, shift registers, counters, input sampling and output-enable control.

Its instructions need to express:

- Set pin values and directions.
- Sample inputs.
- Shift data into and out of registers.
- Delay for a defined number of cycles.
- Wait for an input condition, with timeout support.
- Branch and repeat loops.
- Transfer bytes to/from queues.
- Halt and report status.

Protocol behavior belongs in firmware. Small fixed UART/SPI blocks may implement the host loaders.

Use these initial sizing targets:

| Component | Starting point |
|---|---|
| Data path | 8-bit registers and shifts |
| Program memory | 128 × 16-bit instructions |
| Queues | 8-byte transmit and receive FIFOs |
| Timing | 16-bit delay counter |
| Protocol I/O | Eight bidirectional pins |
| Clocking | One core clock; clock enables for slower operations |
| Physical feasibility target | 10 MHz |

These are starting budgets, not claims that the design already fits. Measure the register-based memory and engine early. Keep SRAM outside the baseline unless measurements later establish a compelling need and a compatible integration path.

**Write the timing specification before substantial engine RTL.** For every instruction, define its state changes, cycle count, pin-update point, input-sampling point and behavior when blocked. A simple instruction table and several handwritten traces are sufficient.

Also define the interface contract:

- Host operations: load, readback, supply data, retrieve data, run, halt and status.
- Reset: engine halted, protocol output enables cleared.
- Program memory: loaded before execution; no dependence on FPGA initialization.
- Program writes: rejected while running.
- Buffer limits: explicit acceptance/error behavior.
- Timing-sensitive transfers: prebuffer data and reserve receive space.
- I²C: drive low or release; never actively drive high.
- Timeout/error recovery: a documented way to stop and restart.

Build a small Python interpreter from that specification. Use it to validate programs and compare instruction behavior with RTL. Keep its implementation independently reviewed.

## 3. Divide the real work and follow milestone gates

| Student | Primary ownership | Required review contribution |
|---|---|---|
| **A: architecture and firmware** | ISA, engine RTL, assembler, UART/SPI/I²C programs | Review the reference model and timing tests |
| **B: verification** | cocotb, reference model, formal properties, regressions | Review instruction semantics and interface corner cases |
| **C: implementation and integration** | Host loaders, FPGA wrapper, ASIC flow, physical reports | Review reset, I/O behavior and clock assumptions |

Ownership is not isolation. Each person should eventually run the tests, understand a counterexample, load the FPGA and explain a timing report.

**SSH is Student B’s side task**, with C helping only on board-specific setup. Start with a small allowance of spare time to establish Linux/SSH access through the campus VPN. It must not delay verification milestones, FPGA testing or ASIC builds. Standalone remote FPGA programming follows only after basic SSH works and the main schedule remains healthy.

The main schedule is:

| Period | Work | Exit condition |
|---|---|---|
| **Weeks 1–2: Sept 28–Oct 11** | Run the official template; learn basic cocotb and formal on a tiny delay/counter; draft architecture and timing specification; generate an FPGA pulse | Everyone can run a test. Team has a passing/failing formal example, measured pulse and successful ASIC-template build |
| **Weeks 3–4: Oct 12–25** | Implement program memory, fetch/execute, pin writes, delays, branches and halt; build the interpreter and UART loader | Load/read back two different pulse programs through the loader; both match the model; minimal engine has completed place and route |
| **Weeks 5–6: Oct 26–Nov 8** | Add shifts and queues; implement UART transmit/receive firmware; develop SPI firmware and SPI loader | UART passes pin-level tests and FPGA measurement; SPI transfer works; queue checks pass |
| **Weeks 7–8: Nov 9–22** | Complete SPI and I²C firmware; integrate both loaders; test ACK/NACK, repeated START and clock stretching | All three protocols work in simulation; hardware demonstrations underway |
| **Weeks 9–10: Nov 23–Dec 6** | Complete FPGA demonstrations; strengthen error/reset/timeout tests; stabilize architecture | Reproducible baseline demo and reviewed physical results. **Feature freeze December 6** |
| **Weeks 11–12: Dec 7–20** | Close verification gaps, run gate-level regressions, fix timing/routing/physical-check failures | Release candidate with passing required checks |
| **Weeks 13–14: Dec 21–Jan 3** | Contingency, documentation and clean-checkout reproduction | Another teammate reproduces the complete project |
| **Week 15: Jan 4–10** | Final checks, evidence and submission preparation | Submission-ready release |
| **Jan 11–18** | Submission buffer | Necessary fixes and submission issues only |

Run physical implementation **throughout development**, beginning in week one. Repeat it after significant changes to the engine, memories or interfaces.

For the first week specifically:

- **A:** Draft the support matrix, block diagram and instruction timing table; trace a ten-instruction pulse program.
- **B:** Run the supplied cocotb test, add a checked counter/delay test, deliberately break it and inspect the waveform.
- **C:** Run the CMOS5L template through its workflows, inspect the resulting layout and identify the area/timing reports.
- **Together:** Review findings and choose the smallest engine milestone for week two.

## 4. Build verification alongside the RTL

Use **cocotb for simulation and OSS CAD Suite/SBY for selected formal proofs**. UVM and commercial licenses are unnecessary for this plan.

Start with the template’s existing simulator setup and pinned dependencies. It currently uses cocotb 2.0.1; follow matching documentation. [Template requirements](https://github.com/TinyTapeout/ttihp-verilog-template/blob/cmos5l/test/requirements.txt), [cocotb quickstart](https://docs.cocotb.org/en/v2.0.1/quickstart.html)

Learn cocotb through your own blocks:

1. Clock, reset, input driving and output assertions.
2. Correct sampling after signal updates.
3. Reusable driver functions.
4. Concurrent stimulus and monitoring.
5. Deterministic random tests, timeouts and failure logs.

Keep the testbench understandable: one host driver, one instruction model, a scoreboard, and protocol peers/monitors.

| Verification level | Required scenarios |
|---|---|
| Blocks | Counter boundaries, shifts, reset, FIFO empty/full and simultaneous read/write |
| Instructions | Every instruction, both branch outcomes, waits, stalls and exact pin-update timing |
| Host control | Load/readback/run/halt/reset/reload through both loaders; invalid writes while running |
| UART | Known patterns, back-to-back frames, varying input phase, framing errors and documented baud tolerance |
| SPI | First/last bit, clock edges, chip-select timing and received values |
| I²C | Reads/writes, ACK/NACK, repeated START, stretching, stuck-line timeout and open-drain behavior |
| Whole system | Actual firmware loaded through actual host interfaces, checked results and recovery after errors |

Check both the data and the waveform timing. A correct received byte does not establish that every edge met the protocol requirements.

For formal, begin with supported `assert`, `assume`, `cover` and guarded `$past` constructs. The free OSS CAD Suite supplies the tools; do not assume every concurrent SVA feature works in its default frontend. [SBY installation](https://yosyshq.readthedocs.io/projects/sby/en/latest/install.html), [formal constructs](https://yosyshq.readthedocs.io/projects/sby/en/latest/verilog.html)

Target five useful proof groups:

- Delay completion occurs on the specified cycle.
- FIFO occupancy and accepted-operation behavior are correct.
- FIFO data ordering is preserved.
- A stalled instruction does not advance or duplicate side effects.
- Reset/halt and open-drain output behavior satisfy their specifications.

For each group, obtain a pass, inject a deliberate bug, inspect the counterexample and cover meaningful activity. Record assumptions, configuration and whether the result is bounded or unbounded.

A few understood proofs are a satisfactory formal-verification contribution. A whole-chip proof is outside the baseline.

## 5. Learn physical implementation by completing your own flow

Your physical-design objective is to **run, understand and debug the supplied implementation flow**.

Use the official CMOS5L branch and its matching tools/PDK. Its workflow supplies GDS generation, Tiny Tapeout precheck and gate-level testing. [CMOS5L workflow](https://github.com/TinyTapeout/ttihp-verilog-template/blob/cmos5l/.github/workflows/gds.yaml)

Learn each stage using your own reports:

| Stage | What the team needs to understand |
|---|---|
| Synthesis | How RTL maps into cells; memory cost; unexpected latches or large multiplexers |
| Floorplanning | Available area and utilization |
| Placement | Cell locations, congestion and room for routing |
| Clock-tree synthesis | Clock distribution, skew and added buffers |
| Routing/extraction | Wiring and its resistance/capacitance |
| Static timing analysis | Setup/hold slack, clock and I/O constraints, analyzed corners |
| DRC | Whether checked layout geometry obeys manufacturing rules |
| LVS | Whether extracted layout connectivity matches the reference circuit |
| Shuttle precheck | Whether the design meets Tiny Tapeout’s integration requirements |

Keep a small table tied to each significant build: source revision, cell area, utilization, worst setup/hold results, relevant corners and check status. In team reviews, explain one real timing path rather than collecting reports nobody reads. [LibreLane timing guide](https://librelane.readthedocs.io/en/latest/usage/timing_closure/index.html)

Use evidence to simplify the implementation:

- If memory dominates area, reduce unnecessary storage and improve firmware compactness.
- If a large combinational path limits speed, simplify it or allow explicitly specified execution cycles.
- If routing is congested, reduce complexity before increasing placement density.
- Never hide failures by adding unjustified timing exceptions or disabling checks.
- A lower clock may help setup timing; it does not solve hold violations.

Inspect which checks the exact flow actually executes. Resolve unavailable required checks with Tiny Tapeout; record skipped checks honestly. Functional formal, gate-level simulation, static timing analysis and physical verification establish different things.

The final acceptance gate is:

1. The same hardware runs all three loaded protocol programs.
2. Both host loaders work and recover correctly from documented errors.
3. cocotb regressions and the selected formal checks pass.
4. FPGA results include representative oscilloscope measurements.
5. The design fits 6×4 and passes required implementation checks at the declared operating conditions.
6. Source, firmware, layout, reports and tool versions correspond to the same release.
7. Another teammate can reproduce the build and demonstrations from the documentation.

That is the chip project. The SSH server supports the team’s access to the board; it is not a dependency of any ASIC milestone.
