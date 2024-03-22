
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
