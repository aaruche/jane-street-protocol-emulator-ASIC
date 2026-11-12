// fifo_monitor.sv: observes the pins, never drives them
//
// What to write
//   [ ] class fifo_monitor extends uvm_monitor; an analysis port
//   [ ] every clock: sample inputs AND outputs through the monitor clocking
//       block into a new fifo_item, then ap.write(item)
//
// Concept: what one sample means (think this through before the scoreboard)
//   At clock edge t you see (a) the inputs that edge t will act on, and
//   (b) the outputs produced by edge t-1. The scoreboard must compare (b)
//   against the model state BEFORE applying (a).
//
// Pitfall
//   Don't let the monitor decide pass/fail. It only reports what happened,
//   which keeps it reusable (e.g. in a passive agent at system level).
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
