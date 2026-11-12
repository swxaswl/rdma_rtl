TOP_MODULE := tb_rdma_engine

all: run

run: run_analysis run_elaboration run_simulation

run_analysis:
	@echo "=== Analyze RTL ==="
	/opt/synopsys2023/vcs/vcs/V-2023.12-SP1/bin/vlogan -full64 -sverilog -timescale=1ps/1ps +incdir+../rtl -f filelist_rtl.f -work lib_rtl -l $(TOP_MODULE)_analysis_rtl.log
	@echo "=== Analyze TB ==="
	/opt/synopsys2023/vcs/vcs/V-2023.12-SP1/bin/vlogan -full64 -sverilog -timescale=1ps/1ps +incdir+../rtl +incdir+../tb -f filelist_tb.f -work lib_tb -l $(TOP_MODULE)_analysis_tb.log

run_elaboration:
	@echo "=== Elaboration ==="
	/opt/synopsys2023/vcs/vcs/V-2023.12-SP1/bin/vcs -full64 -debug_access+r -sverilog -timescale=1ps/1ps -top $(TOP_MODULE) -LDFLAGS "-Wl,--no-as-needed -Wl,--unresolved-symbols=ignore-all" -l $(TOP_MODULE)_elaboration.log

run_simulation:
	@echo "=== Simulation ==="
	./simv -ucli -i ./dump_fsdb_vcs.tcl +fsdb+delta -l $(TOP_MODULE)_simulation.log

clean:
	rm -rf csrc simv* verdiLog *.fsdb *.log novas.* *.key lib_rtl lib_tb
