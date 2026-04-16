`timescale 1ns / 1ps

module uart_rx (
    input clk,
    input rx,
    output reg rx_ready,
    output reg [7:0] rx_data
);

parameter SRC_FREQ = 76800;
parameter BAUDRATE = 9600;

localparam DATA_BITS = 8;

localparam 
    INIT = 0, 
    IDLE = 1,
    RX_DATA = 2,
    STOP = 3;

// UART clock
wire uart_clk;

clock_mul #(
    .SRC_FREQ(SRC_FREQ),
    .OUT_FREQ(BAUDRATE)
) clk_mul_inst (
    .clk_in(clk),
    .clk_out(uart_clk)
);

// CDC signals
reg rx_ready_uart = 0;
reg rx_ready_sync1 = 0;
reg rx_ready_sync2 = 0;

// State machine regs
reg [1:0] state = INIT;
reg [2:0] bit_count = 0;
reg [7:0] shift_reg = 0;

// UART clock domain FSM
always @(posedge uart_clk) begin
    case (state)
        INIT: begin
            state <= IDLE;
        end

        IDLE: begin
            if (rx == 0) begin
                bit_count <= 0;
                state <= RX_DATA;
            end
        end

        RX_DATA: begin
            shift_reg[bit_count] <= rx;
            if (bit_count == DATA_BITS - 1) begin
                state <= STOP;
            end else begin
                bit_count <= bit_count + 1;
            end
        end

        STOP: begin
            rx_data <= shift_reg;
            rx_ready_uart <= 1;
            state <= IDLE;
        end
    endcase
end

// Clear pulse in UART domain
always @(posedge uart_clk) begin
    if (rx_ready_uart)
        rx_ready_uart <= 0;
end

// CDC to source clock domain (1-cycle pulse)
always @(posedge clk) begin
    rx_ready_sync1 <= rx_ready_uart;
    rx_ready_sync2 <= rx_ready_sync1;
    rx_ready <= rx_ready_sync1 & ~rx_ready_sync2;
end

endmodule