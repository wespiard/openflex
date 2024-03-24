
# OpenFLEX

[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
[![PyPI version](https://img.shields.io/pypi/v/openflex.svg)](https://pypi.python.org/pypi/openflex/)
[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/license/mit)

A python module/CLI **F**ramework for **L**ogic Synthesis and **EX**ploration

## Installation

The easiest way to install OpenFLEX is using `pip`. To install OpenFLEX in a Python virtual environment, you can run the following commands:

```bash
python -m venv .venv      # this will create a `.venv` directory in your current directory
source .venv/bin/activate # activate the virtual environment
pip install -U pip        # update the default pip version
pip install openflex      # install OpenFLEX and its dependencies inside venv
```

To de-activate the environment (if you need to delete it, or are switching to another one), simply run the following command:

```bash
deactivate
```

## Usage

The following usage instructions will use files from the `examples/` directory of this repository. Currently, there are two examples:

1) `examples/mult/` : simple combinational logic multiplier with a testbench
2) `examples/blinky/` : classic `blinky` counter/LED example without a testbench

Each example directory contains two types of files: (1) RTL modules and (2) YAML configuration files. The YAML configuration files are used to contain the details/parameters required to simulate or synthesize the RTL modules, e.g., file list, EDA tool, top-level module/testbench parameters, etc.

### Multiplier Simulation Example

Examine the `mult_sim.yml` YAML configuration file contents:

```yaml
mode: sim
tool: questa
top: mult_tb

files:
  - ./mult.sv
  - ./mult_tb.sv

parameters:
  NUM_TESTS: [1000]
  IS_SIGNED: [0, 1]
  INPUT_WIDTH: [8, 16]
```

With this configuration, OpenFLEX will run the `mult_tb` testbench four times (Cartesian product of the `IS_SIGNED` and `INPUT_WIDTH` parameters).

To run a simulation using the `mult` example, make sure any relevant virtual environment is loaded, and run the following commands:

```bash
cd examples/mult
openflex mult_sim.yml
```

This will create a `build_questa` directory that contains the build artifacts, logs, etc.

### Blinky Synthesis Example

To run synthesis/PnR/STA on the blinky module, similarly, you can run the following:

```bash
cd examples/blinky
openflex blinky_synth.yml -c blinky.csv
```

Notice the `-c blinky.csv` argument passed. This specifies the name for the CSV file that the results are output to (fMax, resource utilization, etc.). Note that the CSV file is appended to, not overwritten.

### Custom Flexible Parameter Generation

You are not limited to the rigid parameter combinations that you supply via the YAML configuration. It is also possible to utilize the `FlexConfig()` class from your own custom Python scripts to utilize the power of Python to generate some extremely precise parameter combinations that would be tedious to do manually or through basic filelists/configurations.

An example of this is provided in the blinky example directory: [`blinky.py`](examples/blinky/blinky.py)

The `FlexConfig()` class has an `add_parameter()` method that allows a custom function to be passed which is used to insert new parameters into the parameter list.

For example, in [`blinky.py`](examples/blinky/blinky.py), we create a `generate_count()` function that simply picks a random value between 1k and 100k. This is a trivial use-case, of course.

```python
def generate_count():
    count = random.randint(1e3, 1e7)

    params = []
    params.append(count)
    return list(set(params))
```

Later, we instantiate an instance of `FlexConfig()` by passing the YAML configuration, and call the `add_parameter()` method to add the random `count` parameter value. We could also add more random (or specific) `count` values and add them to the return of this `generate_count()` function:

```python
dut = config.FlexConfig("./blinky_synth.yml")
dut.add_parameter("COUNT", generate_count)
```

Additionally, it is possible to **read** existing parameters inside these `generate()` functions to use them as variables when calculating new pararmeters to prevent "illegal" combinations.

## Contributing

If you would like to make live modifications to the OpenFLEX source code, then you will need to clone this repository and install it in [`editable`](https://setuptools.pypa.io/en/latest/userguide/development_mode.html) mode.

Start by cloning the repository, and then from its root directory, run the following:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -e .  # install OpenFLEX locally as editable
```

Now, any modifications you make to the OpenFLEX source code should be reflected the next time you run or use `openflex`.
