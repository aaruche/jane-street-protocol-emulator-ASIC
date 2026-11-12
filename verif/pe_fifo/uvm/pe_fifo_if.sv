// pe_fifo_if.sv: SystemVerilog interface between the testbench and the DUT
//
// What to write
//   [ ] interface pe_fifo_if #(WIDTH, DEPTH) (input logic clk); with every
//       DUT port as a logic signal (rst_n, push, push_data, pop, pop_data,
//       full, empty, level, overflow, underflow)
//   [ ] clocking block for the driver, @(posedge clk): DUT inputs as outputs
//   [ ] clocking block for the monitor, @(posedge clk): everything as inputs
//   [ ] modports for driver / monitor (optional but good practice)
//
// Concept: why clocking blocks
//   They give race-free timing. The monitor samples values just before the
//   clock edge, and the driver changes inputs just after it, so testbench and
//   DUT never race on the same edge.
//
// Pitfall
//   LEVEL_W must match the DUT's: $clog2(DEPTH + 1).
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
