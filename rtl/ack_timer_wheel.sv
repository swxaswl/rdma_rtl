`timescale 1ns / 1ps
module ack_timer_wheel
    import rdma_pkg::*;
#(
    parameter int unsigned QP_NUM   = 1024,
    parameter int unsigned SLOT_NUM = 256,
    parameter int unsigned TIMER_W  = 32
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_en,
    input  logic [$clog2(QP_NUM)-1:0] start_qpn,
    input  logic [TIMER_W-1:0] timeout_val,
    input  logic        cancel_en,
    input  logic [$clog2(QP_NUM)-1:0] cancel_qpn,
    output logic        timeout_pulse,
    output logic [$clog2(QP_NUM)-1:0] timeout_qpn
);
    localparam int unsigned SLOT_W = $clog2(SLOT_NUM);

    logic [$clog2(QP_NUM)-1:0] wheel_qpn [0:SLOT_NUM-1];
    logic [SLOT_NUM-1:0]       wheel_valid;
    logic [SLOT_W-1:0]         current_slot;
    logic [3:0]                tick_cnt;  // prescaler: wraps every 16 cycles

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_slot  <= '0;
            tick_cnt      <= '0;
            wheel_valid   <= '0;
            timeout_pulse <= 1'b0;
            timeout_qpn   <= '0;
        end else begin
            timeout_pulse <= 1'b0;

            if (start_en) begin
                automatic logic [SLOT_W-1:0] slot;
                slot = current_slot + SLOT_W'(timeout_val);
                wheel_qpn[slot]   <= start_qpn;
                wheel_valid[slot] <= 1'b1;
            end

            if (cancel_en) begin
                for (int i = 0; i < SLOT_NUM; i++) begin
                    if (wheel_valid[i] && wheel_qpn[i] == cancel_qpn)
                        wheel_valid[i] <= 1'b0;
                end
            end

            tick_cnt <= tick_cnt + 1;
            if (tick_cnt == 4'hF) begin  // wrap every 16 cycles
                current_slot <= current_slot + 1;
                if (wheel_valid[current_slot]) begin
                    timeout_pulse <= 1'b1;
                    timeout_qpn   <= wheel_qpn[current_slot];
                    wheel_valid[current_slot] <= 1'b0;
                end
            end
        end
    end
endmodule
