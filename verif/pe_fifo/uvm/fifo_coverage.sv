// fifo_coverage.sv: functional coverage (implements vplan section 2)
//
// What to write
//   [ ] class fifo_coverage extends uvm_subscriber #(fifo_item)
//   [ ] covergroup(s) sampled in write(): level bins 0..DEPTH; op x state
//       cross (12 bins); overflow / underflow seen; pointer wrap count
//   [ ] report_phase: print each covergroup's get_coverage() (or
//       get_inst_coverage()) so the % appears in every log, on any simulator
//
// Concept
//   Coverage answers "did the situation happen?", checks answer "was the
//   behavior right?". You need both; neither replaces the other.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
