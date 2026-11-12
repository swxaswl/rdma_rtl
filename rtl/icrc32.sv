`timescale 1ns / 1ps
// CRC-32C (Castagnoli) ICRC calculator
// Polynomial: 0x1EDC6F41
module icrc32 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        data_valid,
    input  logic [7:0]  data_in,
    input  logic        calc_start,
    input  logic        calc_done,
    output logic [31:0] icrc_out,
    output logic        icrc_valid
);

    // CRC-32C next-state function (single byte)
    function automatic logic [31:0] next_crc32c(
        input logic [31:0] crc,
        input logic [7:0]  data
    );
        logic [31:0] c;
        c = crc ^ {24'b0, data};
        for (int i = 0; i < 8; i++) begin
            if (c[0])
                c = (c >> 1) ^ 32'h82F63B78;  // reflected 0x1EDC6F41
            else
                c = c >> 1;
        end
        return c;
    endfunction

    logic [31:0] crc_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg    <= 32'hFFFFFFFF;
            icrc_out   <= '0;
            icrc_valid <= 1'b0;
        end else begin
            icrc_valid <= 1'b0;
            if (calc_start) begin
                crc_reg <= 32'hFFFFFFFF;
            end else if (data_valid) begin
                crc_reg <= next_crc32c(crc_reg, data_in);
            end else if (calc_done) begin
                icrc_out   <= ~crc_reg;
                icrc_valid <= 1'b1;
            end
        end
    end
endmodule
