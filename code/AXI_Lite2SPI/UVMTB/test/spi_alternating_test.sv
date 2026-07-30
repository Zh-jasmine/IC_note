// spi_alternating_test — VPlan 6.2
//   交替发 0x55/0xAA 共 6 帧，验证相邻位翻转不串扰
//   scoreboard 比对每帧

`ifndef SPI_ALTERNATING_TEST_SV
`define SPI_ALTERNATING_TEST_SV

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
