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

# Greg Stitt
# Wes Piard
# University of Florida

package require cmdline
load_package report

proc remove_commas {s} {
    return [regsub -all "," $s ""]
}

# Gets a numeric result with the specified command (cmd) and arguments (args)
# If an error occurs in Quartus, this catches the error and returns n/a.
proc get_result {cmd args} {

    if { [catch {
        set val [remove_commas [$cmd {*}$args]]
    } err ] } {
        set val "n/a"
    }

    return $val
}

set usage "- script to collect results from a compiled project"

# Process command line
set parameters {
    {q.arg "" "Project QSF file name (without extension) -required"}
    {r.arg "" "Revision name -optional"}
    {p.arg "" "Parameter name/value pairs -optional"}
    {f.arg "" "Output file -required"}
}
set args $quartus(args)
array set options [cmdline::getoptions args $parameters $usage]

# Check for required parameters
if {[expr {$options(q) == ""}]} {
    return -code error "QSF name required"
}
if {[expr {$options(f) == ""}]} {
    return -code error "Output file name required"
}

# By default set the revision equal to the project name.
if {[expr {$options(r) == ""}]} {
    set options(r) $options(q)
}

set project $options(q)
set rev $options(r)
set filename $options(f)

# Parse parameter string
set params [split $options(p) "^"]
set length [llength $params]
set parameter_headers ""
set parameter_values ""

for {set i 0} {$i < $length} {incr i} {
    set param [lindex $params $i]
    set args [split $param " "]
    if {[llength $args] == 2} {
        set name [lindex $args 0]
        set value [lindex $args 1]
        append parameter_headers $name ","
        append parameter_values $value ","
    }
}

# Open existing project and report
project_open $project -revision $rev
load_report $project

# Shortcut of get_report_panel_data command
set cmd get_report_panel_data

# https://www.intel.com/content/www/us/en/programmable/quartushelp/19.4/index.htm#tafs/tafs/tcl_pkg_report_ver_1.0_cmd_get_report_panel_data.htm
# Get Fmax and restricted Fmax
# NOTE: The row and column might change across Quartus versions.
if { [catch {
    set fmax_line            [$cmd -name {*Fmax*} -row 1 -col 0]
    [regexp {[0-9]+[\.0-9]*} $fmax_line fmax]
} err ] } {
    set fmax "n/a"
}

if { [catch {
    set rfmax_line [$cmd -name {*Fmax*} -row 1 -col 1]
    [regexp {[0-9]+[\.0-9]*} $rfmax_line rfmax]
} err ] } {
    set rfmax "n/a"
}

# Shortcut of get_fitter_resource_usage command
set cmd     get_fitter_resource_usage
# https://www.intel.com/content/www/us/en/programmable/quartushelp/19.4/index.htm#tafs/tafs/tcl_pkg_report_ver_2.1_cmd_get_fitter_resource_usage.htm

# Collect all the resource results
set util [get_result $cmd -utilization -used]
set util_total [get_result $cmd -utilization -available]
set alut [get_result $cmd -alut -used]
set alut_total [get_result $cmd -alut -available]
set alm [get_result $cmd -alm -used]
set alm_total [get_result $cmd -alm -available]
set le [get_result $cmd -le -used]
set le_total [get_result $cmd -le -available]
set reg [get_result $cmd -reg -used]

# Register total not provided in summary
#set reg_line [get_report_panel_row {*Fitter Resource Usage Summary*} -row 31]
if { [catch {
    set reg_line [get_report_panel_data -name {*Fitter Resource Usage Summary*} -row 31 -col 1]
    [regexp {/ ([0-9]+[,0-9]*)} $reg_line a reg_total]
    set reg_total [remove_commas $reg_total]
} err ] } {
    set reg_total "n/a"
}

set io [get_result $cmd -io_pin -used]
set io_total [get_result $cmd -io_pin -available]
set mem_bit [get_result $cmd -mem_bit -used]
set mem_bit_total [get_result $cmd -mem_bit -available]

if { [catch {
    set dsp_line [$cmd -resource "DSP*"]
    [regexp {[0-9]+[,0-9]*} $dsp_line dsp_count]
    [regexp {/ ([0-9]+[,0-9]*) \(} $dsp_line a dsp_total]
    set dsp_count [remove_commas $dsp_count]
    set dsp_total [remove_commas $dsp_total]
} err ] } {
    set dsp_count "n/a"
    set dsp_total "n/a"
}

if { [catch {
    set mem_line [$cmd -resource "M*K*"]
    [regexp {[0-9]+[,0-9]*} $mem_line mem_count]
    [regexp {/ ([0-9]+[,0-9]*) \(} $mem_line a mem_total]
    set mem_count [remove_commas $mem_count]
    set mem_total [remove_commas $mem_total]
} err ] } {
    set mem_count "n/a"
    set mem_total "n/a"
}

# Get the compilation times
set cmd get_report_panel_data
if { [catch {
    set synth_time [$cmd -name {Flow Elapsed Time} -row 1 -col 1]
    set synth_mem [$cmd -name {Flow Elapsed Time} -row 1 -col 2]
    set fit_time [$cmd -name {Flow Elapsed Time} -row 2 -col 1]
    set fit_mem [$cmd -name {Flow Elapsed Time} -row 2 -col 2]
} err ] } {
    set synth_time "n/a"
    set synth_mem "n/a"
    set fit_time "n/a"
    set fit_mem "n/a"
}

# TODO: collect routing information.

#set print_header 1

# If the file doesn't exist, create it. Otherwise, open it for appending.
#if {[file exists $filename] == 0} {
#    set outfile [open $filename w]
#} else {
#    set outfile [open $filename a]
#    set print_header 0
#}

#if {$print_header == 1} {
#puts $outfile "${parameter_headers}fMax,fMax (restricted),Logic,Logic(Total),ALUTs,ALUTs (Total),ALMs,ALMs (Total),LEs,LEs (Total),REGs,REGs (Total),IO,IO (Total),MemBits,MemBits (Total),MemBlocks,MemBlocks (Total),DSPs,DSPs (Total),Synth Time,Synth Mem,Fit Time,Fit Mem"
#}
#puts $outfile "$parameter_values$fmax,$rfmax,$util,$util_total,$alut,$alut_total,$alm,$alm_total,$le,$le_total,$reg,$reg_total,$io,$io_total,$mem_bit,$mem_bit_total,$mem_count,$mem_total,$dsp_count,$dsp_total,$synth_time,$synth_mem,$fit_time,$fit_mem"
puts "HEADERS: fMax,fMax (restricted),Logic,Logic(Total),ALUTs,ALUTs (Total),ALMs,ALMs (Total),LEs,LEs (Total),REGs,REGs (Total),IO,IO (Total),MemBits,MemBits (Total),MemBlocks,MemBlocks (Total),DSPs,DSPs (Total),Synth Time,Synth Mem,Fit Time,Fit Mem"
puts "VALUES: $fmax,$rfmax,$util,$util_total,$alut,$alut_total,$alm,$alm_total,$le,$le_total,$reg,$reg_total,$io,$io_total,$mem_bit,$mem_bit_total,$mem_count,$mem_total,$dsp_count,$dsp_total,$synth_time,$synth_mem,$fit_time,$fit_mem"
#close $outfile

# Unload report and close project
unload_report
project_close
