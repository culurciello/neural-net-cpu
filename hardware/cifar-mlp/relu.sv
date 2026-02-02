
`include "timescale.vh"

module relu #(
    parameter DATA_WIDTH = 16
)(
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    // ReLU activation function
    // If the most significant bit is 1, the number is negative, so output 0.
    // Otherwise, the number is positive, so pass it through.
    assign dout = (din[DATA_WIDTH-1] == 1'b1) ? '0 : din;

endmodule
