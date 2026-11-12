// testbench.sv: ENTRY FILE (paste into EDA Playground's "testbench" pane)
//
// Purpose
//   Top of the simulation: everything that is not a UVM class.
//
// What to write
//   [ ] `include "uvm_macros.svh" and the other files, in dependency order:
//       pe_fifo_if.sv, fifo_pkg.sv, pe_fifo_sva.sv (EDA Playground: extra
//       tabs with these exact names; locally: +incdir+ to uvm/ and ../sva/)
//   [ ] module tb_top: clock generator; one pe_fifo_if instance;
//       the DUT (src/pe_fifo.v, in the "design" pane) wired to the interface
//   [ ] bind statement that attaches pe_fifo_sva to pe_fifo (ladder step 4)
//   [ ] uvm_config_db #(virtual pe_fifo_if)::set(...) so the agent finds it
//   [ ] run_test();   the test is chosen with +UVM_TESTNAME=<test_class>
//   [ ] $dumpfile("dump.vcd"); $dumpvars; for EPWave
//
// Decide and write down in the vplan
//   Who drives rst_n: tb_top (simple) or the driver through a field in
//   fifo_item (lets random tests inject reset mid-traffic, requirement F1)?
//
// Pitfall
//   Keep the DUT's parameters (WIDTH, DEPTH) in one place and pass them to
//   the interface, the DUT and the SVA module; a mismatch fails silently.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
