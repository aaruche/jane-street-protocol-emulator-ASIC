// fifo_item.sv: the sequence item (one transaction = ONE clock cycle)
//
// What to write
//   [ ] class fifo_item extends uvm_sequence_item; `uvm_object_utils(...)
//   [ ] stimulus fields, rand: push, pop, push_data (and rst if the driver
//       owns reset)
//   [ ] observed fields, NOT rand, filled by the monitor: pop_data, full,
//       empty, level, overflow, underflow
//   [ ] constraints with `dist` weights, controlled by knobs (e.g. push_pct)
//       so sequences can bias toward full or empty
//   [ ] convert2string() so failures print readable transactions
//
// Concept
//   This FIFO is cycle-based: every cycle has a push/pop decision, so one
//   item per cycle (including "do nothing" cycles) keeps driver, monitor and
//   scoreboard simple.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
