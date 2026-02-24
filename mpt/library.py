# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#
import requests

from pathlib import Path
from rich.prompt import Prompt, Confirm, IntPrompt
from typing import Dict, List, Optional, Union
from urllib.parse import urljoin

from mpt import root_dir
from mpt.config import LibraryConfig
from mpt.file import FileUtils
from mpt.log import RichLogger
from mpt.source import SourceManager


class LibraryManager:

    @staticmethod
    def add_library(lib):
        lib_dir = root_dir / 'ports' / lib
        lib_dir.mkdir(parents=True, exist_ok=True)
        config: Dict[str, Union[str, bool, int, Dict, List]] = {
            "name": lib
        }
        config['version'] = Prompt.ask("Enter library version", default="1.0.0")
        config['url'] = Prompt.ask("Enter source URL (for download/clone)")
        source_path = LibraryManager._process_source_config(config, lib)
        LibraryManager._process_extras(config)
        LibraryManager._process_dependencies(config)
        LibraryManager._process_script(config, source_path)
        if not LibraryConfig.dump(lib, config):
            RichLogger.error(f"Failed to save configuration for library [bold red]{lib}[/bold red]")
            return
        RichLogger.debug(f"[SUCCESS] Configuration created at {lib_dir / 'config.yaml'}")


    @staticmethod
    def remove_library(lib):
        lib_dir = root_dir / 'ports' / lib
        if not lib_dir.exists():
            RichLogger.error(f"Library [bold red]{lib}[/bold red] does not exist")
            return False
        if not Confirm.ask(f"Are you sure you want to remove library [bold red]{lib}[/bold red]?"):
            RichLogger.info(f"Library removal cancelled for [cyan]{lib}[/cyan]")
            return False
        FileUtils.delete_directory(lib_dir)
        return True


    @staticmethod
    def _collect_source_info(source_name):
        info = {
            "name": source_name,
            "version": Prompt.ask(f"Enter version for {source_name}", default="1.0.0"),
            "url": Prompt.ask(f"Enter URL for {source_name}")
        }
        return info


    @staticmethod
    def _get_gitmodules_url(git_url, branch = "master"):
        # Handle GitHub repositories
        if 'github.com' in git_url:
            # Convert https://github.com/owner/repo.git to
            # https://raw.githubusercontent.com/owner/repo/branch/.gitmodules
            repo_path = git_url.replace('https://github.com/', '').replace('.git', '')
            return f"https://raw.githubusercontent.com/{repo_path}/{branch}/.gitmodules"

        # Handle GitLab repositories
        elif 'gitlab.com' in git_url:
            # Convert https://gitlab.com/owner/repo.git to
            # https://gitlab.com/owner/repo/-/raw/branch/.gitmodules
            repo_path = git_url.replace('https://gitlab.com/', '').replace('.git', '')
            return f"https://gitlab.com/{repo_path}/-/raw/{branch}/.gitmodules"
        # For other Git repositories, try to construct a reasonable URL
        else:
            # Fallback: try to access .gitmodules directly from the repo
            return urljoin(git_url, '.gitmodules')


    @staticmethod
    def _process_git_source(source_config, source_name):
        source_path = None
        # Check if .gitmodules file exists
        has_gitmodules = False
        try:
            # Get branch from version field (user might enter 'master', 'main', etc.)
            branch = source_config.get('version', 'master')
            # Construct the correct .gitmodules URL
            gitmodules_url = LibraryManager._get_gitmodules_url(source_config["url"], branch)
            response = requests.get(gitmodules_url, timeout=10, verify=False)
            has_gitmodules = response.status_code == 200
        except requests.Timeout:
            RichLogger.warning(f"Timeout occurred while checking .gitmodules for {source_name}")
            # Use interactive prompt when timeout occurs
            has_gitmodules = Confirm.ask(
                f"Timeout occurred while checking .gitmodules for {source_name}. "
                f"Do you want to enable recursive clone?",
                default=False
            )
        except (requests.RequestException, Exception) as e:
            RichLogger.debug(f"Failed to check .gitmodules: {str(e)}")
            # Use interactive prompt when other errors occur
            has_gitmodules = Confirm.ask(
                f"Failed to check .gitmodules for {source_name}: {str(e)}. "
                f"Do you want to enable recursive clone?",
                default=False
            )
        # Automatically set recursive based on .gitmodules detection or user input
        source_config['recursive'] = has_gitmodules
        if has_gitmodules:
            RichLogger.info(f"Enabled recursive clone for {source_name}")
        else:
            RichLogger.info(f"Disabled recursive clone for {source_name}")
        source_config['depth'] = IntPrompt.ask(
            f"Set Git depth for {source_name}", default=1)
        # Process submodules for Git sources
        if source_config.get('recursive', False) and Confirm.ask(f"Configure submodules for {source_name}?"):
            source_config['submodules'] = {}
            while True:
                sub_name = Prompt.ask(f"Enter submodule name for {source_name} (leave blank to finish)")
                if not sub_name:
                    break
                source_config['submodules'][sub_name] = {
                    'url': Prompt.ask(f"Enter Git URL for {sub_name}"),
                    'branch': Prompt.ask(f"Enter branch for {sub_name}", default="main")
                }
        # For Git sources, fetch the source to clone the repository
        try:
            source_path = SourceManager.fetch(source_config)
            if source_path is not None:
                RichLogger.info(f"Successfully cloned Git repository for {source_name} to {source_path}")
            else:
                RichLogger.warning(f"Failed to clone Git repository for {source_name}")
        except Exception as e:
            RichLogger.warning(f"Error cloning Git repository for {source_name}: {str(e)}")

        return source_path


    @staticmethod
    def _process_archive_source(source_config, source_name):
        source_path = None
        # For non-Git sources, try to download and calculate SHA256
        try:
            # Download source file
            source_path = SourceManager.fetch(source_config)
            if source_path is not None:
                ext = FileUtils.extract_file_extension(source_config['url'])
                # Build download filename
                download_filename = f"{source_config['name']}-{source_config['version']}.{ext}"
                download_filepath = root_dir / 'buildtrees' / 'downloads' / download_filename
                # Calculate SHA256
                if download_filepath.exists():
                    sha256_value = FileUtils.calc_hash(download_filepath)
                    source_config['sha256'] = sha256_value
                    RichLogger.info(f"Automatically calculated SHA256 for {source_name}: {sha256_value}")
                else:
                    RichLogger.warning(f"Download file not found: {download_filepath}")
                    source_config['sha256'] = None
            else:
                RichLogger.warning(f"Failed to download source for {source_name}")
                source_config['sha256'] = None
        except Exception as e:
            RichLogger.warning(f"Error processing non-Git source for {source_name}: {str(e)}")
            # Fallback to manual input if automatic processing fails
            sha256_input = Prompt.ask(f"Enter SHA256 checksum for {source_name}", default="")
            if sha256_input.strip():
                source_config['sha256'] = sha256_input.strip()
            else:
                source_config['sha256'] = None

        return source_path

    @staticmethod
    def _process_source_config(source_config, source_name):
        # For Git sources, add Git-specific options
        url = source_config.get('url', '')
        if url.endswith('.git'):
            return LibraryManager._process_git_source(source_config, source_name)
        else:
            return LibraryManager._process_archive_source(source_config, source_name)


    @staticmethod
    def _process_extras(config: Dict):
        if Confirm.ask("Add extra resources?"):
            config['extras'] = []
            while True:
                extra_name = Prompt.ask("Enter extra resource name (leave blank to finish)")
                if not extra_name:
                    break
                # Collect common source information
                extra = LibraryManager._collect_source_info(extra_name)
                # Process common source configuration
                LibraryManager._process_source_config(extra, extra_name)
                # Add extra-specific fields
                extra['target'] = Prompt.ask(f"Enter target path for {extra_name}")
                # Only add check field if user provides input
                check_input = Prompt.ask(f"Enter existence check command for {extra_name}", default="")
                if check_input:
                    extra['check'] = check_input
                config['extras'].append(extra)


    @staticmethod
    def _process_dependencies(config: Dict):
        if Confirm.ask("Add dependencies?"):
            config['dependencies'] = {}
            # Required dependencies
            req_deps = Prompt.ask("Enter required dependencies (comma separated)", default="")
            if req_deps.strip():
                config['dependencies']['required'] = [d.strip() for d in req_deps.split(",") if d.strip()]
            # Optional dependencies
            opt_deps = Prompt.ask("Enter optional dependencies (comma separated)", default="")
            if opt_deps.strip():
                config['dependencies']['optional'] = [d.strip() for d in opt_deps.split(",") if d.strip()]
            if not config['dependencies'].get('required') and not config['dependencies'].get('optional'):
                config['dependencies'] = None
        else:
            config['dependencies'] = None


    @staticmethod
    def _process_script(config, source_path = None):
        # If source was successfully downloaded, auto-detect build system
        if source_path is not None and source_path.exists():
            RichLogger.info("Auto-detecting build system from downloaded source...")
            # Check for CMakeLists.txt
            cmake_lists = source_path / "CMakeLists.txt"
            if cmake_lists.exists():
                config['script'] = "build.bat"
                RichLogger.info("Detected CMake build system (CMakeLists.txt), using build.bat")
                return
            # Check for meson.build
            meson_build = source_path / "meson.build"
            if meson_build.exists():
                config['script'] = "build.bat"
                RichLogger.info("Detected Meson build system (meson.build), using build.bat")
                return
            # Check for configure.ac (autotools)
            configure_ac = source_path / "configure.ac"
            if configure_ac.exists():
                config['script'] = "build.sh"
                RichLogger.info("Detected Autotools build system (configure.ac), using build.sh")
                return
            # Check for other common build files as fallback
            makefile = source_path / "Makefile"
            configure_script = source_path / "configure"
            if makefile.exists() or configure_script.exists():
                config['script'] = "build.sh"
                RichLogger.info("Detected Makefile or configure script, using build.sh")
                return
            # If no build system detected, fall back to default
            RichLogger.warning("No standard build system detected in source root")
            config['script'] = "build.bat"
            RichLogger.info("Using default build.bat")
        else:
            # Fallback to manual selection if source download failed or unavailable
            RichLogger.warning("Source download failed or unavailable, using manual build script selection")
            # Present build script options
            RichLogger.info("\nSelect build script type:")
            RichLogger.info("1. No build script (empty)")
            RichLogger.info("2. Windows batch file (build.bat)")
            RichLogger.info("3. Unix shell script (build.sh)")
            choice = IntPrompt.ask("Enter your choice (1-3)", default=1, choices=["1", "2", "3"])
            if choice == 1:
                config['script'] = ""  # Empty script
            elif choice == 2:
                config['script'] = "build.bat"  # Windows batch file
            elif choice == 3:
                config['script'] = "build.sh"  # Unix shell script
            RichLogger.debug(f"Selected build script: {config['script']}")
