transcript file logs/axi_env_build_test.log
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

set dpi_lib axi_ref_model
if {$::tcl_platform(os) eq "Darwin"} {
    exec gcc -dynamiclib -fPIC -o ${dpi_lib}.dylib ../tb/environment/axi_ref_model.c
} else {
    exec gcc -shared -fPIC -o ${dpi_lib}.so ../tb/environment/axi_ref_model.c
}

vlog -sv -f compile_filelist.f
vsim -c tb_top -sv_lib ./${dpi_lib} -do "run -all; quit -f"
