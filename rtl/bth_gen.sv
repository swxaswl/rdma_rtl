`timescale 1ns / 1ps
module bth_gen
    import rdma_pkg::*;
(
    input  logic            clk,
    input  logic            rst_n,
    input  logic            hdr_en,
    input  opcode_e         opcode_i,
    input  logic [23:0]     dest_qpn_i,
    input  logic [23:0]     psn_i,
    input  logic [15:0]     pkey_i,
    input  logic            ack_req_i,
    input  logic            reth_en_i,
    input  logic [63:0]     remote_addr_i,
    input  logic [31:0]     remote_rkey_i,
    input  logic [31:0]     dma_len_i,
    input  logic            aeth_en_i,
    input  logic [7:0]      syndrome_i,
    input  logic [23:0]     msn_i,
    output bth_t            bth_o,
    output reth_t           reth_o,
    output aeth_t           aeth_o,
    output logic            bth_valid_o,
    output logic            reth_valid_o,
    output logic            aeth_valid_o
);
    bth_t  bth_r;
    reth_t reth_r;
    aeth_t aeth_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bth_r <= '0; reth_r <= '0; aeth_r <= '0;
            bth_valid_o <= 1'b0; reth_valid_o <= 1'b0; aeth_valid_o <= 1'b0;
        end else begin
            bth_valid_o  <= 1'b0;
            reth_valid_o <= 1'b0;
            aeth_valid_o <= 1'b0;
            if (hdr_en) begin
                bth_r.opcode   <= opcode_i;
                bth_r.se       <= 1'b0;
                bth_r.m        <= 1'b0;
                bth_r.pad_cnt  <= 2'b00;
                bth_r.tver     <= 4'b0;
                bth_r.pkey     <= pkey_i;
                bth_r.f        <= 1'b0;
                bth_r.b        <= 1'b0;
                bth_r.dest_qpn <= dest_qpn_i;
                bth_r.ack_req  <= ack_req_i;
                bth_r.psn      <= psn_i;
                bth_valid_o    <= 1'b1;
                if (reth_en_i) begin
                    reth_r.remote_addr  <= remote_addr_i;
                    reth_r.remote_rkey  <= remote_rkey_i;
                    reth_r.dma_len      <= dma_len_i;
                    reth_valid_o        <= 1'b1;
                end
                if (aeth_en_i) begin
                    aeth_r.syndrome <= syndrome_i;
                    aeth_r.msn      <= msn_i;
                    aeth_valid_o    <= 1'b1;
                end
            end
        end
    end

    assign bth_o  = bth_r;
    assign reth_o = reth_r;
    assign aeth_o = aeth_r;
endmodule
