// pe_fifo_sva.sv: SVA checker module, attached to the DUT with `bind`
// (ladder step 4; never put these assertions in src/)
//
// What to write
//   [ ] module pe_fifo_sva #(WIDTH, DEPTH, LEVEL_W) with every DUT port as
//       an INPUT (and internal signals such as push_accepted if you want
//       them, connected by name through bind)
//   [ ] default clocking @(posedge clk) and default disable iff (!rst_n),
//       except for the reset-value assertion (F1), which must not be disabled
//   [ ] properties from the vplan, each with a label, e.g.:
//         full and empty never both; full == (level == DEPTH);
//         overflow implies push && full in the previous cycle (F2);
//         !empty && no accepted pop  |=>  $stable(pop_data)
//   [ ] a cover property for each important assertion
//   [ ] in testbench.sv:
//         bind pe_fifo pe_fifo_sva #(.WIDTH(WIDTH), .DEPTH(DEPTH)) u_sva (.*);
//
// Pitfall
//   An implication whose antecedent never happens passes vacuously. That is
//   why every assertion needs its cover property to be hit.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
