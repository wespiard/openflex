import yaml


class Config:
    """Contains the configuration data supplied by a YAML file."""

    def __init__(self, config_file) -> None:
        config = yaml.load(config_file, Loader=yaml.loader.BaseLoader)


def main():
    print("Hello")


if __name__ == "__main__":
    main()
