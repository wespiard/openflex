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

import sys
import click
from .config import FlexConfig


@click.command()
@click.argument("config_file")
@click.option("-m", "--mode", help="sim or synth")
@click.option("-t", "--tool", help="questa, quartus, vivado")
@click.option("-c", "--synth_csv", help="results csv file for synthesis runs")
@click.option("-p", "--clk_period", help="clock period", default="1.0")
@click.option("-s", "--sample", help="randomly sample specified amount")
def run(config_file, mode, tool, synth_csv, clk_period, sample):
    dut = FlexConfig(config_file)

    # The command line can override the mode and tool of the YAML
    mode = mode if mode else dut.config["mode"]
    tool = tool if tool else dut.config["tool"]

    if sample:
        dut.sample(sample)

    if mode == "sim":
        if tool == "questa":
            dut.questa_sim()
        else:
            sys.exit("ERROR: Invalid simulator.")
    elif mode == "synth":

        if not synth_csv:
            sys.exit("ERROR: Missing CSV filename")

        if tool == "vivado":
            dut.vivado_synth(synth_csv, clk_period)
        elif tool == "quartus":
            dut.quartus_synth(synth_csv, clk_period)
        else:
            sys.exit("ERROR: Invalid synthesis tool.")
    else:
        sys.exit("ERROR: Invalid mode.")
