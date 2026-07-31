UVM_HOME ?= $(VCS_HOME)/etc/uvm

MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR ?= $(abspath $(MAKEFILE_DIR)/../..)
BLD_DIR ?= /tmp/AXI-LITE2SPI

COMP = vcs \
	-full64 \
	-sverilog \
	-ntb_opts uvm-1.2 \
	+incdir+. \
	+incdir+axi \
	+incdir+spi \
	+incdir+sva \
	+incdir+env \
	+incdir+scoreboard \
	+incdir+test \
	+incdir+test/base \
	+incdir+test/spi \
	+incdir+test/miso \
	+incdir+test/axi \
	+incdir+test/reset \
	+incdir+test/ral \
	+incdir+coverage \
	+incdir+ral \
	+incdir+../DUT \
	-timescale=1ns/1ps \
	-debug_acc+all \
	-debug_region+cell+encrypt \
	-kdb -lca \
	-cm line+cond+fsm+branch+tgl+assert \
	-cm_dir $(BLD_DIR)/cov.vdb \
	tb_top.sv \
	-o simv

TEST ?= spi_word_len_test
TESTS = spi_word_len_test spi_mode_test spi_cs_sck_test spi_sck_cs_test spi_ifg_test spi_sck_speed_test axi_busy_test axi_handshake_test axi_wstrb_test axi_concurrent_test spi_burst_test spi_alternating_test spi_data_all_0_test spi_data_all_1_test reset_mid_test spi_miso_read_test spi_miso_all_0_test spi_miso_all_1_test spi_random_test reset_sva_test ral_test
TIMEOUT ?= 100000000

SIM = ./simv \
	+UVM_TESTNAME=$(TEST) \
	+UVM_VERBOSITY=UVM_LOW \
	+UVM_TIMEOUT=$(TIMEOUT) \
	-cm line+cond+fsm+branch+tgl+assert \
	-cm_dir $(BLD_DIR)/cov.vdb \
	-cm_name $(TEST) \
	-l sim.log

all: comp sim

