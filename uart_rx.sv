`include "clock_mul.sv"

module uart_rx (
    input clk,
    input rx,
    output reg rx_ready,
    output reg [7:0] rx_data
);

parameter SRC_FREQ = 76800;
parameter BAUDRATE = 9600;

// STATES: State of the state machine
localparam DATA_BITS = 8;
localparam 
    INIT = 0, 
    IDLE = 1,
    RX_DATA = 2,
    STOP = 3;

// CLOCK MULTIPLIER: Instantiate the clock multiplier
wire uart_clk;
clock_mul #(
    .SRC_FREQ(SRC_FREQ),
    .OUT_FREQ(BAUDRATE)
) clk_mul_inst (
    .src_clk(clk),
    .out_clk(uart_clk)
);

// State machine registers
reg [1:0] state = INIT;
reg [2:0] bit_count = 0;
reg [7:0] shift_reg = 0;

// Internal ready flag in uart clock domain
reg rx_ready_uart = 0;

// CROSS CLOCK DOMAIN: Two-flip-flop synchronizer for rx_ready
reg sync1 = 0, sync2 = 0;

// STATE MACHINE: Use the UART clock to drive the state machine
always @(posedge uart_clk) begin
    case (state)
        INIT: begin
            state <= IDLE;
        end

        IDLE: begin
            if (rx == 1'b0) begin  // Start bit detected
                bit_count <= 0;
                state <= RX_DATA;
            end
        end

        RX_DATA: begin
            shift_reg[bit_count] <= rx;
            if (bit_count == DATA_BITS-1)
                state <= STOP;
            else
                bit_count <= bit_count + 1;
        end

        STOP: begin
            rx_data <= shift_reg;
            rx_ready_uart <= 1;
            state <= IDLE;
        end
    endcase
end

// Clear the ready flag after one cycle
always @(posedge uart_clk) begin
    if (rx_ready_uart)
        rx_ready_uart <= 0;
end

// Clock domain crossing for rx_ready
always @(posedge clk) begin
    sync1 <= rx_ready_uart;
    sync2 <= sync1;
    rx_ready <= sync1 & ~sync2;
end

endmodule