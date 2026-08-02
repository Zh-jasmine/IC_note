file mkdir logs
transcript file logs/axi_env_build_test.log
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vlog -sv -f compile_filelist.f
vsim -c tb_top -do "run -all; quit -f"
