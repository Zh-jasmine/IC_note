class axi_scb_req;
    axi_op_e op;
    int s_port;
    int m_port;
    bit addr_hit;

    bit [AXI_S_ID_WIDTH-1:0] sid;
    bit [AXI_M_ID_WIDTH-1:0] mid;
    bit [AXI_ADDR_WIDTH-1:0] addr;
    bit [7:0] len;
    bit [2:0] size;
    bit [1:0] burst;

    bit [AXI_DATA_WIDTH-1:0] s_wdata[$];
    bit [AXI_STRB_WIDTH-1:0] s_wstrb[$];
    bit [AXI_DATA_WIDTH-1:0] m_wdata[$];
    bit [AXI_STRB_WIDTH-1:0] m_wstrb[$];

    int unsigned s_r_count;
    int unsigned m_r_count;
    bit s_w_done;
    bit m_w_done;
    bit write_done;

    function new();
        s_port = -1;
        m_port = -1;
        addr_hit = 1'b0;
        sid = '0;
        mid = '0;
        addr = '0;
        len = '0;
        size = '0;
        burst = '0;
        s_r_count = 0;
        m_r_count = 0;
        s_w_done = 1'b0;
        m_w_done = 1'b0;
        write_done = 1'b0;
    endfunction

    function int unsigned beat_count();
        return int'(len) + 1;
    endfunction

    function string label();
        string op_name;
        op_name = (op == AXI_WRITE) ? "WRITE" : "READ";
        return $sformatf("%s S%0d->M%0d sid=%0h mid=%0h addr=%0h len=%0d",
                         op_name, s_port, m_port, sid, mid, addr, len);
    endfunction
endclass

