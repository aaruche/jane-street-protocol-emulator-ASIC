/* 
- First Word - Fall Ahead :he engine is single-cycle (decision D1). PULL must read the byte and pop it in the same cycle. 
  A FIFO that presents data one cycle after pop would add a hidden cycle to every PULL and break the timing rules 

  
*/

module pe_fifo #(
    parameter integer WIDTH   = 8,
    parameter integer DEPTH   = 8,                   // Depth 8 is a bet that the host stays ahead well enough 
    parameter integer LEVEL_W = $clog2(DEPTH + 1)    // derived: do not override
) (
    input  wire               clk,
    input  wire               rst_n,       // synchronous, active low

    input  wire               push,
    input  wire [WIDTH-1:0]   push_data,
    input  wire               pop,

    output wire [WIDTH-1:0]   pop_data,    // valid whenever !empty (show-ahead)
    output wire               full,
    output wire               empty,
    output wire [LEVEL_W-1:0] level,       // 0 .. DEPTH
    output reg                overflow,    // 1-cycle pulse: push rejected (was full)
    output reg                underflow    // 1-cycle pulse: pop ignored (was empty)
);