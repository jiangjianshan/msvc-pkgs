# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import yaml

from mpt.log import RichLogger


class YamlUtils:
    @staticmethod
    def load(file_path):
        if not file_path.exists():
            RichLogger.error(f"YAML file not found: [bold red]{file_path}[/bold red]")
            return None
        if not file_path.is_file():
            RichLogger.error(f"YAML file path is not a file: [bold red]{file_path}[/bold red]")
            return None
        with open(file_path, 'r', encoding='utf-8') as f:
            yaml_data = yaml.safe_load(f) or {}
            return yaml_data


    @staticmethod
    def dump(file_path, data, sort_keys = False):
        file_path.parent.mkdir(parents=True, exist_ok=True)
        class YamlDumper(yaml.SafeDumper):
            def increase_indent(self, flow=False, indentless=False):
                # Override to ensure proper indentation for nested structures
                return super().increase_indent(flow, False)
        with open(file_path, 'w', encoding='utf-8') as f:
            # Use custom dumper with appropriate settings
            yaml.dump(
                data,
                f,
                Dumper=YamlDumper,
                default_flow_style=False,
                sort_keys=sort_keys,
                indent=2
            )
        return True
