# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import argparse
import re
import sys
from typing import Dict, List, Tuple

from rich.text import Text
from rich.table import Table
from rich import box

from mpt import root_dir
from mpt.config import LibraryConfig
from mpt.help import CommandLineHelp
from mpt.log import RichLogger
from mpt.view import RichPanel


class CommandLineParser:

    @staticmethod
    def parse_arguments():
        parser = CommandLineParser._create_parser()
        args, unknown_args = parser.parse_known_args()
        if args.help:
            CommandLineHelp.display_help()
            sys.exit(0)
        action = CommandLineParser._determine_action(args)
        # Skip library validation for 'add' action
        if action == 'add' or action == 'remove':
            libraries = args.libraries
        else:
            libraries = CommandLineParser._validate_libraries(args.libraries)
        return args.arch, action, libraries


    @staticmethod
    def _create_parser():
        parser = argparse.ArgumentParser(
            prog='mpt',
            description="msforge package tool",
            formatter_class=argparse.RawTextHelpFormatter,
            add_help=False,
            epilog="Default behavior: Install all libraries for x64 architecture"
        )
        action_group = parser.add_mutually_exclusive_group(required=False)
        actions = [
            ('--install', 'Install specified libraries or all libraries if none specified'),
            ('--uninstall', 'Uninstall specified libraries or all libraries if none specified'),
            ('--list', 'List installation status of specified libraries or all libraries if none specified'),
            ('--dependency', 'Show dependency tree for specified libraries or all libraries if none specified'),
            ('--fetch', 'Fetch source code for specified libraries or all libraries if none specified'),
            ('--clean', 'Clean build artifacts for specified libraries or all libraries if none specified'),
            ('--add', 'Add and configure a new library with automatic build system detection'),
            ('--remove', 'Remove library configuration files')
        ]
        for arg, help_text in actions:
            action_group.add_argument(arg, action='store_true', help=help_text)
        parser.add_argument(
            '--arch',
            default='x64',
            help="Specify target architecture (default: x64)\n"
                 "Valid values: x86, amd64, x86_amd64, x86_arm, x86_arm64,\n"
                 "              amd64_x86, amd64_arm, amd64_arm64"
        )
        parser.add_argument(
            '-h', '--help',
            action='store_true',
            help="Show this help message and exit"
        )
        parser.add_argument(
            'libraries',
            nargs='*',
            default=[],
            help="List of libraries to process (optional)"
        )
        return parser


    @staticmethod
    def _determine_action(args):
        action_mapping = {
            'install': args.install,
            'uninstall': args.uninstall,
            'list': args.list,
            'dependency': args.dependency,
            'fetch': args.fetch,
            'clean': args.clean,
            'add': args.add,
            'remove': args.remove
        }
        for action, flag in action_mapping.items():
            if flag:
                return action
        return 'install'


    @staticmethod
    def _validate_libraries(requested_libs):
        ports_dir = root_dir / 'ports'
        all_libs = [d.name for d in ports_dir.iterdir()
            if d.is_dir() and (d / "config.yaml").exists()]
        libraries = requested_libs or all_libs
        if not libraries:
            return all_libs
        # Case-insensitive validation
        lib_lower_map = {lib.lower(): lib for lib in all_libs}
        validated_libs = []
        invalid_libs = []
        for lib in libraries:
            if (original_case := lib_lower_map.get(lib.lower())):
                validated_libs.append(original_case)
            else:
                invalid_libs.append(lib)
        if invalid_libs:
            content = Text()
            content.append("Invalid libraries:\n", style="red")
            content.append("   " + " ".join(invalid_libs), style="bold red")
            content.append("\n\nAvailable libraries:\n", style="bold green")
            for i in range(0, len(all_libs), 8):
                content.append("   " + " ".join(all_libs[i:i+8]) + "\n", style="cyan")
            RichPanel.summary(content=content, title="Library Summary")
            sys.exit(1)
        return validated_libs
