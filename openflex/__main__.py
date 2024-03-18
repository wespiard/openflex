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

import os
import sys
import copy
import random
import pathlib
import itertools
import subprocess
import csv
import yaml
import click


class FlexConfig:
    def __init__(self, config_file) -> None:
        try:
            with open(config_file, "r") as y:
                self.config = yaml.load(y, Loader=yaml.loader.BaseLoader)
        except yaml.YAMLError as e:
            sys.exit("Issue with provided YAML configuration file.\n" + repr(e))

        # Initialize object attributes with values from YAML config
        self.files = [os.path.abspath(f) for f in self.config["files"]]
        self.parameters = self.config["parameters"]

        # Gather combinations of parameters (Cartesian product)
        param_names = []
        param_combinations = []

        if "parameters" in self.config:
            param_dict = self.config["parameters"]
            param_names = list(param_dict.keys())
            value_combinations = list(itertools.product(*param_dict.values()))
            param_combinations = [dict(zip(param_names, v)) for v in value_combinations]

        if "groups" in self.config:
            group_params = []

            for g in self.config["groups"]:
                intersection = set(g.keys()).intersection(set(param_names))

                # If the current group is mutually exclusive to the existing parameters.
                if not intersection:
                    param_names.extend(g.keys())
                    if not param_combinations:
                        param_combinations = g
                    for p in param_combinations:
                        p.update(g)

                # If the current group is a subset of the existing parameters.
                elif intersection == set(g.keys()):
                    param_combinations2 = copy.deepcopy(param_combinations)
                    for p in param_combinations2:
                        p.update(g)

                    group_params.append(param_combinations2)
                else:
                    # fmt: off
                    sys.exit("ERROR: Parameter group must either be a subset of the existing parameters, or mutually exclusive." )
                    # fmt: on

            for g in group_params:
                param_combinations.extend(g)

        self.combinations = param_combinations

        # if not "clock" in self.config:
        #    self.config["clock"] = "clk"

        # if not "reset" in self.config:
        #    self.config["clock"] = "rst"

    def filter(self, f):
        self.combinations = list(filter(f, self.combinations))

    def add_parameter(self, name, func, **kwargs):
        new_combs = []
        for c in self.combinations:
            for v in func(c, kwargs):
                d = dict(c)
                d[name] = v
                new_combs.append(d)

        self.combinations = new_combs

    def sample(self, n):
        self.combinations = random.sample(self.combinations, int(n))

    def process_vivado_results(self, parameters, csv_filename):
        vivado_file = "tcl/vivado_report.txt"

        with open(vivado_file, "r") as file:
            # Read the first line as a float
            try:
                clock_freq = float(file.readline().strip())
            except ValueError:
                clock_freq = "n/a"

            # Read the second line and split it into 3-tuples
            tuples_line = file.readline().strip()

        tuples_list = tuples_line.split()

        # Parse the 3-tuples into a list of (string, int, int) tuples
        tuples = []
        for item in tuples_list:
            # print(f"ITEM = {item}")
            parts = item.split(":")

            string_value = parts[0]
            int_value1 = int(parts[1])
            int_value2 = int(parts[2])
            # print(f"STRING={string_value} V1={int_value1} V2={int_value2}")
            tuples.append((string_value, int_value1, int_value2))

        if not os.path.exists(csv_filename):
            # Create the CSV column headers
            headers = [x for x in parameters.keys()]
            headers.append("fMax")
            for i in tuples:
                headers.append(f"{i[0]} (Used)")
                headers.append(f"{i[0]} (Total)")

            # A little lazy here to close the file and then re-open it again.
            with open(csv_filename, "w", newline="") as csv_file:
                csv_writer = csv.writer(csv_file)
                csv_writer.writerow(headers)

        with open(csv_filename, "a") as csv_file:
            csv_writer = csv.writer(csv_file)

            row = [x for x in parameters.values()]
            row.append(clock_freq)
            for i in tuples:
                row.append(i[1])
                row.append(i[2])

            csv_writer.writerow(row)

    def vivado_synth(self, csv_filename, clk_period=1.0):
        vivado_dir = "tcl"
        vivado_filelist = f"{vivado_dir}/filelist.txt"
        vivado_parameters = f"{vivado_dir}/parameters.txt"
        vivado_xdc = f"{vivado_dir}/vivado.xdc"

        # Generate the filelist
        with open(vivado_filelist, "w") as file:
            for file_name in self.files:
                file.write(file_name + "\n")

        # Generate the filelist
        for c in self.combinations:
            # Write the parameter values to a file that can be read by TCL
            with open(vivado_parameters, "w") as file:
                for d in c.items():
                    file.write(f"{d[0]} {d[1]}\n")

            # Generate the XDC file for Vivado
            xdc_content = f"""
    create_clock -period {clk_period} [get_ports {self.config["clock"]}] -name clk
    set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports {self.config["clock"]}]
    """
            with open(vivado_xdc, "w") as xdc_file:
                xdc_file.write(xdc_content)

            build_cmd = []
            build_cmd.append("vivado")
            build_cmd.append("-mode")
            build_cmd.append("batch")
            build_cmd.append("-source")
            build_cmd.append("vivado_flow.tcl")
            build_cmd.append("-tclargs")
            build_cmd.append(self.config["top"])
            build_cmd.append(self.config["device"])
            build_cmd.append(clk_period)
            # print(build_cmd)
            subprocess.run(build_cmd, cwd=vivado_dir)

            # Post-process the run to collect results
            self.process_vivado_results(c, csv_filename)

    def process_quartus_results(self, parameters, output, csv_filename):

        lines = output.split("\n")

        for line in lines:
            if line.startswith("HEADERS: "):
                # Strip off the "HEADERS: " prefix
                result_headers = line[len("HEADERS: ") :].split(",")
            elif line.startswith("VALUES: "):
                # Strip off the "VALUES: " prefix
                result_values = line[len("VALUES: ") :].split(",")

        if not os.path.exists(csv_filename):
            # Create the CSV column headers
            headers = [x for x in parameters.keys()]
            headers.extend(result_headers)

            # A little lazy here to close the file and then re-open it again.
            with open(csv_filename, "w", newline="") as csv_file:
                csv_writer = csv.writer(csv_file)
                csv_writer.writerow(headers)

        with open(csv_filename, "a") as csv_file:
            csv_writer = csv.writer(csv_file)

            row = [x for x in parameters.values()]
            row.extend(result_values)

            csv_writer.writerow(row)

    def quartus_synth(self, csv_filename="", clk_period=1.0):

        clk_period = float(clk_period)
        quartus_dir = "tcl"

        for p in self.combinations:

            # Create the SDC file.
            with open(f"{quartus_dir}/{self.config['top']}.sdc", "w") as sdc:
                # fmt: off
                sdc.write("set_time_format -unit ns -decimal_places 3\n")
                sdc.write(f"create_clock -name {{clk}} -period {clk_period} -waveform {{ 0.000 {clk_period/2.0} }} [get_ports {{{self.config['clock']}}}]\n" )
                sdc.write("set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020\n" )
                sdc.write("set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020\n" )
                sdc.write("set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020\n" )
                sdc.write("set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020\n" )
                # fmt: on

            # Create the project.
            create_project_cmd = f"quartus_sh --tcl_eval project_new -overwrite {self.config['top']} -part {self.config['device']}"
            create_project_cmd_list = create_project_cmd.split()
            subprocess.run(create_project_cmd_list, cwd=quartus_dir)

            # Create the QSF.
            with open(f"{quartus_dir}/{self.config['top']}.qsf", "a") as qsf:
                # Add files to the QSF file with a different assignment type based on each file type.

                # Dictionary used to lookup assignment name type based on file's extension.
                assignment_names = {
                    ".v": "VERILOG_FILE",
                    ".sv": "SYSTEMVERILOG_FILE",
                    ".vhd": "VHDL_FILE",
                    ".sdc": "SDC_FILE",
                }

                for f in self.files:
                    ext = pathlib.Path(f).suffix
                    try:
                        qsf.write(f"set_global_assignment -name {assignment_names[ext]} {f}\n")
                    except KeyError as k:
                        print(f"Extension {k} from file in filelist is not supported: {f}.")

                # Define the parameters
                for k, v in p.items():
                    qsf.write(f"set_parameter -name {k} {v}\n")

            # Open the project, set virtual pins, and compile.
            tcl_cmd = (
                f"quartus_sh --tcl_eval project_open {self.config['top']}.qpf;"
                + 'set_instance_assignment -to "*" -name VIRTUAL_PIN ON;'
                + f'set_instance_assignment -to {self.config["clock"]} -name VIRTUAL_PIN OFF;'
                + f'set_instance_assignment -to {self.config["reset"]} -name VIRTUAL_PIN OFF;'
                # + f'remove_all_instance_assignments -name VIRTUAL_PIN -to clk;'
                # + f'remove_all_instance_assignments -name VIRTUAL_PIN -to rst;'
                + "load_package flow;"
                + "execute_module -tool map;"
                + "execute_module -tool fit;"
                + "execute_module -tool sta"
                # + "execute_flow -compile"
            )
            tcl_cmd_list = tcl_cmd.split()
            subprocess.run(tcl_cmd_list, cwd=quartus_dir)

            result_cmd = f"quartus_sh -t quartus_results.tcl -q {self.config['top']} -f {os.path.abspath(csv_filename)}"
            result_cmd_list = result_cmd.split()
            output = subprocess.check_output(
                result_cmd_list, universal_newlines=True, cwd=quartus_dir
            )
            self.process_quartus_results(p, output, csv_filename)

    def questa_sim(self):
        contains_sv = False
        for f in self.files:
            contains_sv = ".sv" in f
            break

        sim_dir = "questa_sim"
        # Create build directory for the current test case
        if not os.path.exists(sim_dir):
            os.mkdir(sim_dir)

        tests_failed = 0
        failed_tests = []

        # Iterate over all parameter combinations and build each one
        for test_case in self.combinations:
            test_name = "build_" + self.config["top"]
            # print(f"test_case {test_case}")
            for (
                param,
                value,
            ) in test_case.items():
                test_name += f"_{param}_{value}"

            print("\n")
            print("----------------------------------------------------------------------")
            print(f"    RUNNING TEST: {test_name}")
            print("----------------------------------------------------------------------")

            build_cmd = []
            build_cmd.append("qrun")
            build_cmd.append("-64")
            if contains_sv:
                build_cmd.append("-sv")
            build_cmd.append("-timescale=1ns/100ps")
            for (
                param,
                value,
            ) in test_case.items():
                build_cmd.append("-g")
                build_cmd.append(f"{param}={value}")
            for f in self.files:
                build_cmd.append(f)
            build_cmd.append("-top")
            build_cmd.append(self.config["top"])
            ret = subprocess.run(build_cmd, cwd=sim_dir).returncode

            if ret != 0:
                tests_failed += 1
                failed_tests.append(test_name)

        # Report test names and quantity of tests failed, if any
        # NOTE: This doesn't work in modelsim because the returncode doesn't capture
        # assertion failures.
        if tests_failed > 0:
            print("\n")
            print("----------------------------------------------------------------------")
            print(f"Tests failed: {tests_failed}")
            [print(t) for t in failed_tests]
            print("----------------------------------------------------------------------")
        # else:
        #    print(f"\nSUCCESS: All tests passed.")


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
