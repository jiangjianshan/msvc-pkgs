# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os

from pathlib import Path

from mpt import root_dir
from mpt.file import FileUtils
from mpt.log import RichLogger
from mpt.run import Runner

class ArchiveHandler:
    @classmethod
    def verify_hash(cls, file_path, expected_hash):
        if not expected_hash:
            return True
        if not file_path.exists():
            RichLogger.error(f"File not found: {file_path}")
            return False
        actual_hash = FileUtils.calc_hash(file_path)
        if actual_hash == expected_hash:
            return True
        else:
            RichLogger.error(f"Hash mismatch for file: {file_path}")
            RichLogger.error(f"Expected: {expected_hash}")
            RichLogger.error(f"Actual: {actual_hash}")
            return False


    @classmethod
    def extract(cls, archive_path, target_dir, exclude=None, include=None, remove_archive=False):
        if not archive_path.exists():
            RichLogger.error(f"Archive not found: {archive_path}")
            return False
        if not target_dir.exists():
            target_dir.mkdir(parents=True, exist_ok=True)
        success = False
        script_file = root_dir / 'wrappers' / 'extract'
        if exclude:
            if Runner.run_script(script_file, args=[f"{archive_path}", f"{target_dir}", f"", f"\'{exclude}\'"]):
                success = True
        elif include:
            if Runner.run_script(script_file, args=[f"{archive_path}", f"{target_dir}", f"\'{include}\'"]):
                success = True
        elif Runner.run_script(script_file, args=[f"{archive_path}", f"{target_dir}"]):
            success = True
        if success:
            RichLogger.debug(f"Extracted: [bold cyan]{archive_path}[/bold cyan] -> [bold cyan]{target_dir}[/bold cyan]")
            if remove_archive:
                FileUtils.delete_file(archive_path)
        return success
