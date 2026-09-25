`timescale 1ns/1ps

/*
 * UART wrapper
 *
 * This block joins the TX and RX modules and presents a small, processor-
 * friendly interface. A transmit write is accepted when tx_write_ready is
 * high. A received byte remains available until rx_read is asserted.
 */
module UART #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9_600
) (
    input  wire       clk,
    input  wire       rst_n,

    // External UART pins.
    input  wire       rx_serial,
    output wire       tx_serial,

    // Transmit interface.
    // Pulse tx_write for one clock while tx_write_ready is high.
    input  wire [7:0] tx_write_data,
    input  wire       tx_write,
    output wire       tx_write_ready,
    output wire       tx_busy,
    output wire       tx_done,

    // Receive interface.
    // rx_read consumes the byte currently indicated by rx_read_valid.
    output reg  [7:0] rx_read_data,
    output reg        rx_read_valid,
    input  wire       rx_read,
    output wire       rx_busy,

    // These flags describe the byte stored in rx_read_data.
    output reg        parity_error,
    output reg        framing_error,

    // High when an unread byte was replaced by a newer received byte.
    output reg        rx_overrun
);

    // A write is accepted only when the transmitter is free.
    wire tx_start;
    assign tx_write_ready = !tx_busy;
    assign tx_start       = tx_write && tx_write_ready;

    TX #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) tx_instance (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_data   (tx_write_data),
        .tx_start  (tx_start),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    wire [7:0] received_data;
    wire       received_valid;
    wire       received_parity_error;
    wire       received_framing_error;

    RX #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) rx_instance (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_serial     (rx_serial),
        .rx_data       (received_data),
        .rx_valid      (received_valid),
        .rx_busy       (rx_busy),
        .parity_error  (received_parity_error),
        .framing_error (received_framing_error)
    );

    // Keep a received byte until the processor reads it. Receiving a new byte
    // has priority over a simultaneous read, so the new byte is not lost.
    always @(posedge clk) begin
        if (!rst_n) begin
            rx_read_data   <= 8'h00;
            rx_read_valid  <= 1'b0;
            parity_error   <= 1'b0;
            framing_error  <= 1'b0;
            rx_overrun     <= 1'b0;
        end else if (received_valid) begin
            if (rx_read_valid && !rx_read)
                rx_overrun <= 1'b1;
            else
                rx_overrun <= 1'b0;

            rx_read_data  <= received_data;
            rx_read_valid <= 1'b1;
            parity_error  <= received_parity_error;
            framing_error <= received_framing_error;
        end else if (rx_read) begin
            rx_read_valid <= 1'b0;
            parity_error  <= 1'b0;
            framing_error <= 1'b0;
            rx_overrun    <= 1'b0;
        end
    end

endmodule