`timescale 1ns / 1ps
module psn_manager
    import rdma_pkg::*;
#(
    parameter int unsigned WIN_SIZE  = 64,
    parameter int unsigned MAX_RETRY = 7,
    parameter int unsigned RNR_MAX   = 7
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        tx_en_i,
    output logic [PSN_W-1:0] tx_psn_o,
    output logic        tx_ready_o,
    input  logic        ack_valid_i,
    input  logic [PSN_W-1:0] ack_msn_i,
    input  logic        nak_psn_err_i,
    input  logic        nak_rnr_i,
    input  logic        timeout_i,
    output logic        rtx_start_o,
    output logic [PSN_W-1:0] rtx_psn_o,
    output logic [PSN_W-1:0] base_psn_o,
    output logic [PSN_W-1:0] head_psn_o,
    output logic        window_full_o,
    output logic [2:0]  retry_cnt_o,
    output logic [2:0]  rnr_retry_o,
    output logic        qp_error_o
);
    logic [PSN_W-1:0] base_psn_r, head_psn_r;
    logic [2:0]       retry_cnt_r, rnr_retry_r;
    logic             rtx_active_r, qp_error_r;
    logic [PSN_W-1:0] window_used;

    assign window_used   = head_psn_r - base_psn_r;
    assign window_full_o = (window_used >= WIN_SIZE[PSN_W-1:0]);
    assign tx_ready_o    = !window_full_o && !rtx_active_r && !qp_error_r;
    assign tx_psn_o      = head_psn_r;
    assign base_psn_o    = base_psn_r;
    assign head_psn_o    = head_psn_r;
    assign retry_cnt_o   = retry_cnt_r;
    assign rnr_retry_o   = rnr_retry_r;
    assign qp_error_o    = qp_error_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            base_psn_r <= '0; head_psn_r <= '0;
            retry_cnt_r <= '0; rnr_retry_r <= '0;
            rtx_start_o <= 1'b0; rtx_psn_o <= '0;
            rtx_active_r <= 1'b0; qp_error_r <= 1'b0;
        end else begin
            rtx_start_o <= 1'b0;

            if (tx_en_i && tx_ready_o)
                head_psn_r <= head_psn_r + 1;

            if (ack_valid_i && !qp_error_r) begin
                if ((ack_msn_i + 1 > base_psn_r) && (ack_msn_i + 1 <= head_psn_r)) begin
                    base_psn_r  <= ack_msn_i + 1;
                    retry_cnt_r <= 3'd0;
                    rnr_retry_r <= 3'd0;
                end
            end

            if (nak_psn_err_i && !qp_error_r) begin
                if (retry_cnt_r >= MAX_RETRY[2:0])
                    qp_error_r <= 1'b1;
                else begin
                    rtx_start_o  <= 1'b1;
                    rtx_psn_o    <= base_psn_r;
                    head_psn_r   <= base_psn_r;
                    retry_cnt_r  <= retry_cnt_r + 1;
                    rtx_active_r <= 1'b1;
                end
            end

            if (timeout_i && !qp_error_r && !rtx_active_r) begin
                if (retry_cnt_r >= MAX_RETRY[2:0])
                    qp_error_r <= 1'b1;
                else begin
                    rtx_start_o  <= 1'b1;
                    rtx_psn_o    <= base_psn_r;
                    head_psn_r   <= base_psn_r;
                    retry_cnt_r  <= retry_cnt_r + 1;
                    rtx_active_r <= 1'b1;
                end
            end

            if (nak_rnr_i && !qp_error_r) begin
                if (rnr_retry_r >= RNR_MAX[2:0])
                    qp_error_r <= 1'b1;
                else begin
                    rnr_retry_r  <= rnr_retry_r + 1;
                    rtx_start_o  <= 1'b1;
                    rtx_psn_o    <= base_psn_r;
                    head_psn_r   <= base_psn_r;
                    rtx_active_r <= 1'b1;
                end
            end

            if (rtx_active_r && ack_valid_i)
                rtx_active_r <= 1'b0;
        end
    end
endmodule
