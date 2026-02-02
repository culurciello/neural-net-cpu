`include "timescale.vh"

module mlp #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 8,
    parameter INPUT_DEPTH = 3072,
    parameter L1_OUTPUT_DEPTH = 512,
    parameter L2_OUTPUT_DEPTH = 256,
    parameter L3_OUTPUT_DEPTH = 10,
    // Memory files
    parameter FC1_WEIGHTS_FILE = "fc1_weights.hex",
    parameter FC1_BIASES_FILE = "fc1_biases.hex",
    parameter FC2_WEIGHTS_FILE = "fc2_weights.hex",
    parameter FC2_BIASES_FILE = "fc2_biases.hex",
    parameter FC3_WEIGHTS_FILE = "fc3_weights.hex",
    parameter FC3_BIASES_FILE = "fc3_biases.hex",
    parameter INPUT_FILE = "input.hex"
) (
    input logic clk,
    input logic rst,
    input logic start,
    output logic done
);
    // Layer 1
    localparam L1_WEIGHTS_DEPTH = INPUT_DEPTH * L1_OUTPUT_DEPTH;
    // Layer 2
    localparam L2_WEIGHTS_DEPTH = L1_OUTPUT_DEPTH * L2_OUTPUT_DEPTH;
    // Layer 3
    localparam L3_WEIGHTS_DEPTH = L2_OUTPUT_DEPTH * L3_OUTPUT_DEPTH;

    // Address widths derived from depths
    localparam INPUT_ADDR_WIDTH = $clog2(INPUT_DEPTH);
    localparam L1_OUTPUT_ADDR_WIDTH = $clog2(L1_OUTPUT_DEPTH);
    localparam L2_OUTPUT_ADDR_WIDTH = $clog2(L2_OUTPUT_DEPTH);
    localparam L3_OUTPUT_ADDR_WIDTH = $clog2(L3_OUTPUT_DEPTH);
    localparam L1_WEIGHTS_ADDR_WIDTH = $clog2(L1_WEIGHTS_DEPTH);
    localparam L2_WEIGHTS_ADDR_WIDTH = $clog2(L2_WEIGHTS_DEPTH);
    localparam L3_WEIGHTS_ADDR_WIDTH = $clog2(L3_WEIGHTS_DEPTH);


    // Signals for BRAMs and layer connections
    // Input BRAM
    logic [INPUT_ADDR_WIDTH-1:0] input_bram_rdaddr_l1;
    logic [DATA_WIDTH-1:0] input_bram_q_l1;

    // Layer 1 outputs to L1_OUT BRAM
    logic [L1_OUTPUT_ADDR_WIDTH-1:0] l1_output_wraddr;
    logic [DATA_WIDTH-1:0] l1_output_wdata;
    logic l1_output_wren;
    logic [L1_OUTPUT_ADDR_WIDTH-1:0] l1_output_rdaddr_l2; // Read address for Layer 2
    logic [DATA_WIDTH-1:0] l1_output_q_l2;         // Read data for Layer 2

    // Layer 1 weights and biases
    logic [L1_WEIGHTS_ADDR_WIDTH-1:0] l1_weights_rdaddr;
    logic [DATA_WIDTH-1:0] l1_weights_q;
    logic [L1_OUTPUT_ADDR_WIDTH-1:0] l1_biases_rdaddr;
    logic [DATA_WIDTH-1:0] l1_biases_q;

    // Layer 2 outputs to L2_OUT BRAM
    logic [L2_OUTPUT_ADDR_WIDTH-1:0] l2_output_wraddr;
    logic [DATA_WIDTH-1:0] l2_output_wdata;
    logic l2_output_wren;
    logic [L2_OUTPUT_ADDR_WIDTH-1:0] l2_output_rdaddr_l3; // Read address for Layer 3
    logic [DATA_WIDTH-1:0] l2_output_q_l3;         // Read data for Layer 3

    // Layer 2 weights and biases
    logic [L2_WEIGHTS_ADDR_WIDTH-1:0] l2_weights_rdaddr;
    logic [DATA_WIDTH-1:0] l2_weights_q;
    logic [L2_OUTPUT_ADDR_WIDTH-1:0] l2_biases_rdaddr;
    logic [DATA_WIDTH-1:0] l2_biases_q;
    logic [DATA_WIDTH-1:0] l2_biases_bram_q;

    // Layer 3 outputs to L3_OUT BRAM (final output)
    logic [L3_OUTPUT_ADDR_WIDTH-1:0] l3_output_wraddr;
    logic [DATA_WIDTH-1:0] l3_output_wdata;
    logic l3_output_wren;
    logic [L3_OUTPUT_ADDR_WIDTH-1:0] l3_output_rdaddr_final;
    logic [DATA_WIDTH-1:0] l3_output_q_final_element; // Renamed to reflect single element read

    // Layer 3 weights and biases
    logic [L3_WEIGHTS_ADDR_WIDTH-1:0] l3_weights_rdaddr;
    logic [DATA_WIDTH-1:0] l3_weights_q;
    logic [L3_OUTPUT_ADDR_WIDTH-1:0] l3_biases_rdaddr;
    logic [DATA_WIDTH-1:0] l3_biases_q;
    logic [DATA_WIDTH-1:0] l3_biases_bram_q;


    // BRAM instances
    // Input BRAM (read by Layer 1)
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(INPUT_DEPTH), .MEM_FILE(INPUT_FILE)) input_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(input_bram_rdaddr_l1), .q(input_bram_q_l1),
        .wren(1'b0), .wraddr('0), .wdata('0) // Read-only BRAM for input
    );
    // Layer 1 Output BRAM (written by L1, read by L2)
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L1_OUTPUT_DEPTH), .MEM_FILE("")) l1_output_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l1_output_rdaddr_l2), .q(l1_output_q_l2),
        .wren(l1_output_wren), .wraddr(l1_output_wraddr), .wdata(l1_output_wdata)
    );
    // Layer 1 Weights BRAM
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L1_WEIGHTS_DEPTH), .MEM_FILE(FC1_WEIGHTS_FILE)) l1_weights_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l1_weights_rdaddr), .q(l1_weights_q),
        .wren(1'b0), .wraddr('0), .wdata('0) // Read-only
    );
    // Layer 1 Biases BRAM
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L1_OUTPUT_DEPTH), .MEM_FILE(FC1_BIASES_FILE)) l1_biases_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l1_biases_rdaddr), .q(l1_biases_q),
        .wren(1'b0), .wraddr('0), .wdata('0) // Read-only
    );
    // Layer 2 Output BRAM (written by L2, read by L3)
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L2_OUTPUT_DEPTH), .MEM_FILE("")) l2_output_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l2_output_rdaddr_l3), .q(l2_output_q_l3),
        .wren(l2_output_wren), .wraddr(l2_output_wraddr), .wdata(l2_output_wdata)
    );
    // Layer 2 Weights BRAM
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L2_WEIGHTS_DEPTH), .MEM_FILE(FC2_WEIGHTS_FILE)) l2_weights_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l2_weights_rdaddr), .q(l2_weights_q),
        .wren(1'b0), .wraddr('0), .wdata('0) // Read-only
    );
    // Layer 2 Biases BRAM
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L2_OUTPUT_DEPTH), .MEM_FILE(FC2_BIASES_FILE)) l2_biases_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l2_biases_rdaddr), .q(l2_biases_bram_q),
        .wren(1'b0), .wraddr('0), .wdata('0) // Read-only
    );
    // Layer 3 Output BRAM (written by L3, read for final output)
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L3_OUTPUT_DEPTH), .MEM_FILE("")) l3_output_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l3_output_rdaddr_final), .q(l3_output_q_final_element),
        .wren(l3_output_wren), .wraddr(l3_output_wraddr), .wdata(l3_output_wdata)
    );
    // Layer 3 Weights BRAM
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L3_WEIGHTS_DEPTH), .MEM_FILE(FC3_WEIGHTS_FILE)) l3_weights_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l3_weights_rdaddr), .q(l3_weights_q),
        .wren(1'b0), .wraddr('0), .wdata('0) // Read-only
    );
    // Layer 3 Biases BRAM
    bram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(L3_OUTPUT_DEPTH), .MEM_FILE(FC3_BIASES_FILE)) l3_biases_bram_inst (
        .clk(clk), .rden(1'b1), .rdaddr(l3_biases_rdaddr), .q(l3_biases_bram_q),
        .wren(1'b0), .wraddr('0), .wdata('0) // Read-only
    );


    logic start_l1, start_l2, start_l3;
    logic done_l1, done_l2, done_l3;

    // Layer instances
    layer #(
        .INPUT_DEPTH(INPUT_DEPTH), .OUTPUT_DEPTH(L1_OUTPUT_DEPTH), .DATA_WIDTH(DATA_WIDTH), .FRAC_BITS(FRAC_BITS)
    ) layer1 (
        .clk(clk), .rst(rst), .start(start_l1), .done(done_l1),
        .input_rdaddr(input_bram_rdaddr_l1), .input_q(input_bram_q_l1),
        .output_wraddr(l1_output_wraddr), .output_wdata(l1_output_wdata), .output_wren(l1_output_wren),
        .weights_rdaddr(l1_weights_rdaddr), .weights_q(l1_weights_q),
        .biases_rdaddr(l1_biases_rdaddr), .biases_q(l1_biases_q)
    );

    layer #(
        .INPUT_DEPTH(L1_OUTPUT_DEPTH), .OUTPUT_DEPTH(L2_OUTPUT_DEPTH), .DATA_WIDTH(DATA_WIDTH), .FRAC_BITS(FRAC_BITS)
    ) layer2 (
        .clk(clk), .rst(rst), .start(start_l2), .done(done_l2),
        .input_rdaddr(l1_output_rdaddr_l2), .input_q(l1_output_q_l2),
        .output_wraddr(l2_output_wraddr), .output_wdata(l2_output_wdata), .output_wren(l2_output_wren),
        .weights_rdaddr(l2_weights_rdaddr), .weights_q(l2_weights_q),
        .biases_rdaddr(l2_biases_rdaddr), .biases_q(l2_biases_bram_q)
    );

    layer #(
        .INPUT_DEPTH(L2_OUTPUT_DEPTH), .OUTPUT_DEPTH(L3_OUTPUT_DEPTH), .DATA_WIDTH(DATA_WIDTH), .FRAC_BITS(FRAC_BITS)
    ) layer3 (
        .clk(clk), .rst(rst), .start(start_l3), .done(done_l3),
        .input_rdaddr(l2_output_rdaddr_l3), .input_q(l2_output_q_l3),
        .output_wraddr(l3_output_wraddr), .output_wdata(l3_output_wdata), .output_wren(l3_output_wren),
        .weights_rdaddr(l3_weights_rdaddr), .weights_q(l3_weights_q),
        .biases_rdaddr(l3_biases_rdaddr), .biases_q(l3_biases_bram_q)
    );
    
    // State machine to control layer execution
    typedef enum logic [2:0] { IDLE, RUN_L1, RUN_L2, RUN_L3, FINISH } mlp_state_t;
    mlp_state_t mlp_state, next_mlp_state;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) mlp_state <= IDLE;
        else mlp_state <= next_mlp_state;
    end

    always_comb begin
        next_mlp_state = mlp_state;
        start_l1 = 1'b0; start_l2 = 1'b0; start_l3 = 1'b0;
        done = 1'b0;

        case(mlp_state)
            IDLE: if(start) next_mlp_state = RUN_L1;
            RUN_L1: begin
                start_l1 = 1'b1;
                if(done_l1) next_mlp_state = RUN_L2;
            end
            RUN_L2: begin
                start_l2 = 1'b1;
                if(done_l2) next_mlp_state = RUN_L3;
            end
            RUN_L3: begin
                start_l3 = 1'b1;
                if(done_l3) next_mlp_state = FINISH;
            end
            FINISH: begin
                done = 1'b1;
                next_mlp_state = IDLE;
            end
            default: begin
                next_mlp_state = IDLE;
            end
        endcase
    end
    
    // output_data and output_class ports are removed.
    // The testbench will directly access the l3_output_bram_inst to get the final results.

endmodule
