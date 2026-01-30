// E. Culurciello, January 2026
// Top-level for neural-net-cpu

module neural_net_cpu(
  input clk,
  input rst,
  input signed [159:0] in_vec,
  output signed [31:0] out_vec
);


  mlp_c1 #(
    .WIDTH(16),
    .FRAC(8)
  ) mlp_c1_inst (
    .in_vec(in_vec),
    .out_vec(out_vec)
  );

endmodule
