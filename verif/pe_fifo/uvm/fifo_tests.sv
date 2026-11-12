// fifo_tests.sv: tests (selected with +UVM_TESTNAME=...)
//
// What to write
//   [ ] fifo_base_test: builds the env; prints the topology
//       (uvm_top.print_topology()) in end_of_elaboration_phase
//   [ ] one test per vplan section-4 row (reset, fill/overflow, drain/
//       underflow, simultaneous, random): raise an objection, start the
//       sequence(s) on the agent's sequencer, drop the objection
//   [ ] report_phase: print PASS/FAIL from the report server's UVM_ERROR and
//       UVM_FATAL counts, plus the seed
//
// Concept
//   Tests choose WHICH stimulus and configuration; the env is reused
//   unchanged. The factory (type overrides) lets a test swap a component
//   without editing the env.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
