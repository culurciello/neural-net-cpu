
`include "timescale.vh"

module mac_unit #(
    parameter DATA_WIDTH = 16,
    parameter ACCUM_WIDTH = 48
) (
    input logic clk,
    input logic rst,
    input logic en,
    input logic signed [DATA_WIDTH-1:0] a,
    input logic signed [DATA_WIDTH-1:0] b,
    input logic signed [ACCUM_WIDTH-1:0] acc_in,
    input logic acc_en,
    output logic signed [ACCUM_WIDTH-1:0] c
);

    logic signed [2*DATA_WIDTH-1:0] mult_out;
    logic signed [ACCUM_WIDTH-1:0] mult_ext;
    logic signed [ACCUM_WIDTH-1:0] sum_in;
    logic signed [ACCUM_WIDTH-1:0] sum_out;

    // Pipeline stage 1: Multiplication
    always_ff @(posedge clk) begin
        if (rst) begin
            mult_out <= '0;
        end else if (en) begin
            mult_out <= a * b;
        end
    end

    assign mult_ext = {{(ACCUM_WIDTH-2*DATA_WIDTH){mult_out[2*DATA_WIDTH-1]}}, mult_out};

    // Pipeline stage 2: Accumulation
    always_ff @(posedge clk) begin
        if (rst) begin
            sum_out <= '0;
        end else if (en) begin
            if (acc_en) begin
                sum_in <= acc_in + mult_ext;
            end else begin
                sum_in <= mult_ext;
            end
            sum_out <= sum_in;
        end
    end

    assign c = sum_out;

endmodule
