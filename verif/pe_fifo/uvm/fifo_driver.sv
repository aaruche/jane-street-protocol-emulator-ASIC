// fifo_driver.sv: turns items into pin activity
//
// What to write
//   [ ] class fifo_driver extends uvm_driver #(fifo_item)
//   [ ] get the virtual interface from uvm_config_db in build_phase
//       (`uvm_fatal if missing)
//   [ ] run_phase loop: get_next_item -> drive through the driver clocking
//       block -> wait one clock -> item_done
//   [ ] safe idle values (push = 0, pop = 0) during and after reset
//
// Pitfall
//   Drive only through the clocking block, never with blocking assignments
//   at the clock edge, or you create races that look like DUT bugs.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
