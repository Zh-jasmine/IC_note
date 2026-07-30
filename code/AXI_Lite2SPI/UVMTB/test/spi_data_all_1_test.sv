// spi_data_all_1_test — VPlan 7.2
//   全 1 数据（0xFF），验证 MOSI 全高、SCK 正常脉冲、scoreboard 匹配

`ifndef SPI_DATA_ALL_1_TEST_SV
`define SPI_DATA_ALL_1_TEST_SV

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
        seq.mosi_data_i     = 32'hFF;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();

        `uvm_info(get_name(), "[7.2] data=0xFF done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_data_all_1_test

`endif
