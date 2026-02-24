# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

import os
import sys

from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from rich import box
from rich.align import Align
from rich.console import Group
from rich.padding import Padding
from rich.panel import Panel
from rich.prompt import Prompt
from rich.table import Table
from rich.text import Text
from textwrap import shorten

from mpt import root_dir
from mpt.build import BuildManager
from mpt.clean import CleanManager
from mpt.config import LibraryConfig
from mpt.dependency import DependencyResolver
from mpt.git import GitHandler
from mpt.history import HistoryManager
from mpt.library import LibraryManager
from mpt.log import RichLogger
from mpt.source import SourceManager
from mpt.view import RichTable, RichPanel


class ActionHandler:
    def __init__(self, arch, libraries):
        self.arch = arch
        triplet = BuildManager.get_triplet(arch)
        self.triplet = triplet
        self.libraries = libraries
        self.terminal_width = RichLogger.get_console_width()

    def _status_icon(self, success: bool):
        return "[bold green]✓[/bold green]" if success else "[bold red]✗[/bold red]"

    def _shorten_path(self, path, max_len):
        return shorten(path, width=max_len, placeholder="...") if path != "N/A" else path

    def _create_summary_table(self):
        return RichTable.create()

    def _render_summary_panel(self, title, table, stats_text,
                             extra_content = None):
        content = stats_text
        if extra_content:
            content = Group(stats_text, Padding(extra_content, (1, 0)))
        RichPanel.summary(
            content=content,
            title=f"[bold]{title}[/bold]",
            table=table,
            width=self.terminal_width,
            title_align="center"
        )

    def _get_stats_text(self, total, success, action):
        return Text.from_markup(
            f"📋 Total Libraries: [bold yellow]{total}[/bold yellow]"
            f" | ✅ {action}: [bold green]{success}[/bold green]"
            f" | ❌ Failed: [bold red]{total - success}[/bold red]",
            justify="center"
        )

    def clean(self):
        """
        Clean build artifacts for specified libraries with detailed summary.
        """
        clean_options = [
            "1. Delete only log files for libraries (Uninstall action need and recommend to keep it)",
            "2. Delete only compressed libraries (only for non-Git sources)",
            "3. Delete only source directories (cloned or extracted)",
            "4. Delete all: logs, compressed libraries, and source directories"
        ]
        choice_panel = Panel(
            "\n".join(clean_options),
            title="🧹 Cleaning Options",
            border_style="blue",
            width=self.terminal_width
        )
        RichLogger.print(choice_panel)
        choice = Prompt.ask(
            "Please select an option (1-4)",
            choices=["1", "2", "3", "4"],
            default="4"
        )
        for lib in self.libraries:
            if choice == "1":
                CleanManager.clean_logs(self.triplet, lib)
            elif choice == "2":
                CleanManager.clean_archives(lib)
            elif choice == "3":
                CleanManager.clean_source(lib)
            else:
                CleanManager.clean_library(self.triplet, lib)


    def install(self):
        install_table = RichTable.create()
        RichTable.add_column(install_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(install_table, "📦 Status", style="green", header_style="bold green", justify="center")
        overall_success = True
        success_count = 0
        for lib in self.libraries:
            if not DependencyResolver.resolve(self.arch, lib, build=True):
                status = "[bold red]Failed[/bold red]"
                overall_success = False
            else:
                status = "[bold green]Installed[/bold green]"
                success_count += 1
            RichTable.add_row(install_table,
                f"[cyan]{lib}[/cyan]",
                status
            )
        stats_text = self._get_stats_text(len(self.libraries), success_count, "Installed")
        self._render_summary_panel("📦 Installation Summary", install_table, stats_text)


    def uninstall(self):
        for lib in self.libraries:
            CleanManager.clean_package(self.triplet, lib)


    def list(self):
        arch_records = HistoryManager.get_records(self.triplet)
        list_table = RichTable.create()
        RichTable.add_column(list_table, "📁 Library", style="cyan", header_style="bold cyan", justify="left")
        RichTable.add_column(list_table, "📝 Status", style="green", header_style="bold green", justify="center")
        RichTable.add_column(list_table, "📦 Version", style="yellow", header_style="bold yellow", justify="center", no_wrap=False)
        RichTable.add_column(list_table, "🕒 Last Built", style="magenta", header_style="bold magenta", justify="center", no_wrap=False)
        installed_count = 0
        not_installed_count = 0
        update_available_count = 0
        ignore_count = 0
        for lib in self.libraries:
            config = LibraryConfig.load(lib)

            if not config.get('script'):
                ignore_count += 1
                RichTable.add_row(list_table,
                    f"[bold cyan]{lib}[/bold cyan]",
                    "[bold blue]Ignore[/bold blue]",
                    f"[bold yellow]{config.get('version', 'unknown')}[/bold yellow]",
                    "N/A"
                )
                continue
            installed = lib in arch_records
            status_display = "[bold yellow]Error[/bold yellow]"
            version = "N/A"
            last_built = "N/A"
            if not installed:
                not_installed_count += 1
                status_display = "[bold red]Not Installed[/bold red]"
                version = f"[bold yellow]{config.get('version', 'unknown')}[/bold yellow]"
            else:
                installed_count += 1
                lib_info = arch_records[lib]

                time_val = lib_info.get('built')
                if isinstance(time_val, datetime):
                    built_time = time_val
                elif isinstance(time_val, str):
                    try:
                        built_time = datetime.fromisoformat(time_val)
                    except ValueError:
                        built_time = None
                else:
                    built_time = None

                lib_ver = lib_info.get('version')
                lib_built = built_time

                current_version = config.get('version', 'unknown')
                if current_version != lib_ver:
                    update_available_count += 1
                    status_display = "[bold yellow]Update Available[/bold yellow]"
                else:
                    status_display = "[bold green]Installed[/bold green]"

                if lib_ver is not None:
                    version = f"[bold yellow]{lib_ver}[/bold yellow]"
                else:
                    version = "[bold yellow]N/A[/bold yellow]"

                if lib_built:
                    last_built = lib_built.strftime("%Y-%m-%d %H:%M")
                else:
                    last_built = "[bold yellow]Unknown[/bold yellow]"
            RichTable.add_row(list_table,
                f"[bold cyan]{lib}[/bold cyan]",
                status_display,
                version,
                last_built
            )
        stats_text = Text.from_markup(
            f"📋 Total Libraries: [bold yellow]{len(self.libraries)}[/bold yellow] | "
            f"✅ Installed: [bold green]{installed_count}[/bold green] | "
            f"🔄 Update Available: [bold yellow]{update_available_count}[/bold yellow] | "
            f"❌ Not Installed: [bold red]{not_installed_count}[/bold red] | "
            f"🙈 Ignores: [bold blue]{ignore_count}[/bold blue]",
            justify="center"
        )
        self._render_summary_panel("📊 Library Status Summary", list_table, stats_text)
        if installed_count == 0:
            tip_text = Text.from_markup("💡 Use `mpt --install <library>` to install libraries.")
            RichPanel.summary(
                content=tip_text,
                title="Tip",
                border_style="blue",
                width=self.terminal_width
            )
        return True


    def dependency(self):
        for lib in self.libraries:
            DependencyResolver.resolve(self.triplet, lib, build=False)


    def fetch(self):
        for lib in self.libraries:
            config = LibraryConfig.load(lib)
            if not config:
                RichLogger.error(f"Failed to load config for library [cyan]{lib}[/cyan]")
                continue
            SourceManager.fetch(config)


    def add(self):
        for lib in self.libraries:
            lib_dir = root_dir / 'ports' / lib
            if lib_dir.exists() and (lib_dir / "config.yaml").exists():
                RichLogger.warning(f"Library [cyan]{lib}[/cyan] already exists. Skipping creation.")
                continue
            LibraryManager.add_library(lib)


    def remove(self):
        for lib in self.libraries:
            LibraryManager.remove_library(lib)
