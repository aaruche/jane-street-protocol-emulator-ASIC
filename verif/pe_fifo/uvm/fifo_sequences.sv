// fifo_sequences.sv: stimulus
//
// What to write (one class each, extending uvm_sequence #(fifo_item))
//   [ ] fill sequence: push until full, then one more push (overflow, F2)
//   [ ] drain sequence: pop until empty, then one more pop (underflow)
//   [ ] simultaneous sequence: push+pop together at empty, mid and full
//   [ ] random sequence: N items with knobs; bursts that swing between full
//       and empty so the boundaries get exercised (coverage step 6)
//
// Concept
//   start_item() / randomize() with { ... } / finish_item(). Sequences only
//   describe WHAT to send; the driver decides HOW it reaches the pins.
//
// Pitfall
//   Purely uniform random push/pop sits at level ~mid most of the time and
//   rarely reaches full. Bias it, then let coverage tell you if it worked.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
