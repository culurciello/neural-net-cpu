`include "timescale.vh"
`include "mlp.sv"

module mlp_tb;

    // Parameters
    localparam DATA_WIDTH = 16;
    localparam L3_OUTPUT_DEPTH = 10;
    localparam VEC = 16;
    localparam L3_OUTPUT_VEC_DEPTH = (L3_OUTPUT_DEPTH + VEC - 1) / VEC;
    localparam CLK_PERIOD = 10;

    // Signals
    logic clk;
    logic rst;
    logic start;
    logic done;
    logic [DATA_WIDTH-1:0] final_output_data [L3_OUTPUT_DEPTH-1:0];
    logic [$clog2(L3_OUTPUT_DEPTH)-1:0] output_class;
    real max_val_real;
    logic [VEC*DATA_WIDTH-1:0] packed_word;

    // Instantiate the MLP
    mlp #(
        .DATA_WIDTH(DATA_WIDTH),
        .INPUT_DEPTH(3072),
        .L1_OUTPUT_DEPTH(512),
        .L2_OUTPUT_DEPTH(256),
        .L3_OUTPUT_DEPTH(L3_OUTPUT_DEPTH),
        .FC1_WEIGHTS_FILE("fc1_weights.hex"),
        .FC1_BIASES_FILE("fc1_biases.hex"),
        .FC2_WEIGHTS_FILE("fc2_weights.hex"),
        .FC2_BIASES_FILE("fc2_biases.hex"),
        .FC3_WEIGHTS_FILE("fc3_weights.hex"),
        .FC3_BIASES_FILE("fc3_biases.hex"),
        .INPUT_FILE("input.hex")
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done)
    );

    // Clock generator
    always #(CLK_PERIOD/2) clk = ~clk;

    // Main simulation sequence
    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        start = 0;
        #(2 * CLK_PERIOD);
        rst = 0;
        #(2 * CLK_PERIOD);

        // Start the MLP
        start = 1;
        #(CLK_PERIOD);
        start = 0;

        // Wait for completion
        wait(done);

        // Read output data from the final BRAM
        for (int w = 0; w < L3_OUTPUT_VEC_DEPTH; w++) begin
            packed_word = uut.l3_output_bram_inst.mem[w];
            for (int lane = 0; lane < VEC; lane++) begin
                int idx;
                idx = w * VEC + lane;
                if (idx < L3_OUTPUT_DEPTH) begin
                    final_output_data[idx] = packed_word[lane*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end

        // Calculate output_class in testbench
        output_class = '0;
        max_val_real = -1.0e30;
        for (int i = 0; i < L3_OUTPUT_DEPTH; i++) begin
            real v;
            v = fixed_to_real(final_output_data[i], 8);
            if (v > max_val_real) begin
                max_val_real = v;
                output_class = i[$clog2(L3_OUTPUT_DEPTH)-1:0];
            end
        end

        // Display results
        $display("MLP inference done.");
        $display("Output class: %d", output_class);
        for (int i = 0; i < L3_OUTPUT_DEPTH; i++) begin
            real v;
            v = fixed_to_real(final_output_data[i], 8);
            $display("Output[%0d]: %h (%f)", i, final_output_data[i], v);
        end

        // Finish simulation
        $finish;
    end

    function automatic real fixed_to_real(input logic [DATA_WIDTH-1:0] val, input int frac_bits);
        integer signed signed_val;
        real scale;
        begin
            signed_val = $signed({{(32-DATA_WIDTH){val[DATA_WIDTH-1]}}, val});
            scale = 1.0 * (1 << frac_bits);
            fixed_to_real = signed_val / scale;
        end
    endfunction

endmodule
