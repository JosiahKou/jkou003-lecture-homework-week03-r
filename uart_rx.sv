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

localparam BIT_PERIOD = SRC_FREQ / BAUDRATE;  // = 8
localparam HALF_BIT = BIT_PERIOD / 2;         // = 4

// CLOCK MULTIPLIER: Instantiate the clock multiplier
wire uart_clk;
clock_mul #(
    .SRC_FREQ(SRC_FREQ),
    .OUT_FREQ(BAUDRATE)
) clock_mul_inst (
    .src_clk(clk),
    .out_clk(uart_clk)
);

// State machine registers
reg [1:0] state;
reg [2:0] bit_count;
reg [7:0] shift_reg;
reg [3:0] counter;
reg [1:0] rx_sync;

// Synchronize rx to uart clock domain
always @(posedge uart_clk) begin
    rx_sync[0] <= rx;
    rx_sync[1] <= rx_sync[0];
end

reg ready_flag;
reg [1:0] ready_sync;

// CROSS CLOCK DOMAIN: The rx_ready flag should only be set 1 one for one source 
// clock cycle. Use the cross clock domain technique discussed in class to handle this.
always @(posedge clk) begin
    ready_sync[0] <= ready_flag;
    ready_sync[1] <= ready_sync[0];
    rx_ready <= ready_sync[1] && !ready_sync[0];
end

// STATE MACHINE: Use the UART clock to drive that state machine that receives a byte from the rx signal
always @(posedge uart_clk) begin
    case (state)
        IDLE: begin
            ready_flag <= 0;
            if (rx_sync[1] == 1'b0) begin  // Start bit detected
                state <= RX_DATA;
                bit_count <= 0;
                counter <= 0;
            end
        end
        
        RX_DATA: begin
            counter <= counter + 1;
            if (counter == BIT_PERIOD - 1) begin
                counter <= 0;
                shift_reg[bit_count] <= rx_sync[1];
                bit_count <= bit_count + 1;
                if (bit_count == 7) begin
                    state <= STOP;
                end
            end
        end
        
        STOP: begin
            counter <= counter + 1;
            if (counter == BIT_PERIOD - 1) begin
                rx_data <= shift_reg;
                ready_flag <= 1;
                state <= IDLE;
            end
        end
        
        default: state <= IDLE;
    endcase
end

endmodule