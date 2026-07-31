// spi_burst_test — VPlan 6.1
//   连发 4 帧（0x11/0x22/0x33/0x44），验证背靠背 SPI 传输
//   scoreboard 自动比对 4 笔

`ifndef SPI_BURST_TEST_SV
`define SPI_BURST_TEST_SV

class spi_burst_test extends test_base;
    `uvm_component_utils(spi_burst_test)
    function new(string name = "spi_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        automatic bit [31:0]  data_q[4] = '{32'h11, 32'h22, 32'h33, 32'h44};
        phase.raise_objection(this);
        #200;

        foreach (data_q[i]) begin
            seq = axi_spi_cfg_seq::type_id::create($sformatf("frame%0d", i));
        seq.mosi_data_i = data_q[i];
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();
        end
        `uvm_info(get_name(), "[6.1] 4-frame burst done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_burst_test

`endif
