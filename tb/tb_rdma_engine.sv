`timescale 1ns / 1ps
module tb_rdma_engine;
    import rdma_pkg::*;

    localparam realtime CLK_PERIOD = 20.0;

    logic clk, rst_n;
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2.0) clk = ~clk;
    end

    integer pass_count = 0;
    integer fail_count = 0;

    task check(input [255:0] name, input [31:0] actual, input [31:0] expected);
        if (actual === expected) begin
            $display("[PASS] %0s = 0x%0h", name, actual);
            pass_count++;
        end else begin
            $display("[FAIL] %0s: got=0x%0h exp=0x%0h", name, actual, expected);
            fail_count++;
        end
    endtask

    // QP FSM
    qp_cmd_e     fsm_cmd;
    logic        fsm_cmd_valid;
    logic        fsm_retry_exceeded, fsm_access_err;
    qp_state_e   fsm_state;
    logic        fsm_can_send, fsm_can_recv;

    qp_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .cmd_i(fsm_cmd), .cmd_valid_i(fsm_cmd_valid),
        .retry_exceeded_i(fsm_retry_exceeded),
        .access_err_i(fsm_access_err),
        .state_o(fsm_state),
        .can_send_o(fsm_can_send),
        .can_recv_o(fsm_can_recv)
    );

    // BTH GEN
    logic        bth_hdr_en;
    opcode_e     bth_op;
    logic [23:0] bth_dqpn, bth_psn;
    logic [15:0] bth_pkey;
    logic        bth_ack_req, bth_reth_en, bth_aeth_en;
    logic [63:0] bth_raddr;
    logic [31:0] bth_rkey, bth_dlen;
    logic [7:0]  bth_syn;
    logic [23:0] bth_msn;
    bth_t        bth_out;
    reth_t       reth_out;
    aeth_t       aeth_out;
    logic        bth_valid, reth_valid, aeth_valid;

    bth_gen u_bth (
        .clk(clk), .rst_n(rst_n),
        .hdr_en(bth_hdr_en),
        .opcode_i(bth_op), .dest_qpn_i(bth_dqpn), .psn_i(bth_psn),
        .pkey_i(bth_pkey), .ack_req_i(bth_ack_req),
        .reth_en_i(bth_reth_en),
        .remote_addr_i(bth_raddr), .remote_rkey_i(bth_rkey),
        .dma_len_i(bth_dlen),
        .aeth_en_i(bth_aeth_en), .syndrome_i(bth_syn), .msn_i(bth_msn),
        .bth_o(bth_out), .reth_o(reth_out), .aeth_o(aeth_out),
        .bth_valid_o(bth_valid), .reth_valid_o(reth_valid),
        .aeth_valid_o(aeth_valid)
    );

    // PSN MANAGER
    logic        psn_tx_en;
    logic [23:0] psn_tx_psn;
    logic        psn_tx_ready;
    logic        psn_ack_valid;
    logic [23:0] psn_ack_msn;
    logic        psn_nak_psn_err, psn_nak_rnr, psn_timeout;
    logic        psn_rtx_start;
    logic [23:0] psn_rtx_psn, psn_base, psn_head;
    logic        psn_win_full;
    logic [2:0]  psn_retry_cnt, psn_rnr_cnt;
    logic        psn_qp_error;

    psn_manager u_psn (
        .clk(clk), .rst_n(rst_n),
        .tx_en_i(psn_tx_en), .tx_psn_o(psn_tx_psn),
        .tx_ready_o(psn_tx_ready),
        .ack_valid_i(psn_ack_valid), .ack_msn_i(psn_ack_msn),
        .nak_psn_err_i(psn_nak_psn_err), .nak_rnr_i(psn_nak_rnr),
        .timeout_i(psn_timeout),
        .rtx_start_o(psn_rtx_start), .rtx_psn_o(psn_rtx_psn),
        .base_psn_o(psn_base), .head_psn_o(psn_head),
        .window_full_o(psn_win_full),
        .retry_cnt_o(psn_retry_cnt), .rnr_retry_o(psn_rnr_cnt),
        .qp_error_o(psn_qp_error)
    );

    // RTX BUFFER
    logic        rtx_wr_en, rtx_rtx_req, rtx_ack_en;
    logic [23:0] rtx_wr_psn, rtx_rtx_psn, rtx_ack_msn;
    logic [63:0] rtx_wr_data, rtx_rtx_data;
    logic        rtx_rtx_valid;
    logic [7:0]  rtx_usage;

    rtx_buffer u_rtx (
        .clk(clk), .rst_n(rst_n),
        .wr_en(rtx_wr_en), .wr_psn(rtx_wr_psn), .wr_data(rtx_wr_data),
        .rtx_req(rtx_rtx_req), .rtx_psn(rtx_rtx_psn),
        .rtx_data(rtx_rtx_data), .rtx_valid(rtx_rtx_valid),
        .ack_en(rtx_ack_en), .ack_msn(rtx_ack_msn),
        .usage_cnt(rtx_usage)
    );


    // ===================== ACK TIMER WHEEL =====================
    logic        timer_start_en, timer_cancel_en, timer_timeout_pulse;
    logic [$clog2(1024)-1:0] timer_start_qpn, timer_cancel_qpn, timer_timeout_qpn;
    logic [31:0] timer_timeout_val;

    ack_timer_wheel #(.QP_NUM(1024), .SLOT_NUM(256), .TIMER_W(32)) u_timer (
        .clk(clk), .rst_n(rst_n),
        .start_en(timer_start_en), .start_qpn(timer_start_qpn),
        .timeout_val(timer_timeout_val),
        .cancel_en(timer_cancel_en), .cancel_qpn(timer_cancel_qpn),
        .timeout_pulse(timer_timeout_pulse), .timeout_qpn(timer_timeout_qpn)
    );

    // ===================== ERROR DETECTOR =====================
    logic        err_retry_exceeded, err_rkey, err_addr, err_rnr, err_link, err_icrc;
    err_type_e   err_type;
    logic        err_valid, err_qp_reset, err_rtx;

    error_detector u_err (
        .clk(clk), .rst_n(rst_n),
        .retry_exceeded_i(err_retry_exceeded),
        .rkey_err_i(err_rkey), .addr_err_i(err_addr),
        .rnr_nak_i(err_rnr), .link_down_i(err_link),
        .icrc_err_i(err_icrc),
        .err_type_o(err_type), .err_valid_o(err_valid),
        .qp_reset_req_o(err_qp_reset), .rtx_req_o(err_rtx)
    );

    // ===================== ICRC32 =====================
    logic        icrc_data_valid, icrc_calc_start, icrc_calc_done, icrc_valid;
    logic [7:0]  icrc_data_in;
    logic [31:0] icrc_out;

    icrc32 u_icrc (
        .clk(clk), .rst_n(rst_n),
        .data_valid(icrc_data_valid), .data_in(icrc_data_in),
        .calc_start(icrc_calc_start), .calc_done(icrc_calc_done),
        .icrc_out(icrc_out), .icrc_valid(icrc_valid)
    );

    // ===================== DCQCN RATE LIMITER =====================
    logic        dcqcn_cnp, dcqcn_tx_req, dcqcn_tx_grant;
    logic [31:0] dcqcn_min_rate, dcqcn_max_rate, dcqcn_current_rate;
    logic [7:0]  dcqcn_cnp_interval;

    dcqcn_rate_limiter u_dcqcn (
        .clk(clk), .rst_n(rst_n),
        .cnp_received_i(dcqcn_cnp), .tx_request_i(dcqcn_tx_req),
        .tx_grant_o(dcqcn_tx_grant),
        .min_rate_i(dcqcn_min_rate), .max_rate_i(dcqcn_max_rate),
        .cnp_interval_i(dcqcn_cnp_interval),
        .current_rate_o(dcqcn_current_rate)
    );

    // Reset PSN manager
    task reset_psn;
        begin
            psn_tx_en = 0; psn_ack_valid = 0; psn_nak_psn_err = 0;
            psn_nak_rnr = 0; psn_timeout = 0;
            rtx_wr_en = 0; rtx_rtx_req = 0; rtx_ack_en = 0;
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            rst_n = 1'b1;
            repeat (3) @(posedge clk);
        end
    endtask

    initial begin
        rst_n = 1'b0;
        fsm_cmd = CMD_INIT; fsm_cmd_valid = 0;
        fsm_retry_exceeded = 0; fsm_access_err = 0;
        bth_hdr_en = 0; bth_op = OP_SEND_FIRST;
        bth_dqpn = 0; bth_psn = 0; bth_pkey = 16'hFFFF;
        bth_ack_req = 0; bth_reth_en = 0; bth_aeth_en = 0;
        bth_raddr = 0; bth_rkey = 0; bth_dlen = 0;
        bth_syn = 0; bth_msn = 0;
        psn_tx_en = 0; psn_ack_valid = 0; psn_ack_msn = 0;
        psn_nak_psn_err = 0; psn_nak_rnr = 0; psn_timeout = 0;
        rtx_wr_en = 0; rtx_rtx_req = 0; rtx_ack_en = 0;
        rtx_wr_psn = 0; rtx_wr_data = 0; rtx_rtx_psn = 0; rtx_ack_msn = 0;
        timer_start_en = 0; timer_cancel_en = 0;
        timer_start_qpn = 0; timer_cancel_qpn = 0; timer_timeout_val = 0;
        err_retry_exceeded = 0; err_rkey = 0; err_addr = 0;
        err_rnr = 0; err_link = 0; err_icrc = 0;
        icrc_data_valid = 0; icrc_calc_start = 0; icrc_calc_done = 0;
        icrc_data_in = 0;
        dcqcn_cnp = 0; dcqcn_tx_req = 0;
        dcqcn_min_rate = 32'd100; dcqcn_max_rate = 32'hFFFFFFFF;
        dcqcn_cnp_interval = 8'd10;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // Test 1: QP FSM
        $display("\n=== Test 1: QP FSM ===");
        @(negedge clk); fsm_cmd = CMD_INIT; fsm_cmd_valid = 1;
        @(posedge clk);
        @(negedge clk); fsm_cmd_valid = 0;
        check("QP_INIT", fsm_state, QP_INIT);

        @(negedge clk); fsm_cmd = CMD_RTR; fsm_cmd_valid = 1;
        @(posedge clk);
        @(negedge clk); fsm_cmd_valid = 0;
        check("QP_RTR", fsm_state, QP_RTR);
        check("can_recv", fsm_can_recv, 1);

        @(negedge clk); fsm_cmd = CMD_RTS; fsm_cmd_valid = 1;
        @(posedge clk);
        @(negedge clk); fsm_cmd_valid = 0;
        check("QP_RTS", fsm_state, QP_RTS);
        check("can_send", fsm_can_send, 1);

        @(negedge clk); fsm_retry_exceeded = 1;
        @(posedge clk);
        @(negedge clk); fsm_retry_exceeded = 0;
        check("QP_ERROR", fsm_state, QP_ERROR);
        check("can_send_err", fsm_can_send, 0);

        @(negedge clk); fsm_cmd = CMD_RESET; fsm_cmd_valid = 1;
        @(posedge clk);
        @(negedge clk); fsm_cmd_valid = 0;
        check("QP_RESET", fsm_state, QP_RESET);

        fsm_cmd = CMD_INIT; fsm_cmd_valid = 1;
        @(posedge clk); fsm_cmd_valid = 0;
        fsm_cmd = CMD_RTR; fsm_cmd_valid = 1;
        @(posedge clk); fsm_cmd_valid = 0;
        fsm_cmd = CMD_RTS; fsm_cmd_valid = 1;
        @(posedge clk); #1; fsm_cmd_valid = 0;
        check("QP_RTS_again", fsm_state, QP_RTS);

        // Test 2: BTH
        $display("\n=== Test 2: BTH ===");
        @(negedge clk);
        bth_hdr_en = 1;
        bth_op = OP_RDMA_WRITE_FIRST;
        bth_dqpn = 24'h000010;
        bth_psn = 24'h000064;
        bth_pkey = 16'hFFFF;
        bth_ack_req = 1;
        bth_reth_en = 1;
        bth_raddr = 64'h0000_007F_0000_1000;
        bth_rkey = 32'hABCD_1234;
        bth_dlen = 32'd64;
        @(posedge clk);
        @(negedge clk); bth_hdr_en = 0; bth_reth_en = 0;
        check("bth_valid", bth_valid, 1);
        check("reth_valid", reth_valid, 1);
        check("bth_opcode", bth_out.opcode, OP_RDMA_WRITE_FIRST);
        check("bth_dqpn", bth_out.dest_qpn, 24'h000010);
        check("bth_psn", bth_out.psn, 24'h000064);
        check("bth_ack_req", bth_out.ack_req, 1);
        check("reth_rkey", reth_out.remote_rkey, 32'hABCD_1234);
        check("reth_dlen", reth_out.dma_len, 32'd64);

        // Test 3: PSN window
        $display("\n=== Test 3: PSN window ===");
        for (int i = 0; i < 4; i++) begin
            @(negedge clk); psn_tx_en = 1;
            @(posedge clk);
            @(negedge clk); psn_tx_en = 0;
            @(posedge clk);
        end
        check("head_psn", psn_head, 24'd4);
        check("base_psn", psn_base, 24'd0);
        check("win_full", psn_win_full, 0);

        // Test 4: ACK
        $display("\n=== Test 4: ACK ===");
        @(negedge clk); psn_ack_valid = 1; psn_ack_msn = 24'd3;
        @(posedge clk);
        @(negedge clk); psn_ack_valid = 0;
        @(posedge clk);
        check("base_after_ack", psn_base, 24'd4);
        check("retry_after_ack", psn_retry_cnt, 3'd0);

        // Test 5: NAK Go-Back-N
        $display("\n=== Test 5: NAK GBN ===");
        @(negedge clk); psn_tx_en = 1;
        @(posedge clk);
        @(negedge clk); psn_tx_en = 0;
        @(posedge clk);
        @(negedge clk); psn_tx_en = 1;
        @(posedge clk);
        @(negedge clk); psn_tx_en = 0;
        @(posedge clk);
        check("head_before_nak", psn_head, 24'd6);

        @(negedge clk); psn_nak_psn_err = 1;
        @(posedge clk);
        @(negedge clk); psn_nak_psn_err = 0;
        check("rtx_start", psn_rtx_start, 1);
        check("rtx_psn", psn_rtx_psn, 24'd4);
        check("head_after_nak", psn_head, 24'd4);
        check("retry_cnt", psn_retry_cnt, 3'd1);

        // Test 6: Timeout
        $display("\n=== Test 6: Timeout ===");
        // ACK to clear rtx_active from Test 5 NAK
        @(negedge clk); psn_ack_valid = 1; psn_ack_msn = 24'd5;
        @(posedge clk);
        @(negedge clk); psn_ack_valid = 0;
        @(posedge clk);
        psn_ack_valid = 1; psn_ack_msn = 24'd5;
        @(posedge clk); psn_ack_valid = 0;
        @(posedge clk); @(posedge clk);

        @(negedge clk); psn_tx_en = 1;
        @(posedge clk);
        @(negedge clk); psn_tx_en = 0;
        @(posedge clk);
        @(negedge clk); psn_tx_en = 1;
        @(posedge clk);
        @(negedge clk); psn_tx_en = 0;
        @(posedge clk);
        check("head_before_timeout", psn_head, 24'd6);

        @(negedge clk); psn_timeout = 1;
        @(posedge clk);
        @(negedge clk); psn_timeout = 0;
        check("rtx_start_to", psn_rtx_start, 1);
        check("rtx_psn_to", psn_rtx_psn, 24'd4);

        // Test 7: retry exceeded
        $display("\n=== Test 7: retry exceeded ===");
        @(negedge clk); psn_tx_en = 1;
        @(posedge clk);
        @(negedge clk); psn_tx_en = 0;
        @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            @(negedge clk); psn_nak_psn_err = 1;
            @(posedge clk);
            @(negedge clk); psn_nak_psn_err = 0;
            @(posedge clk);
        end
        check("qp_error", psn_qp_error, 1);

        // Test 8: RTX Buffer
        $display("\n=== Test 8: RTX Buffer ===");
        @(negedge clk); rtx_wr_en = 1; rtx_wr_psn = 24'd100; rtx_wr_data = 64'hDEAD_BEEF_1234_5678;
        @(posedge clk);
        @(negedge clk); rtx_wr_en = 0;
        @(posedge clk);
        @(negedge clk); rtx_wr_en = 1; rtx_wr_psn = 24'd101; rtx_wr_data = 64'hAAAA_BBBB_CCCC_DDDD;
        @(posedge clk);
        @(negedge clk); rtx_wr_en = 0;
        @(posedge clk);
        check("rtx_usage", rtx_usage, 8'd3);

        @(negedge clk); rtx_rtx_req = 1; rtx_rtx_psn = 24'd100;
        @(posedge clk);
        @(negedge clk); rtx_rtx_req = 0;
        check("rtx_valid", rtx_rtx_valid, 1);
        check("rtx_data", rtx_rtx_data[31:0], 32'h1234_5678);

        @(negedge clk); rtx_ack_en = 1; rtx_ack_msn = 24'd100;
        @(posedge clk);
        @(negedge clk); rtx_ack_en = 0;
        @(posedge clk);
        check("usage_after_ack", rtx_usage, 8'd2);

        // Test 9: AETH
        $display("\n=== Test 9: AETH ===");
        @(negedge clk);
        bth_hdr_en = 1;
        bth_op = OP_ACK;
        bth_aeth_en = 1;
        bth_syn = SYN_ACK;
        bth_msn = 24'd200;
        bth_psn = 24'd0;
        @(posedge clk);
        @(negedge clk); bth_hdr_en = 0; bth_aeth_en = 0;
        check("aeth_valid", aeth_valid, 1);
        check("aeth_syn", aeth_out.syndrome, 8'h00);
        check("aeth_msn", aeth_out.msn, 24'd200);

        // ===== Test 10: ACK Timer Wheel =====
        $display("\n=== Test 10: ACK Timer Wheel ===");
        // Start timer for QPN=5 with timeout_val=3
        @(negedge clk); timer_start_en = 1; timer_start_qpn = 5; timer_timeout_val = 32'd3;
        @(posedge clk);
        @(negedge clk); timer_start_en = 0;
        // Wait for timeout (tick_cnt wraps every 32 cycles, then slot advances)
        for (int i = 0; i < 200; i++) begin
            @(posedge clk);
            if (timer_timeout_pulse) break;
        end
        check("timer_timeout", timer_timeout_pulse, 1);
        check("timer_qpn", timer_timeout_qpn, 5);

        // Test cancel
        @(negedge clk); timer_start_en = 1; timer_start_qpn = 7; timer_timeout_val = 32'd3;
        @(posedge clk);
        @(negedge clk); timer_start_en = 0; timer_cancel_en = 1; timer_cancel_qpn = 7;
        @(posedge clk);
        @(negedge clk); timer_cancel_en = 0;
        for (int i = 0; i < 200; i++) begin
            @(posedge clk);
            if (timer_timeout_pulse) break;
        end
        check("timer_cancelled", timer_timeout_pulse, 0);

        // ===== Test 11: Error Detector =====
        $display("\n=== Test 11: Error Detector ===");
        @(negedge clk); err_rkey = 1;
        @(posedge clk);
        @(negedge clk); err_rkey = 0;
        check("err_type_rkey", err_type, ERR_RKEY);
        check("err_valid_rkey", err_valid, 1);
        check("err_rtx_rkey", err_rtx, 1);

        @(negedge clk); err_retry_exceeded = 1;
        @(posedge clk);
        @(negedge clk); err_retry_exceeded = 0;
        check("err_type_retry", err_type, ERR_RETRY);
        check("err_qp_reset", err_qp_reset, 1);

        @(negedge clk); err_rnr = 1;
        @(posedge clk);
        @(negedge clk); err_rnr = 0;
        check("err_type_rnr", err_type, ERR_RNR);

        @(negedge clk); err_link = 1;
        @(posedge clk);
        @(negedge clk); err_link = 0;
        check("err_type_link", err_type, ERR_LINK);
        check("err_qp_reset_link", err_qp_reset, 1);

        // ===== Test 12: ICRC32 =====
        $display("\n=== Test 12: ICRC32 ===");
        // Calculate CRC of "123456789" -> expected 0xE3069283 (CRC-32C)
        @(negedge clk); icrc_calc_start = 1;
        @(posedge clk);
        @(negedge clk); icrc_calc_start = 0;
        // Feed bytes '1' through '9'
        for (int i = 0; i < 9; i++) begin
            @(negedge clk); icrc_data_valid = 1; icrc_data_in = 8'h31 + i;
            @(posedge clk);
        end
        @(negedge clk); icrc_data_valid = 0; icrc_calc_done = 1;
        @(posedge clk);
        @(negedge clk); icrc_calc_done = 0;
        check("icrc_valid", icrc_valid, 1);
        check("icrc_value", icrc_out, 32'hE3069283);

        // ===== Test 13: DCQCN Rate Limiter =====
        $display("\n=== Test 13: DCQCN Rate Limiter ===");
        // Initial rate should be max
        check("dcqcn_rate_nonzero", (dcqcn_current_rate > 0) ? 32'd1 : 32'd0, 32'd1);

        // CNP received -> rate decreases
        @(negedge clk); dcqcn_cnp = 1;
        @(posedge clk);
        @(negedge clk); dcqcn_cnp = 0;
        @(posedge clk); #1;
        check("dcqcn_rate_decreased", (dcqcn_current_rate < 32'hFFFFFFFF) ? 32'd1 : 32'd0, 32'd1);

        // tx_grant should work when token_cnt > 1000
        @(negedge clk); dcqcn_tx_req = 1;
        repeat (10) @(posedge clk);
        @(negedge clk); dcqcn_tx_req = 0;
        check("dcqcn_tx_grant", dcqcn_tx_grant ? 32'd1 : 32'd0, 32'd1);

        repeat (5) @(posedge clk);
        $display("\n========================================");
        $display("Test Summary: PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $display("========================================");
        $finish;
    end

    initial begin
        #100_000;
        $display("[ERROR] Timeout!");
        $finish;
    end
endmodule
