// fifo_scoreboard.sv: the reference model and the checks (the heart of it)
//
// What to write
//   [ ] class fifo_scoreboard extends uvm_scoreboard with an analysis imp
//       (or uvm_tlm_analysis_fifo) connected to the monitor
//   [ ] YOUR reference model, written from the spec's Behavior table, NOT
//       from the RTL: an SV queue (bit [7:0] q[$]) plus the overflow and
//       underflow values expected in the next cycle
//   [ ] for every sampled cycle:
//         1. compare ALL outputs with the model: level == q.size(), empty,
//            full, pop_data == q[0] when not empty, overflow, underflow
//         2. then apply that cycle's inputs to the model using the spec's
//            accept rules (push rejected when full, pop ignored when empty,
//            push+pop rules)
//   [ ] handle reset: clear the model when rst_n was low at that edge
//   [ ] count checks; report_phase prints how many checks passed/failed
//
// Pitfall
//   Comparing only pop_data on pops misses flag and level bugs. Check every
//   output every cycle; the bug hunt at step 7 will test this.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
