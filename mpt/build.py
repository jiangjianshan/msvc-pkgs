# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import glob
import os
import platform
import re

from pathlib import Path
from typing import Dict, Optional

from mpt import root_dir
from mpt.config import LibraryConfig
from mpt.dependency import DependencyResolver
from mpt.git import GitHandler
from mpt.history import HistoryManager
from mpt.log import RichLogger
from mpt.patch import PatchHandler
from mpt.run import Runner
from mpt.source import SourceManager


class BuildManager:
    _fail_libs = []

    @classmethod
    def get_triplet(cls, arch):
        arch_map = {
            'x86': 'i686',
            'x86_32': 'i686',
            'i386': 'i686',
            'i486': 'i686',
            'i585': 'i686',
            'i686': 'i686',
            'x64': 'x86_64',
            'x86_64': 'x86_64',
            'amd64': 'x86_64'
        }
        target_arch = arch_map.get(arch, 'x86_64')
        system = platform.system().lower()
        machine = platform.machine().lower()
        os_name = system
        vendor = "unknown"
        abi = "gnu"
        if system == "darwin":
            vendor = "apple"
        if system == "darwin":
            os_name = "darwin"
        elif system == "windows":
            os_name = "windows"
            vendor = "pc"
            abi = "msvc"
        elif system == "linux":
            os_name = "linux"
        elif system.startswith("cygwin"):
            os_name = "cygwin"
        elif system.startswith("msys"):
            os_name = "msys"
        return f"{target_arch}-{vendor}-{os_name}-{abi}"


    @classmethod
    def postaction(cls, node_name, triplet):
        lib, _ = DependencyResolver.parse_dependency_name(node_name)
        config = LibraryConfig.load(lib)
        lib = config.get('name')
        lib_ver = str(config.get('version'))
        prefix = root_dir / 'packages' / f"{lib}-{lib_ver}-{triplet}"
        # process .pc files
        pkgconfig_dir = prefix / 'lib' / 'pkgconfig'
        if not pkgconfig_dir.exists():
            pkgconfig_dir = prefix / 'share' / 'pkgconfig'
        if pkgconfig_dir.exists():
            pc_files = list(pkgconfig_dir.glob("*.pc"))
            sed_cmd = r'sed -e "s#\([A-Za-z]\):/\([^/]\)#/\L\1\E/\2#g" -e "s|[ ]*-L/[^ ]*||g" -e "s/[ ]*$//" -e "s| \([^ -][^ ]*/\)\{1,\}\([^/]*\)\.lib| -l\2|g" -i'
            if pc_files:
                for pc_file in pc_files:
                    file_name = os.path.basename(pc_file)
                    RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Processing [bold green]{file_name}[/bold green]")
                    full_cmd = f"{sed_cmd} {file_name}"
                    Runner.execute(full_cmd, pkgconfig_dir)
        # process .la files
        lib_dir = prefix / 'lib'
        if lib_dir.exists():
            la_files = list(lib_dir.glob("*.la"))
            sed_cmd = r'''sed -e "s|[ ]*-L/[^ ']*||g" -e "s|/[^ ']*/\(lib[^ ']*\.la\)|\1|g" -i'''
            if la_files:
                for la_file in la_files:
                    file_name = os.path.basename(la_file)
                    RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Processing [bold green]{file_name}[/bold green]")
                    full_cmd = f"{sed_cmd} {file_name}"
                    Runner.execute(full_cmd, lib_dir)


    @classmethod
    def build_library(cls, arch, node_name, config):
        if node_name in cls._fail_libs:
            RichLogger.warning(f"[[bold cyan]{node_name}[/bold cyan]] Build skipped - previous build failed")
            return False
        triplet = cls.get_triplet(arch)
        lib, dep_type = DependencyResolver.parse_dependency_name(node_name)
        source_path = SourceManager.fetch(config)
        if not source_path or not source_path.exists():
            RichLogger.critical(f"[[bold cyan]{node_name}[/bold cyan]] Source acquisition failed")
            return False
        if not BuildManager._should_build(triplet, node_name, config):
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build skipped - already up to date")
            return True
        log_dir = root_dir / 'buildtrees' / 'logs'
        log_dir.mkdir(parents=True, exist_ok=True)
        script_file = config.get('script')
        if script_file:
            log_file = log_dir / triplet / f"{lib}.log"
            script_path = root_dir / 'ports' / lib / script_file
            if not script_path.exists():
                RichLogger.error(f"Build script not found: [bold cyan]{script_path}[/bold cyan]")
                return False
            Runner.setup_environment(arch, node_name)
            success = Runner.run_script(script_path, log_file=log_file)
            if success:
                version = config.get('version', 'unknown')
                HistoryManager.add_record(triplet, node_name, version)
                RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build completed successfully")
                if node_name in cls._fail_libs:
                    cls._fail_libs.remove(node_name)
                if script_file.endswith('.bat'):
                    cls.postaction(node_name, triplet)
                return True
            else:
                HistoryManager.remove_record(triplet, node_name)
                RichLogger.error(f"[[bold cyan]{node_name}[/bold cyan]] Build failed")
                if node_name not in cls._fail_libs:
                    cls._fail_libs.append(node_name)
                return False
        else:
            return True
        return False


    @classmethod
    def _should_build(cls, triplet, node_name, config):
        # Parse node name to get library name and dependency type
        lib, dep_type = DependencyResolver.parse_dependency_name(node_name)
        # Check if library node is not installed
        if not HistoryManager.check_installed(triplet, node_name):
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: not installed")
            return True
        # Check if library node update is available
        if HistoryManager.check_for_update(triplet, node_name, config):
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: update available")
            return True
        # Get library node information
        lib_info = HistoryManager.get_library_info(triplet, node_name)
        if not lib_info:
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: no library info")
            return True
        # Check if library node has no build timestamp
        lib_built = lib_info.get('built')
        if not lib_built:
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: no build timestamp")
            return True
        # Check for any file changes in the port directory
        lib_dir = root_dir / 'ports' / lib
        if lib_dir.exists():
            # Walk through all files in the port directory
            for file_path in lib_dir.rglob('*'):
                if file_path.is_file():
                    file_mtime = file_path.stat().st_mtime
                    if file_mtime > lib_built.timestamp():
                        RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: file {file_path.relative_to(lib_dir)} modified")
                        return True
        # Check for source code updates (for git repositories)
        url = config.get('url', '')
        if url.endswith('.git'):
            source_dir = root_dir / 'buildtrees' / 'sources' / lib
            if source_dir.exists():
                last_commit_time = GitHandler.get_last_commit_time(source_dir)
                if not last_commit_time:
                    RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: Failed to get commit time")
                    return True
                elif last_commit_time > lib_built.timestamp():
                    RichLogger.info(f"[[bold cyan]{node_name}[/bold cyan]] Build required: source code updated")
                    return True
        # Check all dependencies for rebuild requirements
        deps = DependencyResolver.get_dependencies(lib, dep_type)
        for dep in deps:
            RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Checking dependency: [bold cyan]{dep}[/bold cyan]")
            # Get dependency information
            dep_info = HistoryManager.get_library_info(triplet, dep)
            if not dep_info:
                RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] No info for dependency [bold cyan]{dep}[/bold cyan]")
                continue
            dep_built = dep_info.get('built')
            if not dep_built:
                RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] No build timestamp for dependency [bold cyan]{dep}[/bold cyan]")
                continue
            # Compare build timestamps
            if dep_built > lib_built:
                RichLogger.debug(f"[[bold cyan]{node_name}[/bold cyan]] Build required: dependency [bold cyan]{dep}[/bold cyan] was updated")
                return True
        return False
