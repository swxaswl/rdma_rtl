`timescale 1ns / 1ps
package rdma_pkg;
    localparam int unsigned PSN_W   = 24;
    localparam int unsigned QPN_W  = 24;
    localparam int unsigned ADDR_W = 64;
    localparam int unsigned RKEY_W = 32;
    localparam int unsigned BTH_W  = 80;
    localparam int unsigned RETH_W = 128;
    localparam int unsigned AETH_W = 32;

    typedef enum logic [7:0] {
        OP_SEND_FIRST          = 8'h00,
        OP_SEND_LAST           = 8'h02,
        OP_SEND_LAST_IMM       = 8'h03,
        OP_RDMA_WRITE_FIRST    = 8'h04,
        OP_RDMA_WRITE_LAST     = 8'h06,
        OP_RDMA_WRITE_LAST_IMM = 8'h07,
        OP_RDMA_READ_REQ       = 8'h0A,
        OP_RDMA_READ_RESP_FIRST= 8'h0B,
        OP_RDMA_READ_RESP_LAST = 8'h0D,
        OP_ATOMIC_CS           = 8'h11,
        OP_ATOMIC_FA           = 8'h12,
        OP_ACK                 = 8'h14,
        OP_RNR_NAK             = 8'h15,
        OP_NAK                 = 8'h16
    } opcode_e;

    localparam logic [7:0] SYN_ACK         = 8'h00;
    localparam logic [7:0] SYN_NAK_PSN_ERR = 8'h60;
    localparam logic [7:0] SYN_NAK_INV_REQ = 8'h61;
    localparam logic [7:0] SYN_NAK_ACCESS  = 8'h62;
    localparam logic [7:0] SYN_NAK_INV_RKEY= 8'h64;
    localparam logic [7:0] SYN_NAK_RNR     = 8'h65;

    typedef enum logic [2:0] {
        QP_RESET = 3'd0, QP_INIT = 3'd1, QP_RTR = 3'd2,
        QP_RTS = 3'd3, QP_SQE = 3'd4, QP_ERROR = 3'd5
    } qp_state_e;

    typedef enum logic [1:0] {
        CMD_INIT = 2'd0, CMD_RTR = 2'd1, CMD_RTS = 2'd2, CMD_RESET = 2'd3
    } qp_cmd_e;

    typedef struct packed {
        logic [7:0]  opcode;
        logic        se;
        logic        m;
        logic [1:0]  pad_cnt;
        logic [3:0]  tver;
        logic [15:0] pkey;
        logic        f;
        logic        b;
        logic [23:0] dest_qpn;
        logic        ack_req;
        logic [23:0] psn;
    } bth_t;

    typedef struct packed {
        logic [63:0] remote_addr;
        logic [31:0] remote_rkey;
        logic [31:0] dma_len;
    } reth_t;

    typedef struct packed {
        logic [7:0]  syndrome;
        logic [23:0] msn;
    } aeth_t;

    typedef enum logic [2:0] {
        ERR_NONE = 3'd0, ERR_RETRY = 3'd1, ERR_RKEY = 3'd2,
        ERR_ADDR = 3'd3, ERR_RNR = 3'd4, ERR_LINK = 3'd5, ERR_ICRC = 3'd6
    } err_type_e;
endpackage
