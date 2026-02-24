# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import yaml
from importlib import resources
from pathlib import Path
from typing import Dict, List, Optional, Any, Union

from mpt import root_dir
from mpt.log import RichLogger
from mpt.yaml import YamlUtils


class LibraryConfig:
    @staticmethod
    def load(lib):
        config_path = root_dir / 'ports' / lib / 'config.yaml'
        return YamlUtils.load(config_path)


    @staticmethod
    def dump(lib, config_data):
        config_path = root_dir / 'ports' / lib / 'config.yaml'
        return YamlUtils.dump(config_path, config_data)


class RequirementsConfig:
    @staticmethod
    def load():
        # Use resources.files() for better Python 3.9+ compatibility
        if hasattr(resources, 'files'):
            config_path = resources.files("mpt.resources") / "requirements.yaml"
            with resources.as_file(config_path) as path:
                config = YamlUtils.load(path)
        else:
            # Fallback for older Python versions
            with resources.path("mpt.resources", "requirements.yaml") as path:
                config = YamlUtils.load(path)
        if config:
            deps = config.get('dependencies', [])
            return deps
        RichLogger.warning("No dependencies found in requirements.yaml")
        return []
