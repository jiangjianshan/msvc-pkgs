# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import logging
import os
import re
import subprocess
import sys

from pathlib import Path
from typing import Dict, Any, Optional, Union, List
from rich.text import Text

from mpt import root_dir
from mpt.config import LibraryConfig
from mpt.dependency import DependencyResolver
from mpt.log import RichLogger


class Runner:
    _saved_console_mode = None
    _proc_env = {}
    _prefix = None

    @classmethod
    def _expand_envvars(cls, cmd):
        def replace_env(match):
            var = match.group(1)
            return os.environ.get(var, match.group(0))
        return re.sub(r'%([^%]+)%', replace_env, cmd)


    @classmethod
    def _setup_basic_environment(cls, arch, config):
        # Set basic environment variables
        cls._proc_env['ARCH'] = arch
        lib = config.get('name')
        lib_ver = str(config.get('version'))
        lib_url = config.get('url')
        if lib_url.endswith('.git'):
            lib_srcdir = str(root_dir / 'buildtrees' / 'sources' / f"{lib}")
        else:
            lib_srcdir = str(root_dir / 'buildtrees' / 'sources' / f"{lib}-{lib_ver}")
        script = config.get('script')
        if script:
            if Path(script).name.endswith('.sh'):
                lib_rootdir = cls.capture_run(f"cygpath -u \"{str(root_dir)}\"")
                lib_srcdir = cls.capture_run(f"cygpath -u \"{lib_srcdir}\"")
                cls._proc_env['ROOT_DIR'] = lib_rootdir
        cls._proc_env['SRC_DIR'] = lib_srcdir
        cls._proc_env['PKG_NAME'] = lib
        cls._proc_env['PKG_VER'] = lib_ver


    @classmethod
    def _setup_prefix_environment(cls, arch, config, dep_type):
        from mpt.build import BuildManager
        triplet = BuildManager.get_triplet(arch)
        lib = config.get('name')
        lib_ver = str(config.get('version'))
        prefix = str(root_dir / 'packages' / f"{lib}-{lib_ver}-{triplet}")
        cls._prefix = prefix
        Path(cls._prefix).mkdir(parents=True, exist_ok=True)
        prefix_paths = [prefix]
        deps = DependencyResolver.get_dependencies(lib, dep_type)
        for dep in deps:
            dep_name, _ = DependencyResolver.parse_dependency_name(dep)
            dep_config = LibraryConfig.load(dep_name)
            dep_ver = dep_config.get('version')
            dep_url = dep_config.get('url')
            dep_prefix = str(root_dir / 'packages' / f"{dep_name}-{dep_ver}-{triplet}")
            prefix_env = dep_name.replace('-', '_').upper() + '_PREFIX'
            if prefix_env not in cls._proc_env:
                cls._proc_env[prefix_env] = dep_prefix
                # Add binary directory to PATH if it exists
                bin_dir = Path(dep_prefix) / 'bin'
                current_path = cls._proc_env.get('PATH', '')
                if bin_dir.exists():
                    if str(bin_dir) not in current_path:
                        cls._proc_env['PATH'] = f"{str(bin_dir)}{os.pathsep}{current_path}"
                elif dep_prefix not in current_path:
                    # Some prefix may don't have bin dir but have share dir
                    cls._proc_env['PATH'] = f"{dep_prefix}{os.pathsep}{current_path}"
                if dep_prefix not in prefix_paths:
                    prefix_paths.append(dep_prefix)
            dep_src_env = dep_name.replace('-', '_').upper() + '_SRC'
            if dep_url.endswith('.git'):
                cls._proc_env[dep_src_env] = str(root_dir / 'buildtrees' / 'sources' / f"{dep_name}")
            else:
                cls._proc_env[dep_src_env] = str(root_dir / 'buildtrees' / 'sources' / f"{dep_name}-{dep_ver}")
            dep_ver_env = dep_name.replace('-', '_').upper() + '_VER'
            cls._proc_env[dep_ver_env] = str(dep_ver)
        script = config.get('script')
        if script:
            if Path(script).name.endswith('.sh'):
                prefix = cls.capture_run(f"cygpath -u \"{prefix}\"")
        cls._proc_env['PREFIX'] = prefix
        cls._proc_env['PREFIX_PATH'] = os.pathsep.join(prefix_paths)


    @classmethod
    def setup_environment(cls, arch, node_name):
        cls._proc_env = os.environ.copy()
        lib, dep_type = DependencyResolver.parse_dependency_name(node_name)
        config = LibraryConfig.load(lib)
        cls._setup_basic_environment(arch, config)
        cls._setup_prefix_environment(arch, config, dep_type)


    @classmethod
    def _save_console_mode(cls):
        if sys.platform != 'win32':
            return
        import ctypes
        from ctypes import wintypes
        STD_OUTPUT_HANDLE = -11
        handle = ctypes.windll.kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
        mode = wintypes.DWORD()
        if ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            cls._saved_console_mode = mode.value


    @classmethod
    def _restore_console_mode(cls):
        if sys.platform != 'win32' or cls._saved_console_mode is None:
            return
        import ctypes
        from ctypes import wintypes
        STD_OUTPUT_HANDLE = -11
        handle = ctypes.windll.kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
        current_mode = wintypes.DWORD()
        if not ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(current_mode)):
            return
        if current_mode.value != cls._saved_console_mode:
            ctypes.windll.kernel32.SetConsoleMode(handle, cls._saved_console_mode)


    @classmethod
    def execute(cls, cmd, cwd = None, log_file = None):
        error_pattern = re.compile(r'(?i)(?<!\w)(error|fatal)(?:\s+[A-Z]+\d+)?\s*:')
        warning_pattern = re.compile(r'(?i)(?<!\w)warning(?:\s+[A-Z]+\d+)?\s*:')
        exit_code = -1
        try:
            # Save console mode before execution
            cls._save_console_mode()
            if log_file:
                RichLogger.add_file_logging(log_file)
            p = subprocess.Popen(
                cmd,
                cwd = str(cwd) if cwd else None,
                env=cls._proc_env if cls._proc_env else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            for line in iter(p.stdout.readline, b''):
                decoded_line = line.decode('utf-8', errors='ignore').rstrip()
                if error_pattern.search(decoded_line):
                    RichLogger.error(decoded_line, markup=False)
                elif warning_pattern.search(decoded_line):
                    RichLogger.warning(decoded_line, markup=False)
                else:
                    RichLogger.info(decoded_line, markup=False)
                #
                # NOTE:
                # Avoid checking p.poll() here - the iter() loop naturally terminates when output ends.
                # Early poll() checks can truncate error messages if build scripts exit abruptly
                # during parallel execution (e.g., with '|| exit 1').
                #
                #  if p.poll() is not None:
                    #  break
            # Wait for process completion
            exit_code = p.wait()
            return exit_code == 0
        except Exception as e:
            RichLogger.exception(f"Unhandled execution error: [bold red]{str(e)}[/bold red]")
            return -1
        finally:
            if log_file:
                RichLogger.remove_file_logging()
            # CRITICAL: Restore console mode immediately after process exits
            cls._restore_console_mode()


    @classmethod
    def run_script(cls, script_file, args = None, log_file = None):
        script_file = Path(script_file) if isinstance(script_file, str) else script_file
        script_dir = script_file.parent
        orig_dir = os.getcwd()
        try:
            os.chdir(script_dir)
            if script_file.name.endswith('.bat'):
                cmd = [script_file.name]
            else:
               cmd = ['bash', script_file.name]
            if args:
                cmd.extend(args)
            return cls.execute(cmd, log_file=log_file)
        except Exception as e:
            RichLogger.exception(f"Failed to execute script: {e}")
            return False
        finally:
            os.chdir(orig_dir)


    @classmethod
    def capture_run(cls, cmd, cwd = None):
        p = subprocess.Popen(
            cmd,
            cwd = str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
        stdout, _ = p.communicate()
        output = stdout.decode('utf-8', errors='ignore').rstrip()
        if p.returncode == 0:
            return output
        else:
            return None


    @classmethod
    def silent_run(cls, cmd, cwd = None):
        p = subprocess.run(
            cmd,
            shell = True,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE
        )
        return p.returncode == 0
