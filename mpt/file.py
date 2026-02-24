# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#
import hashlib
import os
import re

from pathlib import Path

from mpt.log import RichLogger
from mpt.run import Runner


class FileUtils:
    @classmethod
    def delete_file(cls, file_path):
        if file_path.exists():
            if Runner.execute(["rm", "-f", f"{file_path}"]):
                RichLogger.debug(f"Removed: [bold green]{file_path}[/bold green]")
            else:
                RichLogger.error(f"Failed to delete file: [bold red]{file_path}[/bold red]")


    @classmethod
    def delete_directory(cls, directory):
        if directory.exists():
            if Runner.execute(["rm", "-rf", f"{directory}"]):
                RichLogger.debug(f"Removed: [bold green]{directory}[/bold green]")
            else:
                RichLogger.error(f"Failed to delete file: [bold red]{directory}[/bold red]")


    @classmethod
    def extract_file_extension(cls, filename_or_url):
        basename = cls._extract_basename(filename_or_url)
        pattern = r'\.([a-z][a-z0-9]{1,4}(?:\.[a-z][a-z0-9]{1,4}){0,1})$'
        match = re.search(pattern, basename, re.IGNORECASE)
        if match:
            return match.group(1)
        return ""


    @classmethod
    def _extract_basename(cls, path_or_url):
        without_params = path_or_url.split('?')[0].split('#')[0]
        return Path(without_params).name


    @classmethod
    def calc_hash(cls, file_path, algorithm = "sha256"):
        try:
            hash_func = getattr(hashlib, algorithm)()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_func.update(chunk)
            return hash_func.hexdigest()
        except (IOError, AttributeError, ValueError):
            return None
