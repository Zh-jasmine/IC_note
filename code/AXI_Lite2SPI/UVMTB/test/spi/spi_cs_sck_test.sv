// spi_cs_sck_test - VPlan 3.1
//   Sweep CS_SCK register values and check SPI data transfer still completes.
`ifndef SPI_CS_SCK_TEST_SV
`define SPI_CS_SCK_TEST_SV

class spi_cs_sck_test extends test_base;
    `uvm_component_utils(spi_cs_sck_test)

    function new(string name = "spi_cs_sck_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic int cs_sck;
        automatic axi_spi_cfg_seq seq;

        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 3; i++) begin
            case (i)
                0: cs_sck = 2;
                1: cs_sck = 4;
                2: cs_sck = 8;
            endcase

            seq = axi_spi_cfg_seq::type_id::create("seq");
            seq.cs_sck_i    = cs_sck;
            seq.mosi_data_i = 32'hA5;
            seq.start(env.axi_agt.axi_sqr);
            wait_spi_done();

            `uvm_info(get_name(), $sformatf("CS_SCK=%0d transfer done", cs_sck), UVM_LOW)
        end

        phase.drop_objection(this);
    endtask
endclass : spi_cs_sck_test

`endif