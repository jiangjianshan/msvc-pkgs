# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
import re
import shutil

from pathlib import Path

from mpt import root_dir
from mpt.archive import ArchiveHandler
from mpt.clean import CleanManager
from mpt.download import DownloadHandler
from mpt.file import FileUtils
from mpt.git import GitHandler
from mpt.log import RichLogger
from mpt.patch import PatchHandler
from mpt.run import Runner


class SourceManager:
    @staticmethod
    def fetch(config):
        source_dir = SourceManager._process(config)
        if not source_dir:
            RichLogger.error(f"Source fetch failed for [bold cyan]{config['name']}[/bold cyan]")
            return None
        components = config.get('components', [])
        if components:
            for component in components:
                component_path = SourceManager._process(component, base_dir=source_dir)
                if not component_path:
                    RichLogger.warning(f"Failed to process component: [bold cyan]{component.get('name', '')}[/bold cyan]")
        return source_dir


    @staticmethod
    def _process(config, base_dir = None):
        url = config.get('url', '')
        name = config.get('name', '')
        version = config.get('version', '')
        sha256 = config.get('sha256')
        target = config.get('target')

        # Check for extra source check command
        force_extract = False
        # Determine target directory
        if base_dir and target:
            target_dir = base_dir / target
            # NOTE: Only root source need to set patch directory but not components
            patch_dir = None
            if 'check' in config:
                check_command = config.get('check', '')
                if not Runner.silent_run(check_command, base_dir):
                    force_extract = True
        else:
            patch_dir = root_dir / 'ports' / f"{name}"
            if url.endswith('.git'):
                target_dir = root_dir / 'buildtrees' / 'sources' / f"{name}"
            else:
                target_dir = root_dir / 'buildtrees' / 'sources' / f"{name}-{version}"
            lib_dir = root_dir / 'ports' / f"{name}"
            # Check if any .diff file in port directory is newer than main source directory
            if target_dir.exists() and lib_dir.exists():
                # Get the latest modification time of source directory
                target_mtime = target_dir.stat().st_mtime
                # Check all .diff files in port directory
                for diff_file in lib_dir.glob('*.diff'):
                    if diff_file.is_file() and diff_file.stat().st_mtime > target_mtime:
                        RichLogger.info(f"[[bold cyan]{name}[/bold cyan]] {diff_file.name} is newer than source")
                        CleanManager.clean_source(name)
        if target_dir.exists():
            return SourceManager._handle_existing_source(config, target_dir, patch_dir, force_extract)
        else:
            return SourceManager._fetch_new_source(config, target_dir, patch_dir, force_extract)


    @staticmethod
    def _handle_existing_source(config, source_dir, patch_dir, force_extract):
        url = config.get('url', '')
        if url.endswith('.git'):
            return SourceManager._update_git_repository(config, source_dir)
        else:
            return SourceManager._process_archive_source(config, source_dir, patch_dir, force_extract)


    @staticmethod
    def _fetch_new_source(config, source_dir, patch_dir, force_extract):
        url = config.get('url', '')
        if url.endswith('.git'):
            RichLogger.debug(f"Cloning Git repository: [bold cyan]{config['url']}[/bold cyan]")
            success = GitHandler.clone_repository(config, source_dir)
            if not success:
                RichLogger.error(f"Failed to clone repository: [bold cyan]{config['url']}[/bold cyan]")
                return None
            return source_dir
        else:
            return SourceManager._process_archive_source(config, source_dir, patch_dir, force_extract)


    @staticmethod
    def _process_archive_source(config, source_dir, patch_dir, force_extract):
        archive_path = SourceManager._ensure_archive_exists(config)
        if not archive_path:
            RichLogger.error(f"Archive not available for [bold cyan]{config['name']}[/bold cyan]")
            return None
        if not source_dir.exists():
            source_dir.mkdir(parents=True, exist_ok=True)
        if force_extract or not any(source_dir.iterdir()):
            exclude = config.get('exclude', [])
            include = config.get('include', '')
            if not ArchiveHandler.extract(
                archive_path=archive_path,
                target_dir=source_dir,
                exclude=exclude,
                include=include,
                remove_archive=False
            ):
                RichLogger.error(f"Archive extraction failed: [bold cyan]{archive_path}[/bold cyan]")
                return None
            if patch_dir:
                if not PatchHandler.apply_patches(source_dir, patch_dir=patch_dir):
                    RichLogger.error(f"Patch application failed for [bold cyan]{config['name']}[/bold cyan]")
                    return None
        return source_dir


    @staticmethod
    def _ensure_archive_exists(config):
        url = config['url']
        archive_filename = SourceManager._get_archive_filename(url, config)
        archive_path = root_dir / 'buildtrees' / 'downloads' / archive_filename
        # Case 1: File exists and no hash verification needed
        if archive_path.exists() and 'sha256' not in config:
            RichLogger.info(f"Using existing archive: [bold cyan]{archive_filename}[/bold cyan]")
            return archive_path
        # Case 2: File exists but verification required
        if archive_path.exists() and 'sha256' in config:
            expected_hash = config['sha256']
            # Perform single verification
            if ArchiveHandler.verify_hash(archive_path, expected_hash):
                return archive_path
            else:
                RichLogger.warning(f"Archive verification failed - removing invalid file: [bold cyan]{archive_filename}[/bold cyan]")
                FileUtils.delete_file(archive_path)
        # Case 3: File doesn't exist, need to download
        if not DownloadHandler.download_file(url, archive_path):
            RichLogger.error(f"Archive download failed: [bold cyan]{archive_filename}[/bold cyan]")
            return None
        # Case 4: Verification needed after download
        if 'sha256' in config:
            expected_hash = config['sha256']
            if not ArchiveHandler.verify_hash(archive_path, expected_hash):
                RichLogger.error(f"Downloaded archive failed verification: [bold cyan]{archive_filename}[/bold cyan]")
                FileUtils.delete_file(archive_path)
                return None
        return archive_path


    @staticmethod
    def _update_git_repository(config, source_dir):
        RichLogger.info(f"Updating Git repository: [bold cyan]{config['name']}[/bold cyan]")
        updated = GitHandler.update_repository(source_dir, config)
        if not updated:
            RichLogger.warning(f"Update failed - attempting repair: [bold cyan]{source_dir}[/bold cyan]")
            if GitHandler.repair_repository(source_dir, config):
                RichLogger.info(f"Repository repaired after update failure: [bold cyan]{source_dir}[/bold cyan]")
                return source_dir
            return None
        return source_dir


    @staticmethod
    def _get_archive_filename(url, config):
        base_name = f"{config['name']}-{config['version']}"
        extension = FileUtils.extract_file_extension(url)
        filename = f"{base_name}.{extension}"
        return filename
