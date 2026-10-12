# PYNQ-Z1 pin constraints for the current design_1_wrapper.
# Verified top-level ports:
#   clk_125MHz, btn_tri_i[0], data[7:0], data_valid, data_ready
#
# Board pins:
#   H16 = onboard 125 MHz PL clock input
#   D19 = BTN0
#   JA1..JA4, JA7..JA10 = data[7:0]
#   JB1 = data_valid, JB2 = data_ready
#
# The Clock Wizard IP XDC already defines the 8 ns primary clock and derives
# clk_out1 (100 MHz) and clk_out2 (125 MHz). Do not create another clock on
# clk_125MHz here: a duplicate causes XDCC-1/XDCC-7 scoped-clock warnings.
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports {clk_125MHz}]

# BTN0 -> AXI GPIO button input
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports {btn_tri_i[0]}]

# Pmod JA -> incoming 8-bit data bus
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {data[0]}]
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports {data[1]}]
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports {data[2]}]
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports {data[3]}]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {data[4]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {data[5]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {data[6]}]
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {data[7]}]

# Pmod JB -> external byte-valid and ready handshake
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports {data_valid}]
set_property -dict { PACKAGE_PIN Y14 IOSTANDARD LVCMOS33 } [get_ports {data_ready}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */sync_100_reg/D}]
# data and data_valid have no external source-clock input in this wrapper.
# If the external sender is not clocked from the same clock source as the
# receiver, add a top-level data_clk port, connect it to the receiver and the
# FIFO write clock, and assign that clock to a board pin. Add create_clock and
# set_input_delay constraints only from the sender's timing specification.
# Do not constrain unknown external input delays with guessed values.
#
# Add set_output_delay for data_ready only if the external receiver samples it
# and its clock/timing relationship is specified.
