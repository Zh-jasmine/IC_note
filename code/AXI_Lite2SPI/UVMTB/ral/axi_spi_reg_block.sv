// ============================================================
// axi_spi_reg_block — AXI-SPI 寄存器抽象模型 (RAL)
//
//   access policy 按 DUT 实情标注（关键，决定 RAL 能否跑通）：
//     - DUT 读译码 case 只保留 0x04(busy) / 0x24(miso)，其余读回 0
//       → 8 个配置寄存器是 WO（写得进，frontdoor 读不回 → 只能 backdoor peek 验证）
//     - busy / miso 是 RO（硬件更新，frontdoor read 能读真值）
//
//   backdoor: block 设 root hdl path = tb_top.DUT.AXI_SPI_n_regs0，
//             每个 reg 加 slv_regN 的 slice，peek/poke 即走 uvm_hdl_read/deposit。
// ============================================================
`ifndef AXI_SPI_REG_BLOCK_SV
`define AXI_SPI_REG_BLOCK_SV

// ---- 单寄存器定义 ----

// 0x00 start (WO) — 写 0→1 触发一次 SPI 传输
class reg_start extends uvm_reg;
    `uvm_object_utils(reg_start)
    rand uvm_reg_field start;
    function new(string name = "reg_start");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        start = uvm_reg_field::type_id::create("start");
        // configure(parent, size, lsb, access, volatile, reset, has_reset, is_rand, indiv)
        start.configure(this, 1, 0, "WO", 0, 1'h0, 1, 1, 1);
    endfunction
endclass

// 0x04 status (RO) — busy 标志，硬件更新
class reg_status extends uvm_reg;
    `uvm_object_utils(reg_status)
    rand uvm_reg_field busy;
    function new(string name = "reg_status");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        busy.configure(this, 1, 0, "RO", 1, 1'h0, 1, 0, 1);
    endfunction
endclass

// 0x08 spi_mode (WO) — CPOL/CPHA
class reg_spi_mode extends uvm_reg;
    `uvm_object_utils(reg_spi_mode)
    rand uvm_reg_field mode;
    function new(string name = "reg_spi_mode");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        mode = uvm_reg_field::type_id::create("mode");
        mode.configure(this, 2, 0, "WO", 0, 2'h0, 1, 1, 1);
    endfunction
endclass

// 0x0C sck_speed (WO)
class reg_sck_speed extends uvm_reg;
    `uvm_object_utils(reg_sck_speed)
    rand uvm_reg_field speed;
    function new(string name = "reg_sck_speed");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        speed = uvm_reg_field::type_id::create("speed");
        speed.configure(this, 2, 0, "WO", 0, 2'h0, 1, 1, 1);
    endfunction
endclass

// 0x10 word_len (WO)
class reg_word_len extends uvm_reg;
    `uvm_object_utils(reg_word_len)
    rand uvm_reg_field wlen;
    function new(string name = "reg_word_len");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        wlen = uvm_reg_field::type_id::create("wlen");
        wlen.configure(this, 2, 0, "WO", 0, 2'h0, 1, 1, 1);
    endfunction
endclass

// 0x14 ifg (WO)
class reg_ifg extends uvm_reg;
    `uvm_object_utils(reg_ifg)
    rand uvm_reg_field ifg;
    function new(string name = "reg_ifg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        ifg = uvm_reg_field::type_id::create("ifg");
        ifg.configure(this, 8, 0, "WO", 0, 8'h0, 1, 1, 1);
    endfunction
endclass

// 0x18 cs_sck (WO)
class reg_cs_sck extends uvm_reg;
    `uvm_object_utils(reg_cs_sck)
    rand uvm_reg_field cs_sck;
    function new(string name = "reg_cs_sck");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        cs_sck = uvm_reg_field::type_id::create("cs_sck");
        cs_sck.configure(this, 8, 0, "WO", 0, 8'h0, 1, 1, 1);
    endfunction
endclass

// 0x1C sck_cs (WO)
class reg_sck_cs extends uvm_reg;
    `uvm_object_utils(reg_sck_cs)
    rand uvm_reg_field sck_cs;
    function new(string name = "reg_sck_cs");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        sck_cs = uvm_reg_field::type_id::create("sck_cs");
        sck_cs.configure(this, 8, 0, "WO", 0, 8'h0, 1, 1, 1);
    endfunction
endclass

// 0x20 mosi_data (WO) — 待发送 SPI 数据
class reg_mosi_data extends uvm_reg;
    `uvm_object_utils(reg_mosi_data)
    rand uvm_reg_field data;
    function new(string name = "reg_mosi_data");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 32, 0, "WO", 0, 32'h0, 1, 1, 1);
    endfunction
endclass

// 0x24 miso_data (RO) — 接收 SPI 数据，硬件更新
class reg_miso_data extends uvm_reg;
    `uvm_object_utils(reg_miso_data)
    rand uvm_reg_field data;
    function new(string name = "reg_miso_data");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
        data = uvm_reg_field::type_id::create("data");
        data.configure(this, 32, 0, "RO", 1, 32'h0, 1, 0, 1);
    endfunction
endclass

// ---- 寄存器块 ----
class axi_spi_reg_block extends uvm_reg_block;
    `uvm_object_utils(axi_spi_reg_block)

    rand reg_start     start;
    rand reg_status    status;
    rand reg_spi_mode  spi_mode;
    rand reg_sck_speed sck_speed;
    rand reg_word_len  word_len;
    rand reg_ifg       ifg;
    rand reg_cs_sck    cs_sck;
    rand reg_sck_cs    sck_cs;
    rand reg_mosi_data mosi_data;
    rand reg_miso_data miso_data;

    uvm_reg_map map;

    function new(string name = "axi_spi_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        // ---- 创建并 build 每个 reg ----
        start     = reg_start    ::type_id::create("start");     start.build();
        status    = reg_status   ::type_id::create("status");    status.build();
        spi_mode  = reg_spi_mode ::type_id::create("spi_mode");  spi_mode.build();
        sck_speed = reg_sck_speed::type_id::create("sck_speed"); sck_speed.build();
        word_len  = reg_word_len ::type_id::create("word_len");  word_len.build();
        ifg       = reg_ifg      ::type_id::create("ifg");       ifg.build();
        cs_sck    = reg_cs_sck   ::type_id::create("cs_sck");    cs_sck.build();
        sck_cs    = reg_sck_cs   ::type_id::create("sck_cs");    sck_cs.build();
        mosi_data = reg_mosi_data::type_id::create("mosi_data"); mosi_data.build();
        miso_data = reg_miso_data::type_id::create("miso_data"); miso_data.build();

        // configure 把 reg 挂到 block（第二参 regfile=null）
        start    .configure(this, null, "");
        status   .configure(this, null, "");
        spi_mode .configure(this, null, "");
        sck_speed.configure(this, null, "");
        word_len .configure(this, null, "");
        ifg      .configure(this, null, "");
        cs_sck   .configure(this, null, "");
        sck_cs   .configure(this, null, "");
        mosi_data.configure(this, null, "");
        miso_data.configure(this, null, "");

        // ---- 地址映射（base=0, 4-byte bus, 小端, byte addressing）----
        map = create_map("map", 32'h0, 4, UVM_LITTLE_ENDIAN, 1);
        map.add_reg(start,     32'h00, "WO");
        map.add_reg(status,    32'h04, "RO");
        map.add_reg(spi_mode,  32'h08, "WO");
        map.add_reg(sck_speed, 32'h0C, "WO");
        map.add_reg(word_len,  32'h10, "WO");
        map.add_reg(ifg,       32'h14, "WO");
        map.add_reg(cs_sck,    32'h18, "WO");
        map.add_reg(sck_cs,    32'h1C, "WO");
        map.add_reg(mosi_data, 32'h20, "WO");
        map.add_reg(miso_data, 32'h24, "RO");

        // ---- backdoor: root hdl path + 每 reg slice ----
        add_hdl_path("tb_top.DUT.AXI_SPI_n_regs0");
        start    .add_hdl_path_slice("slv_reg0", 0, 32);
        status   .add_hdl_path_slice("slv_reg1", 0, 32);
        spi_mode .add_hdl_path_slice("slv_reg2", 0, 32);
        sck_speed.add_hdl_path_slice("slv_reg3", 0, 32);
        word_len .add_hdl_path_slice("slv_reg4", 0, 32);
        ifg      .add_hdl_path_slice("slv_reg5", 0, 32);
        cs_sck   .add_hdl_path_slice("slv_reg6", 0, 32);
        sck_cs   .add_hdl_path_slice("slv_reg7", 0, 32);
        mosi_data.add_hdl_path_slice("slv_reg8", 0, 32);
        miso_data.add_hdl_path_slice("slv_reg9", 0, 32);

        lock_model();
    endfunction

endclass : axi_spi_reg_block

`endif
