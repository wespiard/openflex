# Copyright (c) 2024 Greg Stitt, Wesley Piard, University of Florida
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set num_args [llength $argv]

if {$num_args < 2} {
    error "ERROR: usage <top_module_name> <device_name> [clock_period]"
}

set top [lindex $argv 0]
set device [lindex $argv 1]

# Default to 1 ns
if {$num_args > 2} {
    set clock_period [lindex $argv 2]
} else {
    set clock_period 1
    puts "INFO: Using default clock constraint of 1 ns."
}

# Get file names
set filelist_path "filelist.txt"
set fileID [open $filelist_path r]
set file_names [split [read $fileID] "\n"]
close $fileID

# define the output directory
set output_dir ./outputs
file mkdir $output_dir

# top level module/entity name
#set top alignment_buffer
#set top vlp_delimited

# choose FPGA part number
# set device xc7k70tfbg676-2
#set device xcku3p-ffva676-2-e
#set device xcvu9p-flga2104-2L-e

puts "----------------------------------------"
puts " Reading design files"
puts "----------------------------------------"

set num_files [llength $file_names]
puts "Num Files = $num_files"

foreach file $file_names {
    if {![string is space $file]} {
    
        puts "Processing file ->$file<-"
        read_verilog -sv $file
    }
}

# https://support.xilinx.com/s/article/52217?language=en_US
#set_param [get_cells $top] -set WORD_WIDTH 16

#set_property generic {WORD_WIDTH=16} [current_fileset]

set pairs_list {}
set parameters_path "parameters.txt"
set fileID [open $parameters_path r]

# Read each line from the file
while {[gets $fileID line] != -1} {
    # Split the line into two strings using whitespace as the delimiter
    set pair [split $line]

    # Append the pair to the list
    lappend pairs_list $pair
}
close $fileID

# load design sources
# `-sv` flag not necessary if files have `.sv` extensions
#read_verilog -sv ../../delay.sv
#read_verilog -sv ../../delay_taps.sv
#read_verilog -sv ../../shift_pipe.sv
#read_verilog -sv ../../shift_lr_pipe.sv
#read_verilog -sv ../../field_aligner.sv
#read_verilog -sv ../../field_buffer.sv
#read_verilog -sv ../../priority_encoder_pipe.sv
#read_verilog -sv ../../priority_encoder_multi_pipe.sv
#read_verilog -sv ../../vlp_delimited.sv

# load constraints
# NOTE: remove `-mode out_of_context` argument for full 
# implementation w/ top level design and real FPGA/board,
# or specify a different XDC file for that case.
read_xdc vivado.xdc

# set parameters/generics
# set_property generic parameter_name=value [get_filesets sources_1]


puts "----------------------------------------"
puts " Running out-of-contex synthesis"
puts "----------------------------------------"

# --------------------------------------------------------
# Run synthesis, write design checkpoint, report timing, 
# and utilization estimates
# --------------------------------------------------------

# Synthesize
#synth_design -top $top -part $device -mode out_of_context

set synth_cmd "synth_design -top $top -part $device -mode out_of_context"
foreach pair $pairs_list {
    #puts "Pair 1: [lindex $pair 0], Pair 2: [lindex $pair 1]"
    set pname [lindex $pair 0]
    set pval [lindex $pair 1]
    append synth_cmd " -generic $pname=$pval"
}
#puts $synth_cmd
eval $synth_cmd

write_checkpoint -force $output_dir/post_synth.dcp
report_methodology -file $output_dir/post_synth_methodology.rpt
report_timing_summary -file $output_dir/post_synth_timing_summary.rpt
report_utilization -file $output_dir/post_synth_util.rpt

# TODO: From ug909: 
# It is recommended to close the design in memory after synthesis, 
# and run implementation separately from synthesis.

puts "----------------------------------------"
puts " Implementation (Optimization, P&R)"
puts "----------------------------------------"
# run logic optimization, placement and physical logic optimization, 
# write design checkpoint, report utilization and timing estimates
opt_design
place_design
report_clock_utilization -file $output_dir/clock_util.rpt

# Optionally run optimization if there are timing violations after placement
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
    puts "Found setup timing violations => running physical optimization"
    phys_opt_design
}
write_checkpoint -force $output_dir/post_place.dcp
report_utilization -file $output_dir/post_place_util.rpt
report_timing_summary -file $output_dir/post_place_timing_summary.rpt

# run the router, write the post-route design checkpoint, report the routing
# status, report timing, power, and DRC, and finally save the Verilog netlist.
route_design
write_checkpoint -force $output_dir/post_route.dcp
report_route_status -file $output_dir/post_route_status.rpt
report_timing_summary -file $output_dir/post_route_timing_summary.rpt
report_power -file $output_dir/post_route_power.rpt
report_drc -file $output_dir/post_imp_drc.rpt
report_design_analysis -timing -logic_level_distribution -of_timing_paths [get_timing_paths -max_paths 10000 -slack_lesser_than 0] -file $output_dir/route_vios.rpt
report_timing -of [get_timing_paths -max_paths 1000 -slack_lesser_than 0] -file $output_dir/route_paths.rpt -rpx $output_dir/route_paths.rpx
# report_qor_suggestions -file $output_dir/route_rqs.rpt
# write_qor_suggestions -force -tcl_output_dir $output_dir/route_wqs $output_dir/route_wqs.rpt
# write_verilog -force $output_dir/cpu_impl_netlist.v -mode timesim -sdf_anno true


# Get WNS
set wns ""
foreach timing_entry [get_timing_paths -delay_type max] {
    set slack [lindex [get_property SLACK $timing_entry] 0]    
    if {$wns eq "" || $slack < $wns} {
        set wns $slack
    }
}

if {$wns ne ""} {    
    set fMax [expr (1000 / ($clock_period - $wns))]
} else {
    set fMax "n/a"    
}

# Capture resource utilization
set utilization_output [get_utilization]

# Specify the file path where you want to save the utilization report
set vivado_report_file "vivado_report.txt"

# Open the file for writing
set file_id [open $vivado_report_file "w"]

# Write the outputs to the file
puts $file_id $fMax
puts $file_id $utilization_output

# Close the file
close $file_id


# generate a bitstream
# write_bitstream -force $output_dir/cpu.bit
puts "----------------------------------------"
puts " Flow complete"
puts "----------------------------------------"
