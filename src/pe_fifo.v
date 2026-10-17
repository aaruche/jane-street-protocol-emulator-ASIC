`default_nettype none

/*
- First Word - Fall Ahead : the engine is single-cycle (decision D1). PULL must read the byte and pop it in the same cycle.
  A FIFO that presents data one cycle after pop would add a hidden cycle to every PULL and break the timing rules

- Burst absorption. The depth (8) is a bet about how long the host can be late. Depth >= (host service latency x byte rate)
  is the sizing intuition.

- Flow control through the flags. empty and full are the handshake:
            PULL on empty stalls the engine.
            PUSH on full stalls the engine.
            level feeds the status register and ATTN, so the host knows when to service the FIFOs.

- Clean error reporting. overflow and underflow pulses turn "the host was too slow" or "firmware misbehaved" into visible
  status bits instead of silent data loss.

- Reset Behavior: full/empty are derived from the pointers, so there is nothing to reset for them.
  The pointer reset gives empty = 1 automatically.
  empty = 1 means "stall; ignore whatever pop_data shows" because it is garbage (the array is never reset).
  Overflow and Underflow under reset: they are flops, so they are reset to 0, otherwise the first cycle after reset
  could show a false error to the host.
*/

module pe_fifo #(
    parameter integer WIDTH   = 8,
    parameter integer DEPTH   = 8,                   // Depth 8 is a bet that the host stays ahead well enough
    parameter integer LEVEL_W = $clog2(DEPTH + 1)    // derived: do not override
) (
    input  wire               clk,
    input  wire               rst_n,

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
    // Pointer = index bits + 1 lap bit (MSB). The low PTR_W-1 bits address the array.
    localparam integer PTR_W = $clog2(DEPTH) + 1;

    reg [WIDTH-1:0] fifo [DEPTH-1:0];

    reg [PTR_W-1:0] rd_ptr;
    reg [PTR_W-1:0] wr_ptr;

    // TODO: empty, full, level, pop_data (combinational, from the pointers)
    // TODO: accepted push / accepted pop wires
    // TODO: storage write block (no reset)

    always @(posedge clk) begin
        if (!rst_n) begin
            // The array is not reset.
            rd_ptr    <= {PTR_W{1'b0}};
            wr_ptr    <= {PTR_W{1'b0}};
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end
        // TODO: else branch: pointer increments and the two pulses
    end

endmodule

`default_nettype wire