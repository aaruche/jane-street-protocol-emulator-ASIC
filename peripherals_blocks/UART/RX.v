/*
===============================================================================
UART RECEIVER — STATE AND DATA FLOW
===============================================================================

Frame format:

    IDLE → START → DATA[0:7] → PARITY → STOP → IDLE

The UART line is normally high (1). Data is received least-significant bit
first, meaning data bit 0 arrives before data bit 7.

Before entering the state machine, rx_serial passes through two storage stages.
This synchronizes the external signal with clk and reduces the risk of
metastability (an uncertain value when the input changes near a clock edge).

STATE BEHAVIOUR
-------------------------------------------------------------------------------

IDLE:
    - rx_busy is low.
    - The baud counter is held at zero.
    - Wait for a falling edge: previous RX = 1 and current RX = 0.
    - A falling edge may indicate the beginning of a start bit.
    - Clear information left from the previous frame.
    - Raise rx_busy and move to START.

START:
    - Wait HALF_CLKS_PER_BIT clocks.
    - This moves the sampling point to approximately the centre of the
      possible start bit.
    - If RX is still low, the start bit is valid and the receiver enters DATA.
    - If RX is high, the low pulse was a false start, so return to IDLE.

DATA:
    - Wait CLKS_PER_BIT clocks before sampling each data bit.
    - Store the sampled value in rx_buffer[bit_index].
    - Receive bits in the order 0, 1, 2, ... 7.
    - After bit 7 is stored, move to PARITY.

PARITY:
    - Wait CLKS_PER_BIT clocks and sample the parity bit.
    - For even parity, the expected parity value is ^rx_buffer.
    - Compare the received parity bit with the expected value.
    - Save the comparison result and move to STOP.

STOP:
    - Wait CLKS_PER_BIT clocks and sample the stop bit.
    - A correct stop bit is high (1).
    - A low stop bit produces a framing error.
    - Copy the completed rx_buffer into rx_data.
    - Pulse rx_valid for one clock.
    - Output parity_error and framing_error alongside rx_valid.
    - Clear rx_busy and return to IDLE.

OUTPUT MEANINGS
-------------------------------------------------------------------------------

rx_data:
    The most recently completed eight-bit byte.

rx_valid:
    Pulses high for one clock when a complete frame has been received.

rx_busy:
    High while the receiver is processing a frame.

parity_error:
    High alongside rx_valid when the received parity bit does not match the
    expected even-parity value.

framing_error:
    High alongside rx_valid when the received stop bit is not high.

A received byte should normally be accepted only when:

    rx_valid == 1
    parity_error == 0
    framing_error == 0

TIMING EXAMPLE — 10 CLOCKS PER UART BIT
-------------------------------------------------------------------------------

    Falling edge detected : clock 0
    Check start bit       : clock 5
    Sample data bit 0     : clock 15
    Sample data bit 1     : clock 25
    ...
    Sample data bit 7     : clock 85
    Sample parity         : clock 95
    Sample stop           : clock 105

The receiver samples near the centre of each UART bit because that is where
the signal is least likely to be changing.
===============================================================================
*/
`timescale 1ns/1ps

module RX #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9_600
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_serial,

    output reg  [7:0] rx_data,
    output reg        rx_valid,                     // high when a complete byte, including parity and stop bit, is ready.
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


    wire half_bit_tick;
    wire full_bit_tick;

    // signal for reaching half a bit.
    assign half_bit_tick =
        (state == START) &&                         // state = START bcus only in START state we will be using half_bit_tick to check for FALSE START 
        (baud_counter == HALF_CLKS_PER_BIT - 1);

    // signal for reaching one complete bit.
    assign full_bit_tick =
        ((state == DATA)   ||
        (state == PARITY) ||
        (state == STOP)) &&
        (baud_counter == CLKS_PER_BIT - 1);


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

    
    
    // start_edge is true when the previous synchronized value was 1
    // and the current synchronized value is 0.
    wire start_edge ; 
    assign start_edge = rx_previous && (!rx_sync) ;     // rx_sync is current sync rx ip 
                                                        // rx =rx_previous is prev sync value   
    

    //============================================================
    // Received-frame storage
    //============================================================

    reg [7:0] rx_buffer;
    reg [2:0] bit_index;
    reg       saved_parity_error;

    //============================================================
    // Baud counter
    
    always @(posedge clk) begin
        if (!rst_n) begin
            baud_counter <= {COUNTER_WIDTH{1'b0}};
        end
        else begin
            case (state)

                IDLE: begin
                    // There is no frame to measure yet.
                    baud_counter <= {COUNTER_WIDTH{1'b0}};
                end

                START: begin
                    // Measure only half a bit so we can check
                    // the centre of the possible start bit.
                    if (half_bit_tick)
                        baud_counter <= {COUNTER_WIDTH{1'b0}};
                    else
                        baud_counter <= baud_counter + 1'b1;
                end

                DATA,
                PARITY,
                STOP: begin
                    // Move from the centre of one UART bit
                    // to the centre of the following bit.
                    if (full_bit_tick)
                        baud_counter <= {COUNTER_WIDTH{1'b0}};
                    else
                        baud_counter <= baud_counter + 1'b1;
                end

                default: begin
                    baud_counter <= {COUNTER_WIDTH{1'b0}};
                end

            endcase
        end
    end
   
           
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
    


    //============================================================

      // RX state controller

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
                    rx_busy <= 1'b0;                // Keep rx_busy low

                    if (start_edge) begin           // Wait for start_edge
                        rx_buffer <= 8'b0;          // clear old frame information
                        rx_busy   <= 1'b1;          // raise rx_busy
                        saved_parity_error <= 1'b0;
                        state     <= START;         // move to START State 
                    end 
                    end

                START: begin        // wait half a bit period
                    
                    if (half_bit_tick) begin 
                        if (!rx_sync)begin 
                            bit_index <= 3'b0;  // start bit is 0th bit 
                            state     <= DATA; 
                        end 
                        else begin 
                            rx_busy  <= 1'b0; 
                            state    <= IDLE; 
                        end 
                    end 
                    // If rx_sync is still 0:
                    //   valid start bit → move to DATA
                    //
                    // Otherwise:
                    //   false start → return to IDLE
                end

                DATA: begin
                    if (full_bit_tick) begin 

                        rx_buffer[bit_index] <= rx_sync ; 
                        
                        if(bit_index == 3'd7) begin
                            state <= PARITY; 
                         end
                        else begin
                            bit_index  <= bit_index + 1'b1;
                         end 
                    end 
                    
                    // At each full-bit point:
                    // save rx_sync into rx_buffer[bit_index]
                    // move through bit numbers 0 to 7
                end

                PARITY: begin
                    if (full_bit_tick) begin

                        // For even parity, ^rx_buffer is the expected parity bit.
                        saved_parity_error <= (rx_sync != ^rx_buffer);      
                        state <= STOP;
                    end
                    // Sample the parity bit.
                    // Compare it with ^rx_buffer.
                end

                STOP: begin
                    if (full_bit_tick) begin

                        // Publish the completed byte.
                        rx_data <= rx_buffer;

                        // All three outputs pulse together for one clock.
                        rx_valid      <= 1'b1;
                        parity_error  <= saved_parity_error;
                        framing_error <= !rx_sync;                      // checks if the stop bit is correct (ie high)

                        // Reception has finished.
                        rx_busy <= 1'b0;
                        state   <= IDLE;
                    end
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