comp:
	rm -rf $(BLD_DIR)
	mkdir -p $(BLD_DIR)/UVMTB
	cp -a $(SRC_DIR)/DUT $(BLD_DIR)/
	cp -a $(SRC_DIR)/UVMTB/* $(BLD_DIR)/UVMTB/
	cd $(BLD_DIR)/UVMTB && $(COMP)
	cp $(BLD_DIR)/UVMTB/simv .

sim:
	cd $(BLD_DIR)/UVMTB && $(SIM)
	-cp $(BLD_DIR)/UVMTB/tb_top.fsdb . 2>/dev/null
	-cp $(BLD_DIR)/UVMTB/sim.log     . 2>/dev/null

clean:
	rm -f  simv tb_top.fsdb sim.log sim_*.log vc_hdrs.h
	rm -f  regression_summary.txt coverage_summary.txt
	rm -rf $(BLD_DIR) simv.daidir csrc
	rm -rf novasLog verdiLog
	rm -rf cov_report
	rm -f  novas.conf novas.rc

# 覆盖率报告：跑完 all_test（或多个 sim）后，合并 cov.vdb 生成 urg 报告
cov:
	urg -dir $(BLD_DIR)/cov.vdb -report cov_report
	@echo "coverage report -> cov_report/dashboard.html"
	@$(MAKE) summary

summary:
	@if command -v python3 >/dev/null 2>&1; then \
		python3 gen_summary.py .; \
	else \
		echo "python3 not found; skip regression_summary.txt / coverage_summary.txt"; \
	fi

all_test: comp
	@PASS=0; FAIL=0; TOTAL=0; \
	PASS_LIST=""; FAIL_LIST=""; \
	for t in $(TESTS); do \
		TOTAL=$$((TOTAL + 1)); \
		echo ">>> [$$TOTAL] 运行 $$t ..."; \
		(cd $(BLD_DIR)/UVMTB && ./simv +UVM_TESTNAME=$$t +UVM_VERBOSITY=UVM_LOW +UVM_TIMEOUT=$(TIMEOUT) -cm line+cond+fsm+branch+tgl+assert -cm_dir $(BLD_DIR)/cov.vdb -cm_name $$t -l sim_$$t.log); \
		LOG=$(BLD_DIR)/UVMTB/sim_$$t.log; \
		if grep -qE 'UVM_ERROR[[:space:]]*:[[:space:]]+0\b' $$LOG 2>/dev/null \
		   && grep -qE 'UVM_FATAL[[:space:]]*:[[:space:]]+0\b' $$LOG 2>/dev/null \
		   && ! grep -q 'failed at' $$LOG 2>/dev/null; then \
			echo "    [PASS] $$t"; \
			PASS=$$((PASS + 1)); \
			PASS_LIST="$$PASS_LIST  $$t"; \
		else \
			echo "    [FAIL] $$t"; \
			FAIL=$$((FAIL + 1)); \
			FAIL_LIST="$$FAIL_LIST  $$t"; \
		fi; \
		cp $(BLD_DIR)/UVMTB/sim_$$t.log . ; \
	done; \
	echo ""; \
	echo "========================================"; \
	printf "  通过 ($$PASS/$$TOTAL):\n"; \
	for t in $$PASS_LIST; do printf "    %s\n" "$$t"; done; \
	printf "\n  失败 ($$FAIL/$$TOTAL):\n"; \
	for t in $$FAIL_LIST; do printf "    %s\n" "$$t"; done; \
	echo "========================================"; \
	echo ">>> 生成覆盖率报告 ..."; \
	urg -dir $(BLD_DIR)/cov.vdb -report cov_report; \
	echo "coverage report -> cov_report/dashboard.html"; \
	$(MAKE) summary

# 单 test 快捷方式：只依赖 sim，复用已编译的 simv（不重编 VCS）
# 首次使用前需先 make all（或 make comp）至少编译一次
test_word_len:
	$(MAKE) sim TEST=spi_word_len_test
	$(MAKE) cov

test_mode:
	$(MAKE) sim TEST=spi_mode_test
	$(MAKE) cov

test_cs_sck:
	$(MAKE) sim TEST=spi_cs_sck_test
	$(MAKE) cov

test_sck_cs:
	$(MAKE) sim TEST=spi_sck_cs_test
	$(MAKE) cov

test_ifg:
	$(MAKE) sim TEST=spi_ifg_test
	$(MAKE) cov

test_sck_speed:
	$(MAKE) sim TEST=spi_sck_speed_test
	$(MAKE) cov

test_busy:
	$(MAKE) sim TEST=axi_busy_test
	$(MAKE) cov

test_handshake:
	$(MAKE) sim TEST=axi_handshake_test
	$(MAKE) cov

test_wstrb:
	$(MAKE) sim TEST=axi_wstrb_test
	$(MAKE) cov

test_concurrent:
	$(MAKE) sim TEST=axi_concurrent_test
	$(MAKE) cov

test_burst:
	$(MAKE) sim TEST=spi_burst_test
	$(MAKE) cov

test_alternating:
	$(MAKE) sim TEST=spi_alternating_test
	$(MAKE) cov

test_data_all_0:
	$(MAKE) sim TEST=spi_data_all_0_test
	$(MAKE) cov

test_data_all_1:
	$(MAKE) sim TEST=spi_data_all_1_test
	$(MAKE) cov

test_reset_mid:
	$(MAKE) sim TEST=reset_mid_test
	$(MAKE) cov

test_miso_read:
	$(MAKE) sim TEST=spi_miso_read_test
	$(MAKE) cov

test_miso_all_0:
	$(MAKE) sim TEST=spi_miso_all_0_test
	$(MAKE) cov

test_miso_all_1:
	$(MAKE) sim TEST=spi_miso_all_1_test
	$(MAKE) cov

test_random:
	$(MAKE) sim TEST=spi_random_test
	$(MAKE) cov

test_reset_sva:
	$(MAKE) sim TEST=reset_sva_test
	$(MAKE) cov

test_ral:
	$(MAKE) sim TEST=ral_test
	$(MAKE) cov

.PHONY: all comp sim clean cov summary help all_test \
        test_word_len test_mode test_cs_sck test_sck_cs test_ifg test_sck_speed \
        test_busy test_handshake test_wstrb test_concurrent test_burst test_alternating test_data_all_0 test_data_all_1 test_reset_mid \
        test_miso_read test_miso_all_0 test_miso_all_1 test_random test_reset_sva test_ral
