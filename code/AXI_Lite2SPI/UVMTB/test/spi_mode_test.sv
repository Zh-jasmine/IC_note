// spi_mode_test — VPlan 2
//   验证 SPI Mode 0/1/2/3（CPOL×CPHA 四种组合）
//   8-bit 字长下逐 mode 发一帧，scoreboard 比对 MOSI 数据

class spi_mode_test extends test_base;

    `uvm_component_utils(spi_mode_test)

    function new(string name = "spi_mode_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200;

        for (int m = 0; m < 4; m++) begin
            run_spi_mode(m[1:0], 32'hAB);
        end

        phase.drop_objection(this);
    endtask : run_phase

    local task automatic run_spi_mode(
        input bit [1:0]  mode_enc,
        input bit [31:0] mosi_data
    );
        axi_spi_cfg_seq seq = axi_spi_cfg_seq::type_id::create("seq");
        seq.spi_mode_i  = mode_enc;
        seq.mosi_data_i     = mosi_data;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();
    endtask : run_spi_mode

endclass : spi_mode_test
