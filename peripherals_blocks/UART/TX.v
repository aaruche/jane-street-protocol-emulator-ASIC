/*

- State sequence: IDLE → START → DATA → PARITY → STOP → IDLE

- Parity checks whether the number of 1 bits is even or odd.
    Even parity bit must be 1
    Odd parity bit must be 0

- At every Baud_tick && posedge clk, Data/Start/Stop/parity bit is sent (when tx_start goes high in the past)

- Interface rule: Assert tx_start for one clock only while tx_busy is zero.
    A tx_start pulse occurring while busy is high will be ignored!!!
    Holding tx_start high for too long could cause another transmission when the UART returns to IDLE.

*/
`timescale 1ns/1ps

module TX #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9_600
) (
    input  wire       clk,
    input  wire       rst_n,

    // Simple internal request interface. 
    input  wire [7:0] tx_data,
    input  wire       tx_start,                 // Start transmitting 

    output reg        tx_serial,
    output reg        tx_busy,
    output reg        tx_done
);
//=================================================
    // States 
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] START  = 3'd1;
    localparam [2:0] DATA   = 3'd2;
    localparam [2:0] PARITY = 3'd3;
    localparam [2:0] STOP   = 3'd4;

    // used for State logic 
    reg [2:0] state;                    
    reg [7:0] tx_buffer;            // holds 8 data bits 
    reg [2:0] bit_index;            // pointer for sending nth bit data 
    reg       parity_bit;           // error handling 

//=================================================

    // Adding BAUD_RATE/2 before division rounds to the nearest whole clock.
    // With 100 MHz and 9,600 baud, this becomes 10,417 clocks per UART bit.
    localparam integer CLKS_PER_BIT = (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;

    reg [13:0] baud_counter; 
    wire baud_tick ; 

    assign baud_tick = tx_busy && (baud_counter == CLKS_PER_BIT - 1);


    // BAUD COUNTER LOGIC 
    always @(posedge clk) begin
        if (!rst_n) begin
            baud_counter <= 14'd0;
        end
        else if (!tx_busy) begin    // ie idle 
            baud_counter <= 14'd0;
        end 
        else if (baud_tick) begin   // back to zero 
            baud_counter <= 14'd0;
        end 
        else begin                  // otherwise increment at every clk edge 
            baud_counter <= baud_counter + 14'd1;
        end
    end

//===================================================

    // STATE CONTROLLER LOGIC 
    always @(posedge clk) begin
    if (!rst_n) begin
        
        state       <= IDLE;    // UART is high while idle.
        tx_serial   <= 1'b1;
        tx_busy     <= 1'b0;    // No byte is being sent.
        tx_done     <= 1'b0;    // No completed-byte notification.
        tx_buffer   <= 8'd0;
        bit_index   <= 3'd0;
        parity_bit  <= 1'b0;
    end else begin
        
        tx_done <= 1'b0;        // Default: normally no completion pulse.

        case (state)

            IDLE: begin
                tx_serial <= 1'b1;
                tx_busy   <= 1'b0;

                if (tx_start) begin
                    tx_buffer  <= tx_data;
                    parity_bit <= ^tx_data; // Even parity
                    tx_serial  <= 1'b0;
                    tx_busy    <= 1'b1;
                    state      <= START;
                end
            end

            START: begin
                
                if (baud_tick) begin
                    tx_serial <= tx_buffer[0];              // At the final clock edge of the start bit (transition of START to DATA),
                                                            // so technically happens in DATA state 
                    bit_index <= 3'd0;
                    state     <= DATA;
                end
            end

            DATA: begin
                if (baud_tick) begin
                    if (bit_index == 3'd7) begin            // checking the final data bit
                        tx_serial <= parity_bit;            // now send the parity bit 
                        state     <= PARITY;
                    end else begin                          // otehrwise send the next data bit 
                        bit_index <= bit_index + 3'd1;
                        tx_serial <= tx_buffer[bit_index + 3'd1];
                    end
                end
            end

            PARITY: begin
                if (baud_tick) begin
                    tx_serial <= 1'b1;                      // sending the STOP bit 
                    state     <= STOP;                      // proceed to STOP state 
                end
            end

            STOP: begin
                if (baud_tick) begin
                    tx_serial <= 1'b1;                      // pulled high when not busy 
                    tx_busy   <= 1'b0;
                    tx_done   <= 1'b1;                      // send tx_done outside this module (YAY)
                    state     <= IDLE;
                end
            end

            default: begin
                tx_serial <= 1'b1;                          // pulled high when not busy 
                tx_busy   <= 1'b0;
                state     <= IDLE;
            end

        endcase
    end
end

endmodule