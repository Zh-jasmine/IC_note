class axi_rm_write_ctx;
    int m_port;
    bit addr_hit;
    bit [AXI_S_ID_WIDTH-1:0] sid;

    function new(int m_port, bit addr_hit, bit [AXI_S_ID_WIDTH-1:0] sid);
        this.m_port = m_port;
        this.addr_hit = addr_hit;
        this.sid = sid;
    endfunction
endclass

class axi_ref_model extends uvm_object;
    `uvm_object_utils(axi_ref_model)

    axi_item m_aw_exp_q[AXI_M_COUNT][$];
    axi_item m_w_exp_q[AXI_M_COUNT][$];
    axi_item m_ar_exp_q[AXI_M_COUNT][$];
    axi_item s_b_exp_q[AXI_S_COUNT][$];
    axi_item s_r_exp_q[AXI_S_COUNT][$];
    axi_rm_write_ctx s_write_ctx_q[AXI_S_COUNT][$];

    function new(string name = "axi_ref_model");
        super.new(name);
    endfunction

    function int addr_to_m_port(bit [AXI_ADDR_WIDTH-1:0] addr);
        if (addr inside {[32'h0000_0000:32'h0000_0fff]}) return 0;
        if (addr inside {[32'h0001_0000:32'h0001_0fff]}) return 1;
        if (addr inside {[32'h0002_0000:32'h0002_0fff]}) return 2;
        return -1;
    endfunction

    function bit [AXI_M_ID_WIDTH-1:0] expand_id(int s_port, bit [AXI_S_ID_WIDTH-1:0] sid);
        bit [AXI_M_ID_WIDTH-1:0] mid;
        bit [AXI_M_ID_WIDTH-AXI_S_ID_WIDTH-1:0] source_bits;
        source_bits = s_port;
        mid = {source_bits, sid};
        return mid;
    endfunction

    function int mid_s_port(bit [AXI_M_ID_WIDTH-1:0] mid);
        return int'(mid >> AXI_S_ID_WIDTH);
    endfunction

    function bit [AXI_S_ID_WIDTH-1:0] mid_sid(bit [AXI_M_ID_WIDTH-1:0] mid);
        return mid[AXI_S_ID_WIDTH-1:0];
    endfunction

    function axi_item make_addr_item(axi_mon_kind_e kind, int m_port, int s_port, axi_item item);
        axi_item exp;
        exp = axi_item::type_id::create("exp");
        exp.kind = kind;
        exp.is_m_side = 1'b1;
        exp.port_index = m_port;
        exp.id = expand_id(s_port, item.id[AXI_S_ID_WIDTH-1:0]);
        exp.addr = item.addr;
        exp.len = item.len;
        exp.size = item.size;
        exp.burst = item.burst;
        return exp;
    endfunction

    function axi_item make_w_item(int m_port, axi_item item);
        axi_item exp;
        exp = axi_item::type_id::create("exp");
        exp.kind = AXI_MON_W;
        exp.is_m_side = 1'b1;
        exp.port_index = m_port;
        exp.beat_data = item.beat_data;
        exp.beat_strb = item.beat_strb;
        exp.last = item.last;
        return exp;
    endfunction

    function axi_item make_b_item(int s_port, bit [AXI_S_ID_WIDTH-1:0] sid, bit [1:0] resp);
        axi_item exp;
        exp = axi_item::type_id::create("exp");
        exp.kind = AXI_MON_B;
        exp.is_m_side = 1'b0;
        exp.port_index = s_port;
        exp.id = sid;
        exp.resp = resp;
        return exp;
    endfunction

    function axi_item make_r_item(
        int s_port,
        bit [AXI_S_ID_WIDTH-1:0] sid,
        bit [AXI_DATA_WIDTH-1:0] data,
        bit [1:0] resp,
        bit last
    );
        axi_item exp;
        exp = axi_item::type_id::create("exp");
        exp.kind = AXI_MON_R;
        exp.is_m_side = 1'b0;
        exp.port_index = s_port;
        exp.id = sid;
        exp.beat_data = data;
        exp.resp = resp;
        exp.last = last;
        return exp;
    endfunction

    function void observe_s_item(int s_port, axi_item item);
        case (item.kind)
            AXI_MON_AW: observe_s_aw(s_port, item);
            AXI_MON_W:  observe_s_w(s_port, item);
            AXI_MON_AR: observe_s_ar(s_port, item);
            default: ;
        endcase
    endfunction

    function void observe_m_item(int m_port, axi_item item);
        case (item.kind)
            AXI_MON_B: observe_m_b(m_port, item);
            AXI_MON_R: observe_m_r(m_port, item);
            default: ;
        endcase
    endfunction

    function void observe_s_aw(int s_port, axi_item item);
        int m_port;
        bit addr_hit;
        axi_rm_write_ctx ctx;
        m_port = addr_to_m_port(item.addr);
        addr_hit = (m_port >= 0);
        ctx = new(m_port, addr_hit, item.id[AXI_S_ID_WIDTH-1:0]);
        s_write_ctx_q[s_port].push_back(ctx);
        if (addr_hit) begin
            m_aw_exp_q[m_port].push_back(make_addr_item(AXI_MON_AW, m_port, s_port, item));
        end
    endfunction

    function void observe_s_w(int s_port, axi_item item);
        axi_rm_write_ctx ctx;

        if (s_write_ctx_q[s_port].size() == 0) begin
            `uvm_error("AXI_RM", $sformatf("S%0d W observed before matching AW", s_port))
            return;
        end

        ctx = s_write_ctx_q[s_port][0];
        if (ctx.addr_hit) begin
            m_w_exp_q[ctx.m_port].push_back(make_w_item(ctx.m_port, item));
        end else if (item.last) begin
            s_b_exp_q[s_port].push_back(make_b_item(s_port, ctx.sid, AXI_RESP_DECERR));
        end

        if (item.last) s_write_ctx_q[s_port].delete(0);
    endfunction

    function void observe_s_ar(int s_port, axi_item item);
        int m_port;
        bit [AXI_S_ID_WIDTH-1:0] sid;
        m_port = addr_to_m_port(item.addr);
        sid = item.id[AXI_S_ID_WIDTH-1:0];

        if (m_port >= 0) begin
            m_ar_exp_q[m_port].push_back(make_addr_item(AXI_MON_AR, m_port, s_port, item));
        end else begin
            for (int unsigned beat = 0; beat < int'(item.len) + 1; beat++) begin
                s_r_exp_q[s_port].push_back(make_r_item(s_port, sid, '0, AXI_RESP_DECERR, beat == int'(item.len)));
            end
        end
    endfunction

    function void observe_m_b(int m_port, axi_item item);
        int s_port;
        s_port = mid_s_port(item.id);
        if ((s_port < 0) || (s_port >= AXI_S_COUNT)) begin
            `uvm_error("AXI_RM", $sformatf("M%0d B has invalid expanded id=%0h", m_port, item.id))
            return;
        end
        s_b_exp_q[s_port].push_back(make_b_item(s_port, mid_sid(item.id), item.resp));
    endfunction

    function void observe_m_r(int m_port, axi_item item);
        int s_port;
        s_port = mid_s_port(item.id);
        if ((s_port < 0) || (s_port >= AXI_S_COUNT)) begin
            `uvm_error("AXI_RM", $sformatf("M%0d R has invalid expanded id=%0h", m_port, item.id))
            return;
        end
        s_r_exp_q[s_port].push_back(make_r_item(s_port, mid_sid(item.id), item.beat_data, item.resp, item.last));
    endfunction

    function bit get_m_expected(int m_port, axi_mon_kind_e kind, output axi_item exp);
        case (kind)
            AXI_MON_AW: if (m_aw_exp_q[m_port].size() != 0) begin exp = m_aw_exp_q[m_port].pop_front(); return 1'b1; end
            AXI_MON_W:  if (m_w_exp_q[m_port].size()  != 0) begin exp = m_w_exp_q[m_port].pop_front();  return 1'b1; end
            AXI_MON_AR: if (m_ar_exp_q[m_port].size() != 0) begin exp = m_ar_exp_q[m_port].pop_front(); return 1'b1; end
            default: ;
        endcase
        exp = null;
        return 1'b0;
    endfunction

    function bit get_s_expected(int s_port, axi_mon_kind_e kind, output axi_item exp);
        case (kind)
            AXI_MON_B: if (s_b_exp_q[s_port].size() != 0) begin exp = s_b_exp_q[s_port].pop_front(); return 1'b1; end
            AXI_MON_R: if (s_r_exp_q[s_port].size() != 0) begin exp = s_r_exp_q[s_port].pop_front(); return 1'b1; end
            default: ;
        endcase
        exp = null;
        return 1'b0;
    endfunction

    function int unsigned pending_count();
        pending_count = 0;
        foreach (m_aw_exp_q[i]) pending_count += m_aw_exp_q[i].size();
        foreach (m_w_exp_q[i]) pending_count += m_w_exp_q[i].size();
        foreach (m_ar_exp_q[i]) pending_count += m_ar_exp_q[i].size();
        foreach (s_b_exp_q[i]) pending_count += s_b_exp_q[i].size();
        foreach (s_r_exp_q[i]) pending_count += s_r_exp_q[i].size();
        foreach (s_write_ctx_q[i]) pending_count += s_write_ctx_q[i].size();
    endfunction
endclass
