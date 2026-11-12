# Verification

This is the main work of the project (ROADMAP decisions D11–D12). Claude drafts
most RTL; **every reference model, check and coverage model here is written by
the developer** (CLAUDE.md §10). Claude provides scaffolding, explanations,
reviews, and bug-hunt mutants.

Stack: **SystemVerilog UVM 1.2 + SVA + covergroups on EDA Playground**,
**SymbiYosys** for formal (`../formal/`), and thin **cocotb** smoke tests in
`../test/` only because the Tiny Tapeout CI needs them.

## Layout (one folder per block)

```
verif/<block>/
  vplan.md        requirements → check → coverage item → test   (write first)
  uvm/            the UVM testbench; testbench.sv is the entry file
  sva/            SVA bind file(s); never put SVA in src/
  bugs/           mutant RTL for the bug hunt (Claude adds these at step 7 only)
  results/        run log: test, seed, pass/fail, coverage %, playground link
  signoff.md      written at step 8
```

## The ladder (every block)

| Step | Produce | Done when |
|---|---|---|
| 0. Design review | Review notes on the RTL vs `docs/spec/block_interfaces.md`; fixes merged | Every spec rule traced to a line of RTL, or reported |
| 1. vplan | `vplan.md` | Every requirement has a check, a coverage item and a test; no orphan checks |
| 2. Thin cocotb smoke test | `test/unit/<block>/` | Passes in CI (reset + basic traffic only) |
| 3. UVM environment | `uvm/` | Directed and random tests pass; scoreboard checks **every output every cycle** |
| 4. SVA | `sva/<block>_sva.sv` bound into the testbench | Assertions pass; every important `assert property` has a `cover property` that is hit |
| 5. Formal | `../formal/<block>.sby` | Proofs pass; bounded vs unbounded recorded; one injected bug's counterexample read |
| 6. Coverage closure | Coverage goals met | 100% of the vplan's functional coverage, or every hole explained in the vplan |
| 7. Bug hunt | Entries in `results/` | Every mutant in `bugs/` caught (and which check caught it); survivors fixed by strengthening the testbench |
| 8. Sign-off | `signoff.md` | Someone reading it knows what is verified, how well, and what is not |

The FIFO goes through every step in depth; later blocks reuse its structure.

## Running on EDA Playground

[EDA Playground](https://www.edaplayground.com) gives free browser access to
commercial simulators that support UVM, SVA and functional coverage. It is
manual (no CI), so log every meaningful run in `results/`.

1. Log in (a free account is needed for commercial simulators).
2. Left settings panel:
   - **Testbench + Design:** SystemVerilog/Verilog
   - **UVM / OVM:** UVM 1.2
   - **Tools & Simulators:** Aldec Riviera-PRO, or another commercial
     simulator your account offers
   - Tick **Open EPWave after run** when you need waveforms
3. Files:
   - Paste the RTL (e.g. `src/pe_fifo.v`) into the **design** pane.
   - Paste `uvm/testbench.sv` into the **testbench** pane.
   - Add every other file in `uvm/` and `sva/` as extra tabs with the **same
     file names**. Extra tabs are pulled in with `` `include `` from
     `testbench.sv`, so keep the include order correct (package before top).
4. **Run options:** pick the test with `+UVM_TESTNAME=<test_class>`. Set the
   seed with the simulator's seed option (Riviera-PRO: `-sv_seed <n>`, or
   `-sv_seed random` and read the chosen seed from the log).
5. Waves: call `$dumpfile("dump.vcd"); $dumpvars;` in the top module and open
   EPWave after the run.
6. **Save** the playground and copy its URL.
7. Add one line to `results/README.md`: date, test, seed, UVM_ERROR /
   UVM_FATAL counts, coverage %, playground link.

The files are plain SV/UVM, so the same testbench runs on any commercial
simulator with UVM 1.2 if you get access to one later.

## Rules (from CLAUDE.md §7)

- Write the vplan before the testbench.
- The scoreboard's reference model is yours, not derived from the RTL.
- Log the seed of every random run.
- SVA lives here (bind files), never in `src/`.
- Never weaken a check to get green; understand the failure first.
