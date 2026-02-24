# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#

import ctypes
import sys

from typing import NoReturn
from yaml import SafeDumper

from mpt.action import ActionHandler
from mpt.cli import CommandLineParser
from mpt.log import RichLogger
from mpt.runtime import RuntimeManager


def main():
    ctypes.windll.kernel32.SetConsoleOutputCP(65001)
    RichLogger.initialize()
    SafeDumper.add_representer(
        type(None),
        lambda dumper, value: dumper.represent_scalar('tag:yaml.org,2002:null', '')
    )
    if not RuntimeManager.validate():
        RichLogger.critical("System dependency check failed. Application cannot continue.")
        sys.exit(1)
    arch, action, libraries = CommandLineParser.parse_arguments()
    handler = ActionHandler(arch, libraries)
    action_mapping = {
        'install': handler.install,
        'uninstall': handler.uninstall,
        'list': handler.list,
        'dependency': handler.dependency,
        'fetch': handler.fetch,
        'clean': handler.clean,
        'add': handler.add,
        'remove': handler.remove
    }
    if action not in action_mapping:
        RichLogger.error(f"Unsupported action: {action}")
        sys.exit(1)
    action_mapping[action]()


if __name__ == "__main__":
    main()
