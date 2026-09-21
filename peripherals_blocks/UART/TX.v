`timescale 1ns/1ps

module TX #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9_600
) (
    input  wire       clk,
    input  wire       rst_n,

    // Simple internal request interface. A future processor/UART wrapper can
    // turn an accepted write to UART_TXDATA into a one-clock tx_start pulse.
    input  wire [7:0] tx_data,
    input  wire       tx_start,

    output reg        tx_serial,
    output reg        tx_busy,
    output reg        tx_done
);

    // Adding BAUD_RATE/2 before division rounds to the nearest whole clock.
    // With 100 MHz and 9,600 baud, this becomes 10,417 clocks per UART bit.
    localparam integer CLKS_PER_BIT =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;

    // This first skeleton uses an active-low, synchronous reset:
    // rst_n = 0 resets the transmitter on the next rising edge of clk.
    always @(posedge clk) begin
        if (!rst_n) begin
            tx_serial <= 1'b1;  // UART is high while idle.
            tx_busy   <= 1'b0;  // No byte is being sent.
            tx_done   <= 1'b0;  // No completed-byte notification.
        end else begin
            // tx_done will eventually be a one-clock pulse, so its normal
            // default value is zero.
            tx_done <= 1'b0;

            // Next milestone:
            // 1. Add the baud counter here.
            // 2. Accept tx_data when tx_start is high and tx_busy is low.
            // 3. Add the IDLE -> START -> DATA -> STOP states.
        end
    end

endmodule