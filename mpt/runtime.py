# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import locale
import os
import re
import shutil
from pathlib import Path
from rich.prompt import Confirm, IntPrompt

from mpt import root_dir
from mpt.archive import ArchiveHandler
from mpt.config import RequirementsConfig
from mpt.download import DownloadHandler
from mpt.log import RichLogger
from mpt.patch import PatchHandler
from mpt.run import Runner


class RuntimeManager:
    _restart_pending = False

    @classmethod
    def _process(cls, config):
        name = config.get('name', '')
        url = config.get('url', '')
        sha256 = config.get('sha256', '')
        target = config.get('target', '')
        exclude = config.get('exclude', [])
        include = config.get('include', [])
        install = config.get('install', '')
        download_dir = root_dir / 'buildtrees' / 'downloads'
        download_dir.mkdir(parents=True, exist_ok=True)
        download_path = download_dir / Path(url).name
        if download_path.exists():
            if not (sha256 and ArchiveHandler.verify_hash(download_path, sha256)):
                download_path.unlink(missing_ok=True)
                if not DownloadHandler.download_file(url, download_path, verify_ssl=False):
                    return False
        else:
            if not DownloadHandler.download_file(url, download_path, verify_ssl=False):
                return False
            if not (sha256 and ArchiveHandler.verify_hash(download_path, sha256)):
                return False
        if target:
            expanded_target = Runner._expand_envvars(target)
            target_path = Path(expanded_target)
            if download_path.suffix.lower() in ['.exe', '.msi']:
                # Copy regular file to target location
                if target_path.is_dir():
                    # Target is a directory, copy file to it
                    target_path.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(download_path, target_path)
                    RichLogger.debug(f"Copied [bold cyan]{download_path.name}[/bold cyan] to [bold cyan]{target_path}[/bold cyan]")
                else:
                    # Target is a file, create parent directory and copy
                    target_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(download_path, target_path)
                    RichLogger.debug(f"Copied [bold cyan]{download_path.name}[/bold cyan] to [bold cyan]{target_path}[/bold cyan]")
            elif not ArchiveHandler.extract(
                archive_path=download_path,
                target_dir=target_path,
                exclude=exclude,
                include=include,
                remove_archive=False
            ):
                return False
            # patch
            patch = config.get('patch')
            if patch:
                patch_files = []
                for file_name in patch:
                    patch_file = root_dir / 'mpt' / 'resources' / file_name
                    if not patch_file.exists():
                        return False
                    patch_files.append(patch_file.resolve())
                if not PatchHandler.apply_patches(source_dir=target_path, patch_files=patch_files):
                    return False
        elif install:
            RichLogger.debug(f"Installing [bold red]'{name}'[/bold red]")
            if not Runner.silent_run(install, download_path.parent):
                RichLogger.error(f"Failed to install [bold red]'{name}'[/bold red]")
                return False
        requires_restart = config.get('restart', False)
        if requires_restart:
            cls._restart_pending = True
        return True


    @classmethod
    def _process_variants(cls, dep_name, variants):
        RichLogger.info(f"Dependency [bold cyan]{dep_name}[/bold cyan] has {len(variants)} variants:")
        for i, variant in enumerate(variants, 1):
            RichLogger.info(f"{i}. {variant.get('name', f'Variant {i}')}")
        RichLogger.info(f"{len(variants) + 1}. Skip installation")
        choice = IntPrompt.ask(
            f"Select a variant to install (1-{len(variants) + 1})",
            choices=[str(i) for i in range(1, len(variants) + 2)],
            default=str(len(variants) + 1)
        )
        if choice == len(variants) + 1:
            RichLogger.info(f"Skipped installation of [bold cyan]{dep_name}[/bold cyan]")
            return True
        selected_variant = variants[choice - 1]
        variant_name = selected_variant.get('name', f'Variant {choice}')
        return cls._process(selected_variant)


    @classmethod
    def _process_components(cls, config):
        components = config.get('components', [])
        if components:
            for component in components:
                name = component.get('name', '')
                check_cmd = component.get('check', '')
                if check_cmd:
                    if not Runner.silent_run(check_cmd):
                        if not cls._process(component):
                            RichLogger.error(f"Failed to install [bold red]'{name}'[/bold red]")
                            return False
        return True


    @classmethod
    def validate(cls):
        requirements = RequirementsConfig.load()
        if not requirements:
            return False
        for config in requirements:
            dep_name = config.get('name', 'Unknown')
            check_cmd = config.get('check', '')
            if check_cmd:
                if not Runner.silent_run(check_cmd):
                    variants = config.get('variants', [])
                    if variants:
                        if not cls._process_variants(dep_name, variants):
                            RichLogger.error(f"Failed to install [bold red]'{dep_name}'[/bold red]")
                            return False
                    else:
                        if not cls._process(config):
                            RichLogger.error(f"Failed to install [bold red]'{dep_name}'[/bold red]")
                            return False
            else:
                if not cls._process_components(config):
                    return False
        if cls._restart_pending:
            RichLogger.warning("System restart is required to complete installation")
            RichLogger.print("\n[bold yellow]System Restart Required[/bold yellow]")
            RichLogger.print("Some dependencies require a system restart to function properly")
            if Confirm.ask("Do you want to restart now?", default=True):
                RichLogger.info("Initiating system restart...")
                os.system("shutdown /r /t 0")
            else:
                RichLogger.warning("Please restart your computer when convenient")
                return False
        return True
