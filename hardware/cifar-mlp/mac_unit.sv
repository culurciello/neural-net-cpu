
`include "timescale.vh"

module mac_unit #(
    parameter DATA_WIDTH = 16,
    parameter ACCUM_WIDTH = 48,
    parameter VEC = 16
) (
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  logic [VEC*DATA_WIDTH-1:0] a,
    input  logic [VEC*DATA_WIDTH-1:0] b,
    input  logic signed [ACCUM_WIDTH-1:0] acc_in,
    input  logic acc_en,
    output logic signed [ACCUM_WIDTH-1:0] c
);

    logic signed [ACCUM_WIDTH-1:0] sum_comb;

    integer i;
    always_comb begin
        sum_comb = '0;
        for (i = 0; i < VEC; i++) begin
            logic signed [DATA_WIDTH-1:0] a_lane;
            logic signed [DATA_WIDTH-1:0] b_lane;
            logic signed [2*DATA_WIDTH-1:0] prod;
            a_lane = a[i*DATA_WIDTH +: DATA_WIDTH];
            b_lane = b[i*DATA_WIDTH +: DATA_WIDTH];
            prod = a_lane * b_lane;
            sum_comb = sum_comb + {{(ACCUM_WIDTH-2*DATA_WIDTH){prod[2*DATA_WIDTH-1]}}, prod};
        end
    end

    assign c = acc_en ? (acc_in + sum_comb) : sum_comb;

endmodule
