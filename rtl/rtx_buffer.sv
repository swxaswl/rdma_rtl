`timescale 1ns / 1ps
module rtx_buffer
    import rdma_pkg::*;
#(
    parameter int unsigned BUF_DEPTH = 256,
    parameter int unsigned DATA_W    = 64
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wr_en,
    input  logic [PSN_W-1:0] wr_psn,
    input  logic [DATA_W-1:0] wr_data,
    input  logic        rtx_req,
    input  logic [PSN_W-1:0] rtx_psn,
    output logic [DATA_W-1:0] rtx_data,
    output logic        rtx_valid,
    input  logic        ack_en,
    input  logic [PSN_W-1:0] ack_msn,
    output logic [7:0]  usage_cnt
);
    logic [DATA_W-1:0] buf_data  [0:BUF_DEPTH-1];
    logic [PSN_W-1:0]  buf_psn   [0:BUF_DEPTH-1];
    logic [BUF_DEPTH-1:0] buf_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf_valid <= '0;
            rtx_valid <= 1'b0;
        end else begin
            rtx_valid <= 1'b0;
            if (wr_en) begin
                buf_data[(BUF_DEPTH)'((buf_valid))] <= wr_data;
                buf_psn[(BUF_DEPTH)'((buf_valid))]  <= wr_psn;
                buf_valid[(buf_valid)] <= 1'b1;
            end
            if (rtx_req) begin
                for (int i = 0; i < BUF_DEPTH; i++) begin
                    if (buf_valid[i] && buf_psn[i] == rtx_psn) begin
                        rtx_data  <= buf_data[i];
                        rtx_valid <= 1'b1;
                    end
                end
            end
            if (ack_en) begin
                for (int i = 0; i < BUF_DEPTH; i++) begin
                    if (buf_valid[i] && buf_psn[i] <= ack_msn)
                        buf_valid[i] <= 1'b0;
                end
            end
        end
    end

    assign usage_cnt = 8'((buf_valid));
endmodule
