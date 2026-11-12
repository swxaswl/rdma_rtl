`timescale 1ns / 1ps
module dcqcn_rate_limiter (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cnp_received_i,
    input  logic        tx_request_i,
    output logic        tx_grant_o,
    input  logic [31:0] min_rate_i,
    input  logic [31:0] max_rate_i,
    input  logic [7:0]  cnp_interval_i,
    output logic [31:0] current_rate_o
);

    logic [31:0] rate_r;
    logic [7:0]  alpha_r;
    logic [31:0] token_cnt_r;
    logic [7:0]  cnp_timer_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rate_r      <= 32'hFFFFFFFF;
            alpha_r     <= 8'd0;
            token_cnt_r <= '0;
            cnp_timer_r <= '0;
        end else begin
            // Token bucket refill
            if (token_cnt_r + rate_r >= token_cnt_r)  // overflow check
                token_cnt_r <= token_cnt_r + rate_r;
            else
                token_cnt_r <= 32'hFFFFFFFF;

            // CNP received: decrease rate
            if (cnp_received_i) begin
                automatic logic [31:0] reduction;
                alpha_r <= alpha_r + (alpha_r >> 2);
                reduction = (rate_r * {24'b0, alpha_r}) >> 8;
                if (reduction >= rate_r)
                    rate_r <= min_rate_i;
                else
                    rate_r <= (rate_r - reduction < min_rate_i) ? min_rate_i : rate_r - reduction;
                cnp_timer_r <= '0;
            end else begin
                // Timeout: increase rate
                cnp_timer_r <= cnp_timer_r + 1;
                if (cnp_timer_r == cnp_interval_i) begin
                    rate_r  <= rate_r + (rate_r >> 4);
                    alpha_r <= (alpha_r == 0) ? 8'd0 : alpha_r - 1;
                end
            end
        end
    end

    assign tx_grant_o     = tx_request_i && (token_cnt_r > 32'd1000);
    assign current_rate_o = rate_r;
endmodule
