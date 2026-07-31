// SPI MISO readback tests.
// The base class sweeps mode x word_len; subclasses only select MISO pattern.

`ifndef SPI_MISO_TESTS_SV
`define SPI_MISO_TESTS_SV

class spi_miso_base_test extends test_base;

    bit [7:0] exp_miso_byte = 8'h00;

    function new(string name = "spi_miso_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function automatic bit [31:0] expand_payload(bit [7:0] pattern,
                                                 bit [1:0] word_len);
        case (word_len)
            2'd0:    expand_payload = {pattern, pattern, pattern, pattern};
            2'd1:    expand_payload = {16'h0, pattern, pattern};
            2'd2:    expand_payload = {24'h0, pattern};
            2'd3:    expand_payload = {28'h0, pattern[3:0]};
            default: expand_payload = {24'h0, pattern};
        endcase
    endfunction

    function automatic bit [31:0] mask_for_word_len(bit [1:0] word_len);
        case (word_len)
            2'd0:    mask_for_word_len = 32'hFFFF_FFFF;
            2'd1:    mask_for_word_len = 32'h0000_FFFF;
            2'd2:    mask_for_word_len = 32'h0000_00FF;
            2'd3:    mask_for_word_len = 32'h0000_000F;
            default: mask_for_word_len = 32'h0000_00FF;
        endcase
    endfunction

    task automatic run_one_case(bit [1:0] spi_mode, bit [1:0] word_len);
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        automatic axi_spi_cfg_seq cfg;
        automatic axi_read_seq rd;
        automatic bit [31:0] exp_payload;
        automatic bit [31:0] mask;

        exp_payload = expand_payload(exp_miso_byte, word_len);
        mask = mask_for_word_len(word_len);
        spi_vif.miso_tx_data = exp_payload;

        cfg = axi_spi_cfg_seq::type_id::create("cfg");
        cfg.spi_mode_i  = spi_mode;
        cfg.word_len_i  = word_len;
        cfg.mosi_data_i = 32'hA5;
        cfg.start(env.axi_agt.axi_sqr);
        wait_spi_done();

        rd = axi_read_seq::type_id::create("rd_miso");
        rd.raddr = 32'h24;
        rd.start(env.axi_agt.axi_sqr);

        if ((rd.rdata_o & mask) === (exp_payload & mask))
            `uvm_info(get_name(), $sformatf(
                "[4.x] MISO OK: mode=%0d word_len=%0d expected=0x%08h got=0x%08h",
                spi_mode, word_len, exp_payload & mask, rd.rdata_o & mask), UVM_LOW)
        else
            `uvm_error(get_name(), $sformatf(
                "[4.x] MISO FAIL: mode=%0d word_len=%0d expected=0x%08h got=0x%08h",
                spi_mode, word_len, exp_payload & mask, rd.rdata_o & mask))
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200;

        for (int m = 0; m < 4; m++) begin
            for (int w = 0; w < 4; w++) begin
                run_one_case(m[1:0], w[1:0]);
            end
        end

        phase.drop_objection(this);
    endtask
endclass : spi_miso_base_test

class spi_miso_read_test extends spi_miso_base_test;
    `uvm_component_utils(spi_miso_read_test)

    function new(string name = "spi_miso_read_test", uvm_component parent = null);
        super.new(name, parent);
        exp_miso_byte = 8'h5A;
    endfunction
endclass : spi_miso_read_test

class spi_miso_all_0_test extends spi_miso_base_test;
    `uvm_component_utils(spi_miso_all_0_test)

    function new(string name = "spi_miso_all_0_test", uvm_component parent = null);
        super.new(name, parent);
        exp_miso_byte = 8'h00;
    endfunction
endclass : spi_miso_all_0_test

class spi_miso_all_1_test extends spi_miso_base_test;
    `uvm_component_utils(spi_miso_all_1_test)

    function new(string name = "spi_miso_all_1_test", uvm_component parent = null);
        super.new(name, parent);
        exp_miso_byte = 8'hFF;
    endfunction
endclass : spi_miso_all_1_test

`endif
