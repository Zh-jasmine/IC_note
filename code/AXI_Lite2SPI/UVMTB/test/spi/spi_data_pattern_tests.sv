// SPI MOSI data pattern tests:
//   - all 0
//   - all 1
//   - alternating 0x55 / 0xAA burst

`ifndef SPI_DATA_PATTERN_TESTS_SV
`define SPI_DATA_PATTERN_TESTS_SV

class spi_data_all_0_test extends test_base;
    `uvm_component_utils(spi_data_all_0_test)

    function new(string name = "spi_data_all_0_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        seq = axi_spi_cfg_seq::type_id::create("cfg");
        seq.mosi_data_i = 32'h00;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();

        `uvm_info(get_name(), "[7.1] data=0x00 done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_data_all_0_test

class spi_data_all_1_test extends test_base;
    `uvm_component_utils(spi_data_all_1_test)

    function new(string name = "spi_data_all_1_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        seq = axi_spi_cfg_seq::type_id::create("cfg");
        seq.mosi_data_i = 32'hFF;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();

        `uvm_info(get_name(), "[7.2] data=0xFF done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_data_all_1_test

class spi_alternating_test extends test_base;
    `uvm_component_utils(spi_alternating_test)

    function new(string name = "spi_alternating_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 6; i++) begin
            seq = axi_spi_cfg_seq::type_id::create($sformatf("alt%0d", i));
            seq.mosi_data_i = (i % 2) ? 32'hAA : 32'h55;
            seq.start(env.axi_agt.axi_sqr);
            wait_spi_done();
        end

        `uvm_info(get_name(), "[6.2] alternating 0x55/0xAA done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_alternating_test

`endif
