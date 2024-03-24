from openflex import main, config
import sys
import math
import random
import pathlib


def generate_count():
    count = random.randint(1e3, 1e7)

    params = []
    params.append(count)
    return list(set(params))


if __name__ == "__main__":

    dut = config.FlexConfig("./blinky_synth.yml")
    dut.add_parameter("COUNT", generate_count)

    mode = dut.config["mode"]
    tool = dut.config["tool"]

    clk_period = 2

    sample = None

    synth_csv = pathlib.Path("blinky.csv")

    # TODO: replace the rest of this code with
    # an integrated "dut.run()" or similar

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
            dut.vivado_synth(synth_csv)
        elif tool == "quartus":
            dut.quartus_synth(synth_csv)
        else:
            sys.exit("ERROR: Invalid synthesis tool.")
    else:
        sys.exit("ERROR: Invalid mode.")
