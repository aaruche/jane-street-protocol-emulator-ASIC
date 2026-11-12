// fifo_agent.sv: bundles sequencer + driver + monitor
//
// What to write
//   [ ] class fifo_agent extends uvm_agent
//   [ ] build_phase: always build the monitor; build the sequencer and
//       driver only when is_active == UVM_ACTIVE
//   [ ] connect_phase: driver.seq_item_port -> sequencer.seq_item_export
//
// Concept
//   Active vs passive agents: at system level the same monitor runs passively
//   on an internal interface while another agent drives the pins.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
