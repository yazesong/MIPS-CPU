-makelib xcelium_lib/xpm -sv \
  "D:/vivado/Vivado/2022.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "D:/vivado/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../MIPS-CPU.gen/sources_1/ip/clocking_1/clocking_clk_wiz.v" \
  "../../../../MIPS-CPU.gen/sources_1/ip/clocking_1/clocking.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

