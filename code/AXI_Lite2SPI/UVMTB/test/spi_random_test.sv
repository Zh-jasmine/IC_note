// spi_random_test — VPlan 6.x
//   80 帧约束随机回归：mode × word_len × sck_speed × data 随机组合
//   scoreboard 逐帧比对，coverage 累积填满 cross bins

`ifndef SPI_RANDOM_TEST_SV
`define SPI_RANDOM_TEST_SV

class spi_random_test extends test_base;
    `uvm_component_utils(spi_random_test)

    int num_frames = 80;

    function new(string name = "spi_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        for (int i = 0; i < num_frames; i++) begin
            seq = axi_spi_cfg_seq::type_id::create($sformatf("rand%0d", i));

            if (!seq.randomize() with {
                cs_sck_i inside {[2:8]};
                sck_cs_i inside {[2:8]};
                ifg_i    inside {[1:8]};
            })
                `uvm_error(get_name(), "axi_spi_cfg_seq randomize failed")

        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();
        end

        `uvm_info(get_name(), $sformatf("random regression done: %0d frames", num_frames), UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_random_test

`endif
