// ============================================================
// ral_test — RAL frontdoor / backdoor 流程冒烟测试
//
//   1. backdoor 复位检查：复位后 8 个 WO 配置寄存器物理值 = 0（peek）
//   2. WO 寄存器：frontdoor write → backdoor peek 比对（写得进 + 值正确）
//                 （这些寄存器 frontdoor 读回 0，无法用 mirror check，必须 backdoor）
//   3. RO 寄存器：frontdoor read → status.busy 空闲时 = 0（读通道通）
//   4. backdoor poke → frontdoor read 反向验证：用 miso_data(RO) 演示
//                 （poke 物理写入 slv_reg9，但硬件每拍刷新，需在 reset 保持下读）
//
//   注意：本 test 不触发 SPI 传输，不依赖 scoreboard。
// ============================================================
`ifndef RAL_TEST_SV
`define RAL_TEST_SV

class ral_test extends test_base;
    `uvm_component_utils(ral_test)

    axi_spi_reg_block   reg_model;
    axi_spi_reg_adapter adapter;

    int unsigned err_cnt = 0;

    function new(string name = "ral_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        reg_model = axi_spi_reg_block::type_id::create("reg_model");
        reg_model.build();                 // 内部已 lock_model
        adapter = axi_spi_reg_adapter::type_id::create("adapter");
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // 把 reg map 接到现有 AXI sequencer + adapter
        reg_model.map.set_sequencer(env.axi_agt.axi_sqr, adapter);
        reg_model.map.set_auto_predict(1); // frontdoor 后自动更新 mirror（无独立 predictor）
    endfunction

    // ---- backdoor 复位值检查（应为 0）----
    task automatic check_reset0(uvm_reg r);
        uvm_status_e   st;
        uvm_reg_data_t pv;
        r.peek(st, pv);
        if (st != UVM_IS_OK) begin
            `uvm_error("RAL", $sformatf("[reset] %s peek 状态异常", r.get_name())); err_cnt++;
        end
        else if (pv !== 0) begin
            `uvm_error("RAL", $sformatf("[reset] %s 复位值应为 0，实际 0x%0h", r.get_name(), pv)); err_cnt++;
        end
        else
            `uvm_info("RAL", $sformatf("[reset] %s = 0  OK", r.get_name()), UVM_LOW)
    endtask

    // ---- WO: frontdoor write → backdoor peek 比对 ----
    task automatic wo_write_peek(uvm_reg r, uvm_reg_data_t wval);
        uvm_status_e   st_w, st_p;
        uvm_reg_data_t pv;
        r.write(st_w, wval);          // frontdoor（默认）
        #20;                          // 等写响应落地到寄存器
        r.peek(st_p, pv);             // backdoor 物理读
        if (st_w != UVM_IS_OK || st_p != UVM_IS_OK) begin
            `uvm_error("RAL", $sformatf("[WO] %s 总线状态异常 w=%s p=%s",
                       r.get_name(), st_w.name(), st_p.name())); err_cnt++;
        end
        else if (pv !== wval) begin
            `uvm_error("RAL", $sformatf("[WO] %s frontdoor写0x%0h ≠ backdoor读0x%0h",
                       r.get_name(), wval, pv)); err_cnt++;
        end
        else
            `uvm_info("RAL", $sformatf("[WO] %s write/peek=0x%0h  OK", r.get_name(), pv), UVM_LOW)
    endtask

    task run_phase(uvm_phase phase);
        uvm_status_e   st;
        uvm_reg_data_t rv;

        phase.raise_objection(this);
        #200;   // 等复位释放（复位在 100ns 拉高）

        `uvm_info("RAL", "==== 1. backdoor 复位值检查（WO 配置寄存器应=0）====", UVM_LOW)
        check_reset0(reg_model.spi_mode);
        check_reset0(reg_model.sck_speed);
        check_reset0(reg_model.word_len);
        check_reset0(reg_model.ifg);
        check_reset0(reg_model.cs_sck);
        check_reset0(reg_model.sck_cs);
        check_reset0(reg_model.mosi_data);

        `uvm_info("RAL", "==== 2. WO frontdoor write → backdoor peek ====", UVM_LOW)
        wo_write_peek(reg_model.spi_mode,  32'h2);
        wo_write_peek(reg_model.sck_speed, 32'h1);
        wo_write_peek(reg_model.word_len,  32'h3);
        wo_write_peek(reg_model.ifg,       32'hA5);
        wo_write_peek(reg_model.cs_sck,    32'h0C);
        wo_write_peek(reg_model.sck_cs,    32'h0C);
        wo_write_peek(reg_model.mosi_data, 32'hDEADBEEF);

        `uvm_info("RAL", "==== 3. RO frontdoor read：status.busy 空闲应=0 ====", UVM_LOW)
        reg_model.status.read(st, rv);   // frontdoor
        if (st != UVM_IS_OK) begin
            `uvm_error("RAL", "[RO] status 读状态异常"); err_cnt++;
        end
        else if (rv[0] !== 1'b0) begin
            `uvm_error("RAL", $sformatf("[RO] 空闲时 busy 应=0，实际 0x%0h", rv)); err_cnt++;
        end
        else
            `uvm_info("RAL", $sformatf("[RO] status.busy=0 (frontdoor read=0x%0h)  OK", rv), UVM_LOW)

        `uvm_info("RAL", "==== 4. backdoor poke → frontdoor read（miso_data RO 演示）====", UVM_LOW)
        // miso_data 由硬件每拍刷新（slv_reg9<=miso_data），传输空闲时 miso_data=0，
        // poke 后下一拍即被覆盖回 0，故 frontdoor 读回 0 属预期。
        // 此步仅演示 poke 调用链通畅（uvm_hdl_deposit），不做值断言。
        reg_model.miso_data.poke(st, 32'h5A5A5A5A);
        if (st != UVM_IS_OK) begin
            `uvm_error("RAL", "[poke] miso_data poke 状态异常"); err_cnt++;
        end
        else begin
            reg_model.miso_data.read(st, rv);
            `uvm_info("RAL", $sformatf("[poke] miso_data poke 0x5A5A5A5A → frontdoor read=0x%0h（硬件刷新预期回0）", rv), UVM_LOW)
        end

        // 清空 scoreboard 队列：RAL write mosi_data 会被 SCB 拦截入队，
        // 本 test 不触发 SPI 传输，手动清掉避免 SCB_FAIL
        env.scb.expected_data_q.delete();

        if (err_cnt == 0)
            `uvm_info("RAL", "==== RAL 测试全部通过 ====", UVM_LOW)
        else
            `uvm_error("RAL", $sformatf("==== RAL 测试 %0d 处失败 ====", err_cnt))

        phase.drop_objection(this);
    endtask

endclass : ral_test

`endif
