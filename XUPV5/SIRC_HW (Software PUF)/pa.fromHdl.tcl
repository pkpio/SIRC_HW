
# PlanAhead Launch Script for Pre-Synthesis Floorplanning, created by Project Navigator

create_project -name SIRC -dir "C:/Users/praveen/Xilinx work/Dropbox/Rice Internship work/Farinaz - Low power high speed PUFs/PUF testing code/SIRC_HW/planAhead_run_1" -part xc5vlx110tff1136-1
set_param project.pinAheadLayout yes
set srcset [get_property srcset [current_run -impl]]
set_property top system $srcset
set_param project.paUcfFile  "C:/Program Files (x86)/Microsoft Research/Simple Interface for Reconfigurable Computing (SIRC) v1.1/Salar/HWSrc/ML505-6-7-XUPV5/XUPV5system.ucf"
add_files [list {ipcore_dir/blk_mem_gen_paramReg.ngc}]
set hdlfile [add_files [list {ipcore_dir/emac_single/example_design/physical/gmii_if.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/emac_single/example_design/emac_single.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/emac_single/example_design/client/fifo/tx_client_fifo_8.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/emac_single/example_design/client/fifo/rx_client_fifo_8.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {PUF.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/emac_single/example_design/emac_single_block.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/emac_single/example_design/client/fifo/eth_fifo_8.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/blk_mem_gen_paramReg.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/blk_mem_gen_outputMem.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/blk_mem_gen_inputMem.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {iobuf.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {fifo36Wrapper.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {serialTransmitReceive.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ipcore_dir/emac_single/example_design/emac_single_locallink.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ethernetController.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {simpleTestModuleOne.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {ethernet2BlockMem.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {system.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
add_files "C:/Program Files (x86)/Microsoft Research/Simple Interface for Reconfigurable Computing (SIRC) v1.1/Salar/HWSrc/ML505-6-7-XUPV5/XUPV5system.ucf" -fileset [get_property constrset [current_run]]
add_files "ipcore_dir/blk_mem_gen_inputMem.ncf" "ipcore_dir/blk_mem_gen_outputMem.ncf" "ipcore_dir/blk_mem_gen_paramReg.ncf" -fileset [get_property constrset [current_run]]
open_rtl_design -part xc5vlx110tff1136-1
