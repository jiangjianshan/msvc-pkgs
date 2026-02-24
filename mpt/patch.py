# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
from pathlib import Path
from typing import List, Optional
from rich.text import Text

from mpt import root_dir
from mpt.log import RichLogger
from mpt.run import Runner
from mpt.view import RichPanel


class PatchHandler:
    @classmethod
    def apply_patches(cls, source_dir, patch_dir=None, patch_files=None):
        # Validate source directory exists
        if not source_dir.exists():
            RichLogger.error(f"Source directory not found: [bold red]{source_dir}[/bold red]")
            return False
        # Determine patch files to apply based on provided parameters
        patches = []
        if patch_files:
            patches = [p for p in patch_files if p.exists()]
        elif patch_dir and patch_dir.exists():
            patches = sorted(patch_dir.glob('*.diff'))
        if not patches:
            return True
        patch_status = True
        successful_patches = 0
        for idx, patch in enumerate(patches, start=1):
            RichLogger.info(f"Applying patch ([bold cyan]{idx}[/bold cyan]/[bold cyan]{len(patches)}[/bold cyan]): [bold cyan]{patch.name}[/bold cyan]")
            if Runner.execute(f"patch -Np1 -i \"{patch}\"", source_dir):
                RichLogger.debug(f"Successfully applied patch: [bold cyan]{patch.name}[/bold cyan]")
                successful_patches += 1
            else:
                RichLogger.error(f"Patch application failed: [bold red]{patch.name}[/bold red]")
                patch_status = False
        cls._show_patch_summary(len(patches), successful_patches)
        return patch_status


    @classmethod
    def _show_patch_summary(cls, total, successful):
        failed = total - successful
        summary_text = Text.from_markup(
            f"Total Patches: [bold yellow]{total}[/bold yellow]"
            f" | Applied: [bold green]{successful}[/bold green]"
            f" | Failed: [bold red]{failed}[/bold red]",
            justify="center"
        )
        RichPanel.summary(
            content=summary_text,
            title="Patch Application Summary"
        )
