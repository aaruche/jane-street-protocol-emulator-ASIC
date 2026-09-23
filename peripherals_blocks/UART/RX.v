`timescale 1ns/1ps

module RX #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9_600
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_serial,

    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        rx_busy,
    output reg        parity_error,
    output reg        framing_error
);

    // States
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] START  = 3'd1;
    localparam [2:0] DATA   = 3'd2;
    localparam [2:0] PARITY = 3'd3;
    localparam [2:0] STOP   = 3'd4;

    reg [2:0] state;


   // Timing
   
    localparam integer CLKS_PER_BIT =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;

    localparam integer HALF_CLKS_PER_BIT =
        CLKS_PER_BIT / 2;

    localparam integer COUNTER_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    reg [COUNTER_WIDTH-1:0] baud_counter;

    // TODO:
    // Create a signal for reaching half a bit.
    // Create a signal for reaching one complete bit.

    // Input synchronizer
    reg rx_meta;
    reg rx_sync;
    reg rx_previous;

    always @(posedge clk) begin
        if (!rst_n) begin                   
            rx_meta     <= 1'b1;
            rx_sync     <= 1'b1;
            rx_previous <= 1'b1;
        end
        else begin                             // 2 FF synchroniser 
            rx_meta     <= rx_serial ; 
            rx_sync     <= rx_meta ; 
            rx_previous <= rx_sync ; 
        end
    end

    // TODO:
    // Create start_edge.
    // It is true when the previous synchronized value was 1
    // and the current synchronized value is 0.

    //============================================================
    // Received-frame storage
    //============================================================

    reg [7:0] rx_buffer;
    reg [2:0] bit_index;
    reg       saved_parity_error;

    //============================================================
    // Baud counter
    //============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            baud_counter <= {COUNTER_WIDTH{1'b0}};
        end
        else begin
            // TODO:
            //
            // IDLE:
            //   keep the counter at zero
            //
            // START:
            //   count until half a bit
            //
            // DATA/PARITY/STOP:
            //   count until one complete bit
            //
            // When the required time is reached:
            //   return the counter to zero
        end
    end

    //============================================================
    // RX state controller
    //============================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            state              <= IDLE;
            rx_data            <= 8'h00;
            rx_buffer          <= 8'h00;
            bit_index          <= 3'd0;

            rx_valid           <= 1'b0;
            rx_busy            <= 1'b0;
            parity_error       <= 1'b0;
            framing_error      <= 1'b0;
            saved_parity_error <= 1'b0;
        end
        else begin
            // Normally low. Raise for one clock when a frame finishes.
            rx_valid      <= 1'b0;
            parity_error  <= 1'b0;
            framing_error <= 1'b0;

            case (state)

                IDLE: begin
                    // TODO:
                    // Keep rx_busy low.
                    // Wait for start_edge.
                    // When found:
                    //   clear old frame information
                    //   raise rx_busy
                    //   move to START
                end

                START: begin
                    // TODO:
                    // Wait half a bit.
                    //
                    // If rx_sync is still 0:
                    //   valid start bit → move to DATA
                    //
                    // Otherwise:
                    //   false start → return to IDLE
                end

                DATA: begin
                    // TODO later:
                    // At each full-bit point:
                    //   save rx_sync into rx_buffer[bit_index]
                    //   move through bit numbers 0 to 7
                end

                PARITY: begin
                    // TODO later:
                    // Sample the parity bit.
                    // Compare it with ^rx_buffer.
                end

                STOP: begin
                    // TODO later:
                    // Check that the stop bit is 1.
                    // Copy rx_buffer into rx_data.
                    // Pulse rx_valid.
                    // Return to IDLE.
                end

                default: begin
                    state   <= IDLE;
                    rx_busy <= 1'b0;
                end

            endcase
        end
    end

endmodule