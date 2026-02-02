`include "timescale.vh"

module layer #(
    parameter INPUT_DEPTH = 3072,
    parameter OUTPUT_DEPTH = 512,
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 8,
    parameter ACCUM_WIDTH = 48
) (
    input logic clk,
    input logic rst,
    input logic start,
    output logic done,

    // Input RAM interface
    output logic [$clog2(INPUT_DEPTH)-1:0] input_rdaddr,
    input  logic [DATA_WIDTH-1:0] input_q,

    // Output RAM interface (write side)
    output logic [$clog2(OUTPUT_DEPTH)-1:0] output_wraddr,
    output logic [DATA_WIDTH-1:0] output_wdata,
    output logic output_wren,

    // Weights BRAM interface
    output logic [$clog2(INPUT_DEPTH * OUTPUT_DEPTH)-1:0] weights_rdaddr,
    input  logic [DATA_WIDTH-1:0] weights_q,

    // Biases BRAM interface
    output logic [$clog2(OUTPUT_DEPTH)-1:0] biases_rdaddr,
    input  logic [DATA_WIDTH-1:0] biases_q
);

    localparam int INPUT_ADDR_WIDTH = $clog2(INPUT_DEPTH);
    localparam int OUTPUT_ADDR_WIDTH = $clog2(OUTPUT_DEPTH);
    localparam int WEIGHT_ADDR_WIDTH = $clog2(INPUT_DEPTH * OUTPUT_DEPTH);
    localparam int unsigned INPUT_DEPTH_INT = INPUT_DEPTH;
    localparam int unsigned OUTPUT_DEPTH_INT = OUTPUT_DEPTH;
    localparam logic [INPUT_ADDR_WIDTH-1:0] INPUT_DEPTH_VAL = INPUT_DEPTH_INT[INPUT_ADDR_WIDTH-1:0];
    localparam logic [OUTPUT_ADDR_WIDTH-1:0] OUTPUT_DEPTH_VAL = OUTPUT_DEPTH_INT[OUTPUT_ADDR_WIDTH-1:0];
    localparam logic [INPUT_ADDR_WIDTH-1:0] INPUT_LAST = INPUT_DEPTH_VAL - 1'b1;
    localparam logic [OUTPUT_ADDR_WIDTH-1:0] OUTPUT_LAST = OUTPUT_DEPTH_VAL - 1'b1;

    typedef enum logic [3:0] {
        IDLE,
        FETCH_BIAS,
        MAC_LOOP,
        MAC_WAIT,
        ADD_BIAS_RELU,
        WRITE_OUTPUT,
        DONE_NEURON,
        FINISH
    } state_t;

    state_t state, next_state;

    logic [$clog2(OUTPUT_DEPTH)-1:0] neuron_idx, next_neuron_idx;
    logic [$clog2(INPUT_DEPTH)-1:0] input_idx, next_input_idx;
    logic signed [ACCUM_WIDTH-1:0] accum, next_accum;
    logic [WEIGHT_ADDR_WIDTH-1:0] weight_addr, next_weight_addr;
    logic [WEIGHT_ADDR_WIDTH-1:0] input_depth_offset;

    logic start_mac;
    logic signed [ACCUM_WIDTH-1:0] mac_result;
    logic signed [DATA_WIDTH-1:0] bias_val;
    logic signed [ACCUM_WIDTH-1:0] accum_plus_bias;
    
    // MAC unit has a 2 cycle latency
    logic start_mac_d1, start_mac_d2; 

    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) mac (
        .clk(clk),
        .rst(rst),
        .en(start_mac),
        .a(input_q),
        .b(weights_q),
        .acc_in(accum),
        .acc_en(input_idx != 0),
        .c(mac_result)
    );

    relu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) relu_inst (
        .din(accum_plus_bias[FRAC_BITS + DATA_WIDTH-1 : FRAC_BITS]), // Truncate to DATA_WIDTH
        .dout(output_wdata)
    );

    // State register
    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else state <= next_state;
    end
    
    // MAC latency pipeline
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            start_mac_d1 <= 1'b0;
            start_mac_d2 <= 1'b0;
        end else begin
            start_mac_d1 <= start_mac;
            start_mac_d2 <= start_mac_d1;
        end
    end

    // FSM
    always_comb begin
        next_state = state;
        done = 1'b0;
        start_mac = 1'b0;
        output_wren = 1'b0;
        input_depth_offset = {{(WEIGHT_ADDR_WIDTH-INPUT_ADDR_WIDTH){1'b0}}, (INPUT_DEPTH_VAL - input_idx)};

        // Default assignments
        next_neuron_idx = neuron_idx;
        next_input_idx = input_idx;
        next_accum = accum;
        next_weight_addr = weight_addr;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FETCH_BIAS;
                    next_neuron_idx = '0;
                    next_input_idx = '0;
                    next_accum = '0;
                    next_weight_addr = '0;
                end
            end
            FETCH_BIAS: begin
                // Bias is available on the next cycle
                next_state = MAC_LOOP;
            end
            MAC_LOOP: begin
                start_mac = 1'b1;
                if (input_idx == INPUT_LAST) begin
                    next_state = MAC_WAIT;
                end else begin
                    next_input_idx = input_idx + 1;
                    next_weight_addr = weight_addr + 1;
                end
                // The accumulator is updated with a delay
                if(start_mac_d2) begin
                    next_accum = mac_result;
                end
            end
            MAC_WAIT: begin
                // Wait for MAC pipeline to finish
                if (start_mac_d2) begin
                    next_accum = mac_result;
                    next_state = ADD_BIAS_RELU;
                end
            end
            ADD_BIAS_RELU: begin
                // Bias was fetched in FETCH_BIAS state, it should be stable
                // The final accumulated value is in accum register
                next_state = WRITE_OUTPUT;
            end
            WRITE_OUTPUT: begin
                output_wren = 1'b1;
                next_state = DONE_NEURON;
            end
            DONE_NEURON: begin
                if (neuron_idx == OUTPUT_LAST) begin
                    next_state = FINISH;
                end else begin
                    next_state = FETCH_BIAS;
                    next_neuron_idx = neuron_idx + 1;
                    next_input_idx = '0;
                    next_accum = '0;
                    // The weight_addr for the next neuron starts where the current one left off, plus INPUT_DEPTH
                    next_weight_addr = weight_addr + input_depth_offset;
                end
            end
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Bias register
    always_ff @(posedge clk) begin
        if(state == FETCH_BIAS) begin
            bias_val <= biases_q;
        end
    end

    // Accumulator for bias addition
    always_ff @(posedge clk) begin
        if(state == ADD_BIAS_RELU) begin
            // Sign extend bias to match accumulator width
            accum_plus_bias <= accum + {{ACCUM_WIDTH-DATA_WIDTH{bias_val[DATA_WIDTH-1]}}, bias_val};
        end
    end

    // Address and data registers
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            neuron_idx <= '0;
            input_idx  <= '0;
            accum <= '0;
            weight_addr <= '0;
        end else begin
            neuron_idx <= next_neuron_idx;
            input_idx  <= next_input_idx;
            accum <= next_accum;
            weight_addr <= next_weight_addr;
        end
    end

    // Memory address generation
    always_comb begin
        input_rdaddr = input_idx;
        weights_rdaddr = weight_addr;
        biases_rdaddr = neuron_idx;
        output_wraddr = neuron_idx;
    end

endmodule
