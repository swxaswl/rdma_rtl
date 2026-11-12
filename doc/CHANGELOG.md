# CHANGELOG

## [0.2.0] - 2026-11-11

### Added
- `rtl/ack_timer_wheel.sv`：ACK 超时轮，4 位预分频（16 周期/slot），256 slot。
- `rtl/error_detector.sv`：错误检测与分类，支持 retry/rkey/addr/rnr/link/icrc。
- `rtl/icrc32.sv`：CRC-32C（Castagnoli）逐字节计算。
- `rtl/dcqcn_rate_limiter.sv`：DCQCN 速率控制/token 授权原型。
- `tb/tb_rdma_engine.sv`：新增 Test 10-13，共 16 项检查。
- `doc/功能手册.md`：新增功能手册。
- `doc/修改手册.md`：新增修改手册。

### Changed
- `sim/filelist_rtl.f`：加入 4 个新模块。
- testbench 检查数：38 -> 54。

### Verification
- 工具：VCS V-2023.12-SP1
- 命令：`cd sim && make clean && make run`
- 结果：`PASS=54  FAIL=0`
- 仿真时间：约 7.45 us
- 日志：`sim/tb_rdma_engine_simulation.log`

### Known Issues
- P0 `rtx_buffer`：写索引使用 `buf_valid` 位图值，不是写指针；`usage_cnt` 是位图低 8 位，不是条目计数；ACK 释放未处理 PSN 回绕。
- P0 `dcqcn_rate_limiter`：`alpha` 初值为 0，CNP 降速不生效；`max_rate_i` 未使用；token 不消费；增率可能 32 位溢出。
- P1 `ack_timer_wheel`：每 slot 单条目，无冲突处理；同 QP 重启可能重复超时。
- P1 `psn_manager`：任意 `ack_valid` 都会清除 `rtx_active`，包括窗口外无效 ACK。
- P1 全局：无顶层集成、无 RX 路径、无 DMA/MPT/队列管理。
- P2 全局：无 SVA、覆盖率、随机测试、综合约束。

### Notes
- Test 8 的 `rtx_usage=3` 固化了位图语义（两次写入后 `0b11`），不是两条记录。
- Test 13 的 `dcqcn_rate_decreased` 通过是增率溢出造成的假通过，不能证明 CNP 降速有效。

## [0.1.0] - 2026-11-11

### Added
- `rtl/rdma_pkg.sv`：位宽、opcode、QP 状态、BTH/RETH/AETH、错误类型。
- `rtl/bth_gen.sv`：BTH/RETH/AETH 生成。
- `rtl/qp_fsm.sv`：QP 状态机。
- `rtl/psn_manager.sv`：PSN 窗口、累计 ACK、NAK/超时/RNR 重传。
- `rtl/rtx_buffer.sv`：重传缓存。
- `tb/tb_rdma_engine.sv`：初始 38 项检查。
- `sim/Makefile`、`sim/filelist_rtl.f`、`sim/filelist_tb.f`、`sim/synopsys_sim.setup`、`sim/dump_fsdb_vcs.tcl`。

### Fixed
- `psn_manager`：ACK 更新时限制 `base_psn` 不得超过 `head_psn`，增加 `ack_msn+1 <= head_psn` 条件。

### Verification
- 初始 38 项检查全部通过。
