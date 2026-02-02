
`include "timescale.vh"

module bram #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 1024,
    parameter MEM_FILE = "" // Add back MEM_FILE
) (
    input logic clk,
    input logic rden,
    input logic [$clog2(DEPTH)-1:0] rdaddr,
    output logic [DATA_WIDTH-1:0] q,
    // Add write ports
    input logic wren,
    input logic [$clog2(DEPTH)-1:0] wraddr,
    input logic [DATA_WIDTH-1:0] wdata
);

    logic [DATA_WIDTH-1:0] mem [DEPTH-1:0]; // Back to 'logic'

    initial begin
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, mem);
        end
    end

    // Read operation
    always_ff @(posedge clk) begin
        if (rden) begin
            q <= mem[rdaddr];
        end
    end

    // Write operation
    always_ff @(posedge clk) begin
        if (wren) begin
            mem[wraddr] <= wdata;
        end
    end

    // Task to dump memory contents for testbench
    task automatic dump_mem(output logic [DATA_WIDTH-1:0] dump_array [DEPTH-1:0]);
        for (int i = 0; i < DEPTH; i++) begin
            dump_array[i] = mem[i];
        end
    endtask

endmodule
