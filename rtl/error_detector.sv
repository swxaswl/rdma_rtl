`timescale 1ns / 1ps
module error_detector
    import rdma_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        retry_exceeded_i,
    input  logic        rkey_err_i,
    input  logic        addr_err_i,
    input  logic        rnr_nak_i,
    input  logic        link_down_i,
    input  logic        icrc_err_i,
    output err_type_e   err_type_o,
    output logic        err_valid_o,
    output logic        qp_reset_req_o,
    output logic        rtx_req_o
);

    err_type_e err_type_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            err_type_r    <= ERR_NONE;
            err_valid_o   <= 1'b0;
            qp_reset_req_o<= 1'b0;
            rtx_req_o     <= 1'b0;
        end else begin
            err_valid_o    <= 1'b0;
            qp_reset_req_o <= 1'b0;
            rtx_req_o      <= 1'b0;

            if (retry_exceeded_i) begin
                err_type_r    <= ERR_RETRY;
                err_valid_o   <= 1'b1;
                qp_reset_req_o<= 1'b1;
            end else if (rkey_err_i) begin
                err_type_r  <= ERR_RKEY;
                err_valid_o <= 1'b1;
                rtx_req_o   <= 1'b1;
            end else if (addr_err_i) begin
                err_type_r  <= ERR_ADDR;
                err_valid_o <= 1'b1;
                rtx_req_o   <= 1'b1;
            end else if (rnr_nak_i) begin
                err_type_r  <= ERR_RNR;
                err_valid_o <= 1'b1;
                rtx_req_o   <= 1'b1;
            end else if (link_down_i) begin
                err_type_r    <= ERR_LINK;
                err_valid_o   <= 1'b1;
                qp_reset_req_o<= 1'b1;
            end else if (icrc_err_i) begin
                err_type_r  <= ERR_ICRC;
                err_valid_o <= 1'b1;
                rtx_req_o   <= 1'b1;
            end
        end
    end

    assign err_type_o = err_type_r;
endmodule