class axi_scoreboard extends uvm_component;
    `uvm_component_utils(axi_scoreboard)

    uvm_tlm_analysis_fifo #(axi_item) s_fifo[AXI_S_COUNT];
    uvm_tlm_analysis_fifo #(axi_item) m_fifo[AXI_M_COUNT];
    axi_ref_model rm;

    axi_scb_req s_write_q[AXI_S_COUNT][$];
    axi_scb_req m_write_exp_q[AXI_M_COUNT][$];
    axi_scb_req m_write_q[AXI_M_COUNT][$];
    axi_scb_req s_b_q[$];

    axi_scb_req m_read_exp_q[AXI_M_COUNT][$];
    axi_scb_req m_read_q[AXI_M_COUNT][$];
    axi_scb_req s_r_q[$];

    int unsigned s_item_count;
    int unsigned m_item_count;
    int unsigned route_checks;
    int unsigned write_checks;
    int unsigned read_checks;
    int unsigned resp_checks;
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
        if (rm == null) begin
            rm = axi_ref_model::type_id::create("rm");
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            if (!process_fifo_items()) #1ns;
        end
    endtask

    function bit process_fifo_items();
        axi_item item;
        process_fifo_items = 1'b0;

        foreach (s_fifo[i]) begin
            while (s_fifo[i].try_get(item)) begin
                process_fifo_items = 1'b1;
                s_item_count++;
                `uvm_info("AXI_SCB", $sformatf("S%0d %s", i, item.convert2string()), UVM_HIGH)
                handle_s_item(i, item);
            end
        end

        foreach (m_fifo[i]) begin
            while (m_fifo[i].try_get(item)) begin
                process_fifo_items = 1'b1;
                m_item_count++;
                `uvm_info("AXI_SCB", $sformatf("M%0d %s", i, item.convert2string()), UVM_HIGH)
                handle_m_item(i, item);
            end
        end
    endfunction

    function void scb_error(string msg);
        scb_errors++;
        `uvm_error("AXI_SCB", msg)
    endfunction

    function bit [AXI_S_ID_WIDTH-1:0] mid_sid(bit [AXI_M_ID_WIDTH-1:0] mid);
        return mid[AXI_S_ID_WIDTH-1:0];
    endfunction

    function int mid_s_port(bit [AXI_M_ID_WIDTH-1:0] mid);
        return int'(mid >> AXI_S_ID_WIDTH);
    endfunction

    function axi_scb_req new_req(axi_op_e op, int port, axi_item item);
        axi_scb_req req;
        req = new();
        req.op = op;
        req.s_port = port;
        req.sid = item.id[AXI_S_ID_WIDTH-1:0];
        req.addr = item.addr;
        req.len = item.len;
        req.size = item.size;
        req.burst = item.burst;
        req.m_port = rm.addr_to_m_port(item.addr);
        req.addr_hit = (req.m_port >= 0);
        req.mid = req.addr_hit ? rm.expand_id(port, req.sid) : '0;
        return req;
    endfunction

    function void handle_s_item(int idx, axi_item item);
        case (item.kind)
            AXI_MON_AW: handle_s_aw(idx, item);
            AXI_MON_W:  handle_s_w(idx, item);
            AXI_MON_B:  handle_s_b(idx, item);
            AXI_MON_AR: handle_s_ar(idx, item);
            AXI_MON_R:  handle_s_r(idx, item);
            default: scb_error($sformatf("Unknown S-side monitor kind=%0d on S%0d", item.kind, idx));
        endcase
    endfunction

    function void handle_m_item(int idx, axi_item item);
        case (item.kind)
            AXI_MON_AW: handle_m_aw(idx, item);
            AXI_MON_W:  handle_m_w(idx, item);
            AXI_MON_B:  handle_m_b(idx, item);
            AXI_MON_AR: handle_m_ar(idx, item);
            AXI_MON_R:  handle_m_r(idx, item);
            default: scb_error($sformatf("Unknown M-side monitor kind=%0d on M%0d", item.kind, idx));
        endcase
    endfunction

    function void handle_s_aw(int idx, axi_item item);
        axi_scb_req req;
        req = new_req(AXI_WRITE, idx, item);

        s_write_q[idx].push_back(req);
        s_b_q.push_back(req);
        if (req.addr_hit) m_write_exp_q[req.m_port].push_back(req);
    endfunction

    function void handle_s_w(int idx, axi_item item);
        int req_idx;
        axi_scb_req req;
        int unsigned beat;

        req_idx = first_open_s_write(idx);
        if (req_idx < 0) begin
            scb_error($sformatf("S%0d W beat without AW: data=%0h strb=%0h last=%0b",
                                idx, item.beat_data, item.beat_strb, item.last));
            return;
        end

        req = s_write_q[idx][req_idx];
        beat = req.s_wdata.size();
        req.s_wdata.push_back(item.beat_data);
        req.s_wstrb.push_back(item.beat_strb);
        check_last($sformatf("S%0d W", idx), req, beat, item.last);

        if (item.last) begin
            req.s_w_done = 1'b1;
            s_write_q[idx].delete(req_idx);
            if (!req.addr_hit) req.write_done = 1'b1;
            finish_write(req);
        end
    endfunction

    function void handle_s_b(int idx, axi_item item);
        int req_idx;
        axi_scb_req req;
        bit [1:0] exp_resp;

        req_idx = find_s_b(idx, item.id[AXI_S_ID_WIDTH-1:0]);
        if (req_idx < 0) begin
            scb_error($sformatf("Unexpected S%0d B id=%0h resp=%0h", idx, item.id, item.resp));
            return;
        end

        req = s_b_q[req_idx];
        exp_resp = req.addr_hit ? AXI_RESP_OKAY : AXI_RESP_DECERR;
        if (item.resp !== exp_resp) begin
            scb_error($sformatf("S%0d B resp mismatch for %s exp=%0h got=%0h",
                                idx, req.label(), exp_resp, item.resp));
        end
        if (req.addr_hit && !req.write_done) begin
            scb_error($sformatf("S%0d B arrived before write data check finished for %s", idx, req.label()));
        end

        s_b_q.delete(req_idx);
        resp_checks++;
    endfunction

    function void handle_s_ar(int idx, axi_item item);
        axi_scb_req req;
        req = new_req(AXI_READ, idx, item);

        s_r_q.push_back(req);
        if (req.addr_hit) m_read_exp_q[req.m_port].push_back(req);
    endfunction

    function void handle_s_r(int idx, axi_item item);
        int req_idx;
        axi_scb_req req;

        req_idx = find_s_r(idx, item.id[AXI_S_ID_WIDTH-1:0]);
        if (req_idx < 0) begin
            scb_error($sformatf("Unexpected S%0d R id=%0h data=%0h resp=%0h last=%0b",
                                idx, item.id, item.beat_data, item.resp, item.last));
            return;
        end

        req = s_r_q[req_idx];
        check_read_beat($sformatf("S%0d R", idx), req, item, 1'b1);
        if (req.s_r_count == req.beat_count()) s_r_q.delete(req_idx);
    endfunction

    function void handle_m_aw(int idx, axi_item item);
        axi_scb_req req;
        req = take_m_write_exp(idx, item);
        if (req == null) begin
            scb_error($sformatf("Unexpected M%0d AW id=%0h addr=%0h len=%0d", idx, item.id, item.addr, item.len));
            return;
        end

        m_write_q[idx].push_back(req);
        route_checks++;
    endfunction

    function void handle_m_w(int idx, axi_item item);
        int req_idx;
        axi_scb_req req;
        int unsigned beat;

        req_idx = first_open_m_write(idx);
        if (req_idx < 0) begin
            scb_error($sformatf("M%0d W beat without routed AW: data=%0h strb=%0h last=%0b",
                                idx, item.beat_data, item.beat_strb, item.last));
            return;
        end

        req = m_write_q[idx][req_idx];
        beat = req.m_wdata.size();
        req.m_wdata.push_back(item.beat_data);
        req.m_wstrb.push_back(item.beat_strb);
        check_last($sformatf("M%0d W", idx), req, beat, item.last);

        if (item.last) begin
            req.m_w_done = 1'b1;
            finish_write(req);
        end
    endfunction

    function void handle_m_b(int idx, axi_item item);
        axi_scb_req req;

        if (m_write_q[idx].size() == 0) begin
            scb_error($sformatf("Unexpected M%0d B id=%0h resp=%0h", idx, item.id, item.resp));
            return;
        end

        req = m_write_q[idx][0];
        if (!req.m_w_done) begin
            scb_error($sformatf("M%0d B arrived before WLAST for %s", idx, req.label()));
        end
        if (item.id !== req.mid) begin
            scb_error($sformatf("M%0d B id mismatch for %s exp=%0h got=%0h",
                                idx, req.label(), req.mid, item.id));
        end
        if ((mid_s_port(item.id) != req.s_port) || (mid_sid(item.id) !== req.sid)) begin
            scb_error($sformatf("M%0d B source decode mismatch for %s got_s=%0d got_id=%0h",
                                idx, req.label(), mid_s_port(item.id), mid_sid(item.id)));
        end
        if (item.resp !== AXI_RESP_OKAY) begin
            scb_error($sformatf("M%0d B resp mismatch for %s exp=%0h got=%0h",
                                idx, req.label(), AXI_RESP_OKAY, item.resp));
        end

        m_write_q[idx].delete(0);
        resp_checks++;
    endfunction

    function void handle_m_ar(int idx, axi_item item);
        axi_scb_req req;
        req = take_m_read_exp(idx, item);
        if (req == null) begin
            scb_error($sformatf("Unexpected M%0d AR id=%0h addr=%0h len=%0d", idx, item.id, item.addr, item.len));
            return;
        end

        m_read_q[idx].push_back(req);
        route_checks++;
    endfunction

    function void handle_m_r(int idx, axi_item item);
        int req_idx;
        axi_scb_req req;

        req_idx = find_m_read(idx, item.id);
        if (req_idx < 0) begin
            scb_error($sformatf("Unexpected M%0d R id=%0h data=%0h resp=%0h last=%0b",
                                idx, item.id, item.beat_data, item.resp, item.last));
            return;
        end

        req = m_read_q[idx][req_idx];
        check_read_beat($sformatf("M%0d R", idx), req, item, 1'b0);
        if (req.m_r_count == req.beat_count()) m_read_q[idx].delete(req_idx);
    endfunction

    function int first_open_s_write(int idx);
        foreach (s_write_q[idx][i]) begin
            if (!s_write_q[idx][i].s_w_done) return i;
        end
        return -1;
    endfunction

    function int first_open_m_write(int idx);
        foreach (m_write_q[idx][i]) begin
            if (!m_write_q[idx][i].m_w_done) return i;
        end
        return -1;
    endfunction

    function int find_s_b(int idx, bit [AXI_S_ID_WIDTH-1:0] sid);
        foreach (s_b_q[i]) begin
            if ((s_b_q[i].s_port == idx) && (s_b_q[i].sid === sid)) return i;
        end
        return -1;
    endfunction

    function int find_s_r(int idx, bit [AXI_S_ID_WIDTH-1:0] sid);
        foreach (s_r_q[i]) begin
            if ((s_r_q[i].s_port == idx) && (s_r_q[i].sid === sid) &&
                (s_r_q[i].s_r_count < s_r_q[i].beat_count())) begin
                return i;
            end
        end
        return -1;
    endfunction

    function int find_m_read(int idx, bit [AXI_M_ID_WIDTH-1:0] mid);
        foreach (m_read_q[idx][i]) begin
            if ((m_read_q[idx][i].mid === mid) &&
                (m_read_q[idx][i].m_r_count < m_read_q[idx][i].beat_count())) begin
                return i;
            end
        end
        return -1;
    endfunction

    function bit addr_matches(axi_scb_req req, axi_item item, int idx);
        return ((req.m_port == idx) &&
                (item.id === req.mid) &&
                (item.addr === req.addr) &&
                (item.len === req.len) &&
                (item.size === req.size) &&
                (item.burst === req.burst));
    endfunction

    function axi_scb_req take_m_write_exp(int idx, axi_item item);
        foreach (m_write_exp_q[idx][i]) begin
            if (addr_matches(m_write_exp_q[idx][i], item, idx)) begin
                axi_scb_req req;
                req = m_write_exp_q[idx][i];
                m_write_exp_q[idx].delete(i);
                return req;
            end
        end
        return null;
    endfunction

    function axi_scb_req take_m_read_exp(int idx, axi_item item);
        foreach (m_read_exp_q[idx][i]) begin
            if (addr_matches(m_read_exp_q[idx][i], item, idx)) begin
                axi_scb_req req;
                req = m_read_exp_q[idx][i];
                m_read_exp_q[idx].delete(i);
                return req;
            end
        end
        return null;
    endfunction

    function void check_last(string label, axi_scb_req req, int unsigned beat, bit last);
        int unsigned exp_beats;
        exp_beats = req.beat_count();

        if (beat >= exp_beats) begin
            scb_error($sformatf("%s has too many beats for %s beat=%0d exp_beats=%0d",
                                label, req.label(), beat, exp_beats));
            return;
        end
        if ((beat == exp_beats - 1) && !last) begin
            scb_error($sformatf("%s missing LAST on final beat for %s", label, req.label()));
        end
        if ((beat < exp_beats - 1) && last) begin
            scb_error($sformatf("%s early LAST on beat %0d for %s", label, beat, req.label()));
        end
    endfunction

    function void finish_write(axi_scb_req req);
        if (req.write_done) return;
        if (!req.addr_hit) begin
            if (req.s_w_done) req.write_done = 1'b1;
            return;
        end
        if (!(req.s_w_done && req.m_w_done)) return;

        compare_write(req);
        commit_write(req);
        req.write_done = 1'b1;
        write_checks++;
    endfunction

    function void compare_write(axi_scb_req req);
        int unsigned exp_beats;
        exp_beats = req.beat_count();

        if ((req.s_wdata.size() != exp_beats) || (req.m_wdata.size() != exp_beats)) begin
            scb_error($sformatf("Write beat count mismatch for %s exp=%0d s=%0d m=%0d",
                                req.label(), exp_beats, req.s_wdata.size(), req.m_wdata.size()));
            return;
        end

        for (int unsigned beat = 0; beat < exp_beats; beat++) begin
            if (req.m_wdata[beat] !== req.s_wdata[beat]) begin
                scb_error($sformatf("Write data mismatch for %s beat=%0d exp=%0h got=%0h",
                                    req.label(), beat, req.s_wdata[beat], req.m_wdata[beat]));
            end
            if (req.m_wstrb[beat] !== req.s_wstrb[beat]) begin
                scb_error($sformatf("Write strb mismatch for %s beat=%0d exp=%0h got=%0h",
                                    req.label(), beat, req.s_wstrb[beat], req.m_wstrb[beat]));
            end
        end
    endfunction

    function void commit_write(axi_scb_req req);
        for (int unsigned beat = 0; beat < req.beat_count(); beat++) begin
            rm.write_beat(req.addr, req.len, req.size, req.burst, beat, req.m_wdata[beat], req.m_wstrb[beat]);
        end
    endfunction

    function void check_read_beat(string label, axi_scb_req req, axi_item item, bit is_s_side);
        int unsigned beat;
        int unsigned exp_beats;
        bit exp_last;
        bit [1:0] exp_resp;
        bit [AXI_DATA_WIDTH-1:0] exp_data;

        beat = is_s_side ? req.s_r_count : req.m_r_count;
        exp_beats = req.beat_count();

        if (beat >= exp_beats) begin
            scb_error($sformatf("%s has too many beats for %s beat=%0d exp_beats=%0d",
                                label, req.label(), beat, exp_beats));
            return;
        end

        exp_last = (beat == exp_beats - 1);
        exp_resp = req.addr_hit ? AXI_RESP_OKAY : AXI_RESP_DECERR;
        exp_data = req.addr_hit ? rm.read_beat(req.addr, req.len, req.size, req.burst, beat) : '0;

        if (is_s_side) begin
            if (item.id[AXI_S_ID_WIDTH-1:0] !== req.sid) begin
                scb_error($sformatf("%s id mismatch for %s exp=%0h got=%0h",
                                    label, req.label(), req.sid, item.id));
            end
        end else begin
            if (item.id !== req.mid) begin
                scb_error($sformatf("%s id mismatch for %s exp=%0h got=%0h",
                                    label, req.label(), req.mid, item.id));
            end
        end

        if (item.resp !== exp_resp) begin
            scb_error($sformatf("%s resp mismatch for %s beat=%0d exp=%0h got=%0h",
                                label, req.label(), beat, exp_resp, item.resp));
        end
        if (item.beat_data !== exp_data) begin
            scb_error($sformatf("%s data mismatch for %s beat=%0d exp=%0h got=%0h",
                                label, req.label(), beat, exp_data, item.beat_data));
        end
        if (item.last !== exp_last) begin
            scb_error($sformatf("%s LAST mismatch for %s beat=%0d exp=%0b got=%0b",
                                label, req.label(), beat, exp_last, item.last));
        end

        if (is_s_side) begin
            req.s_r_count++;
        end else begin
            req.m_r_count++;
        end
        read_checks++;
    endfunction

    function void check_empty_queue(string label, int unsigned count);
        if (count != 0) scb_error($sformatf("%s still has %0d outstanding item(s)", label, count));
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        foreach (s_write_q[i]) check_empty_queue($sformatf("s_write_q[%0d]", i), s_write_q[i].size());
        foreach (m_write_exp_q[i]) check_empty_queue($sformatf("m_write_exp_q[%0d]", i), m_write_exp_q[i].size());
        foreach (m_write_q[i]) check_empty_queue($sformatf("m_write_q[%0d]", i), m_write_q[i].size());
        foreach (m_read_exp_q[i]) check_empty_queue($sformatf("m_read_exp_q[%0d]", i), m_read_exp_q[i].size());
        foreach (m_read_q[i]) check_empty_queue($sformatf("m_read_q[%0d]", i), m_read_q[i].size());
        check_empty_queue("s_b_q", s_b_q.size());
        check_empty_queue("s_r_q", s_r_q.size());

        `uvm_info("AXI_SCB",
                  $sformatf("Observed items: S-side=%0d M-side=%0d route_checks=%0d write_checks=%0d read_checks=%0d resp_checks=%0d scb_errors=%0d",
                            s_item_count, m_item_count, route_checks, write_checks, read_checks, resp_checks, scb_errors),
                  UVM_NONE)
    endfunction
endclass
