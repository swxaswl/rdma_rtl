`timescale 1ns / 1ps
module qp_fsm
    import rdma_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  qp_cmd_e     cmd_i,
    input  logic        cmd_valid_i,
    input  logic        retry_exceeded_i,
    input  logic        access_err_i,
    output qp_state_e   state_o,
    output logic        can_send_o,
    output logic        can_recv_o
);
    qp_state_e state_r, state_n;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state_r <= QP_RESET;
        else        state_r <= state_n;
    end

    always_comb begin
        state_n = state_r;
        case (state_r)
            QP_RESET: if (cmd_valid_i && cmd_i == CMD_INIT) state_n = QP_INIT;
            QP_INIT:  if (cmd_valid_i && cmd_i == CMD_RTR)  state_n = QP_RTR;
                      else if (cmd_valid_i && cmd_i == CMD_RESET) state_n = QP_RESET;
            QP_RTR:   if (cmd_valid_i && cmd_i == CMD_RTS)  state_n = QP_RTS;
                      else if (cmd_valid_i && cmd_i == CMD_RESET) state_n = QP_RESET;
            QP_RTS:   if (retry_exceeded_i || access_err_i) state_n = QP_ERROR;
                      else if (cmd_valid_i && cmd_i == CMD_RESET) state_n = QP_RESET;
            QP_ERROR: if (cmd_valid_i && cmd_i == CMD_RESET) state_n = QP_RESET;
            default:  state_n = QP_RESET;
        endcase
    end

    assign state_o    = state_r;
    assign can_send_o = (state_r == QP_RTS);
    assign can_recv_o = (state_r == QP_RTR) || (state_r == QP_RTS);
endmodule
