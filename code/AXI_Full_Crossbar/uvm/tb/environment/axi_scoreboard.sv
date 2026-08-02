class axi_scoreboard extends uvm_component;
    `uvm_component_utils(axi_scoreboard)

    uvm_tlm_analysis_fifo #(axi_item) s_fifo[AXI_S_COUNT];
    uvm_tlm_analysis_fifo #(axi_item) m_fifo[AXI_M_COUNT];
    axi_ref_model rm;

    int unsigned s_item_count;
    int unsigned m_item_count;
    int unsigned compare_count;
    int unsigned scb_errors;

    function new(string name = "axi_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void set_ref_model(axi_ref_model model);
        rm = model;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        foreach (s_fifo[i]) s_fifo[i] = new($sformatf("s_fifo%0d", i), this);
        foreach (m_fifo[i]) m_fifo[i] = new($sformatf("m_fifo%0d", i), this);
        if (rm == null) rm = axi_ref_model::type_id::create("rm");
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            if (!process_fifo_items()) #1ns;
        end
    endtask

    function bit process_fifo_items();
        axi_item item;
        axi_item s_items[AXI_S_COUNT][$];
        axi_item m_items[AXI_M_COUNT][$];
        process_fifo_items = 1'b0;

        foreach (s_fifo[i]) begin
            while (s_fifo[i].try_get(item)) begin
                process_fifo_items = 1'b1;
                s_item_count++;
                s_items[i].push_back(item);
            end
        end

        foreach (m_fifo[i]) begin
            while (m_fifo[i].try_get(item)) begin
                process_fifo_items = 1'b1;
                m_item_count++;
                m_items[i].push_back(item);
            end
        end

        foreach (s_items[i, j]) begin
            if (is_s_to_m_item(s_items[i][j])) rm.observe_s_item(i, s_items[i][j]);
        end

        foreach (m_items[i, j]) begin
            if (is_m_to_s_item(m_items[i][j])) rm.observe_m_item(i, m_items[i][j]);
        end

        foreach (m_items[i, j]) begin
            if (is_s_to_m_item(m_items[i][j])) compare_m_item(i, m_items[i][j]);
        end

        foreach (s_items[i, j]) begin
            if (is_m_to_s_item(s_items[i][j])) compare_s_item(i, s_items[i][j]);
        end
    endfunction

    function void scb_error(string msg);
        scb_errors++;
        `uvm_error("AXI_SCB", msg)
    endfunction

    function bit is_s_to_m_item(axi_item item);
        return (item.kind inside {AXI_MON_AW, AXI_MON_W, AXI_MON_AR});
    endfunction

    function bit is_m_to_s_item(axi_item item);
        return (item.kind inside {AXI_MON_B, AXI_MON_R});
    endfunction

    function void compare_s_item(int idx, axi_item item);
        axi_item exp;

        case (item.kind)
            AXI_MON_B,
            AXI_MON_R: begin
                if (!rm.get_s_expected(idx, item.kind, exp)) begin
                    scb_error($sformatf("Unexpected S%0d %s actual=%s",
                                        idx, kind_name(item.kind), item.convert2string()));
                    return;
                end
                compare_item($sformatf("S%0d", idx), exp, item);
            end

            default: scb_error($sformatf("Unknown S-side item kind=%0d on S%0d", item.kind, idx));
        endcase
    endfunction

    function void compare_m_item(int idx, axi_item item);
        axi_item exp;

        case (item.kind)
            AXI_MON_AW,
            AXI_MON_W,
            AXI_MON_AR: begin
                if (!rm.get_m_expected(idx, item.kind, exp)) begin
                    scb_error($sformatf("Unexpected M%0d %s actual=%s",
                                        idx, kind_name(item.kind), item.convert2string()));
                    return;
                end
                compare_item($sformatf("M%0d", idx), exp, item);
            end

            default: scb_error($sformatf("Unknown M-side item kind=%0d on M%0d", item.kind, idx));
        endcase
    endfunction

    function string kind_name(axi_mon_kind_e kind);
        case (kind)
            AXI_MON_AW: return "AW";
            AXI_MON_W:  return "W";
            AXI_MON_B:  return "B";
            AXI_MON_AR: return "AR";
            AXI_MON_R:  return "R";
            default:    return "UNKNOWN";
        endcase
    endfunction

    function void compare_item(string path, axi_item exp, axi_item act);
        if (act.kind !== exp.kind) begin
            scb_error($sformatf("%s kind mismatch exp=%s got=%s",
                                path, kind_name(exp.kind), kind_name(act.kind)));
            return;
        end

        case (act.kind)
            AXI_MON_AW,
            AXI_MON_AR: compare_addr(path, exp, act);
            AXI_MON_W:  compare_w(path, exp, act);
            AXI_MON_B:  compare_b(path, exp, act);
            AXI_MON_R:  compare_r(path, exp, act);
            default: scb_error($sformatf("%s unknown compare kind=%0d", path, act.kind));
        endcase

        compare_count++;
    endfunction

    function void compare_addr(string path, axi_item exp, axi_item act);
        if (act.id !== exp.id) begin
            scb_error($sformatf("%s %s id mismatch exp=%0h got=%0h",
                                path, kind_name(act.kind), exp.id, act.id));
        end
        if (act.addr !== exp.addr) begin
            scb_error($sformatf("%s %s addr mismatch exp=%0h got=%0h",
                                path, kind_name(act.kind), exp.addr, act.addr));
        end
        if (act.len !== exp.len) begin
            scb_error($sformatf("%s %s len mismatch exp=%0d got=%0d",
                                path, kind_name(act.kind), exp.len, act.len));
        end
        if (act.size !== exp.size) begin
            scb_error($sformatf("%s %s size mismatch exp=%0d got=%0d",
                                path, kind_name(act.kind), exp.size, act.size));
        end
        if (act.burst !== exp.burst) begin
            scb_error($sformatf("%s %s burst mismatch exp=%0d got=%0d",
                                path, kind_name(act.kind), exp.burst, act.burst));
        end
    endfunction

    function void compare_w(string path, axi_item exp, axi_item act);
        if (act.beat_data !== exp.beat_data) begin
            scb_error($sformatf("%s W data mismatch exp=%0h got=%0h",
                                path, exp.beat_data, act.beat_data));
        end
        if (act.beat_strb !== exp.beat_strb) begin
            scb_error($sformatf("%s W strb mismatch exp=%0h got=%0h",
                                path, exp.beat_strb, act.beat_strb));
        end
        if (act.last !== exp.last) begin
            scb_error($sformatf("%s W last mismatch exp=%0b got=%0b",
                                path, exp.last, act.last));
        end
    endfunction

    function void compare_b(string path, axi_item exp, axi_item act);
        if (act.id[AXI_S_ID_WIDTH-1:0] !== exp.id[AXI_S_ID_WIDTH-1:0]) begin
            scb_error($sformatf("%s B id mismatch exp=%0h got=%0h",
                                path, exp.id[AXI_S_ID_WIDTH-1:0], act.id[AXI_S_ID_WIDTH-1:0]));
        end
        if (act.resp !== exp.resp) begin
            scb_error($sformatf("%s B resp mismatch exp=%0h got=%0h",
                                path, exp.resp, act.resp));
        end
    endfunction

    function void compare_r(string path, axi_item exp, axi_item act);
        if (act.id[AXI_S_ID_WIDTH-1:0] !== exp.id[AXI_S_ID_WIDTH-1:0]) begin
            scb_error($sformatf("%s R id mismatch exp=%0h got=%0h",
                                path, exp.id[AXI_S_ID_WIDTH-1:0], act.id[AXI_S_ID_WIDTH-1:0]));
        end
        if (act.beat_data !== exp.beat_data) begin
            scb_error($sformatf("%s R data mismatch exp=%0h got=%0h",
                                path, exp.beat_data, act.beat_data));
        end
        if (act.resp !== exp.resp) begin
            scb_error($sformatf("%s R resp mismatch exp=%0h got=%0h",
                                path, exp.resp, act.resp));
        end
        if (act.last !== exp.last) begin
            scb_error($sformatf("%s R last mismatch exp=%0b got=%0b",
                                path, exp.last, act.last));
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (rm.pending_count() != 0) begin
            scb_error($sformatf("Reference model still has %0d expected item(s)", rm.pending_count()));
        end

        `uvm_info("AXI_SCB",
                  $sformatf("items: S=%0d M=%0d compares=%0d errors=%0d",
                            s_item_count, m_item_count, compare_count, scb_errors),
                  UVM_NONE)
    endfunction
endclass
