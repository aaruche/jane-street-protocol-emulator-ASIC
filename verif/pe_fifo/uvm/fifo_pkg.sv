// fifo_pkg.sv: the package that holds every UVM class
//
// What to write
//   [ ] package fifo_pkg; import uvm_pkg::*;
//   [ ] `include the class files in dependency order (a class must be
//       declared before it is used): item, sequences, driver, monitor,
//       agent, scoreboard, coverage, env, tests
//   [ ] endpackage
//
// Concept
//   Packages give the classes one shared namespace and let tb_top call
//   run_test() by name through the factory.
//
// SCAFFOLD: header only. The developer writes the code (CLAUDE.md §10).
