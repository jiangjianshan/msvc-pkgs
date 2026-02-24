# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import datetime
import os
import shutil
import stat
import time

from pathlib import Path

from mpt.file import FileUtils
from mpt.log import RichLogger
from mpt.run import Runner


class GitHandler:
    @staticmethod
    def is_valid_repository(repo_dir):
        if not repo_dir.exists():
            return False
        git_dir = repo_dir / '.git'
        if not git_dir.exists():
            return False
        output = Runner.capture_run(['git', 'rev-parse', '--is-inside-work-tree'], repo_dir)
        return output is not None


    @staticmethod
    def clone_repository(config, target_dir):
        url = config['url']
        version = config['version']
        recursive = config.get('recursive', True)
        depth = config.get('depth')
        if target_dir.exists():
            if (not GitHandler.is_valid_repository(target_dir) or
                GitHandler._is_only_git_directory(target_dir) or
                GitHandler._is_empty_directory(target_dir)):
                if not FileUtils.delete_directory(target_dir):
                    return False
            else:
                return GitHandler.update_repository(target_dir, config)
        cmd = ['git', 'clone']
        if depth:
            cmd.extend(['--depth', str(depth)])
        cmd.extend(['--branch', version, url, str(target_dir)])
        if not Runner.execute(cmd, target_dir.parent):
            if GitHandler._is_only_git_directory(target_dir):
                FileUtils.delete_directory(target_dir)
            return False
        if GitHandler._is_empty_directory(target_dir):
            FileUtils.delete_directory(target_dir)
            return False
        if recursive:
            override_submodules = config.get('submodules', {})
            if not GitHandler._update_submodules(target_dir, depth, override_submodules):
                RichLogger.error("Submodule initialization failed during clone")
                return False
        return True


    @staticmethod
    def _update_ref(repo_dir, version, is_tag, depth=None):
        if is_tag:
            fetch_target = ['tag', version]
            reset_target = version
        else:
            fetch_target = [version]
            reset_target = f'origin/{version}'
        cmd = ['git', 'fetch', 'origin'] + fetch_target
        if depth:
            cmd.extend(['--depth', str(depth)])
        if not Runner.execute(cmd, repo_dir):
            return False
        return Runner.execute(['git', 'reset', '--hard', reset_target], repo_dir)


    @staticmethod
    def update_repository(repo_dir, config):
        if not GitHandler.is_valid_repository(repo_dir):
            RichLogger.warning(f"Repository is invalid, attempting repair: {repo_dir}")
            return GitHandler.repair_repository(repo_dir, config)
        if GitHandler._is_empty_directory(repo_dir):
            return False
        version = config['version']
        recursive = config.get('recursive', True)
        depth = config.get('depth')
        is_tag = GitHandler._is_tag(repo_dir, version)
        if not GitHandler._update_ref(repo_dir, version, is_tag, depth):
            return False
        if not Runner.execute(['git', 'clean', '-fd'], repo_dir):
            return False
        if recursive:
            override_submodules = config.get('submodules', {})
            if not GitHandler._update_submodules(repo_dir, depth, override_submodules):
                RichLogger.error("Submodule update failed")
                return False
        return True


    @staticmethod
    def _is_only_git_directory(path):
        if not path.exists():
            return False
        items = list(path.iterdir())
        return len(items) == 1 and items[0].name == '.git' and items[0].is_dir()


    @staticmethod
    def _is_empty_directory(path):
        if not path.exists():
            return False
        return not any(path.iterdir())


    @staticmethod
    def _is_tag(repo_dir, ref_name):
        if Runner.capture_run(['git', 'tag', '-l', ref_name], repo_dir):
            return True
        elif Runner.capture_run(['git', 'ls-remote', '--tags', 'origin', ref_name], repo_dir):
            return True
        return False


    @staticmethod
    def _update_submodules(repo_dir, depth=None, override_submodules=None):
        if override_submodules is None:
            override_submodules = {}
        submodules_to_sync = []
        for submodule_path, override_config in override_submodules.items():
            new_url = override_config.get('url')
            new_branch = override_config.get('branch')
            if new_url:
                cmd = ['git', 'config', '-f', '.gitmodules', f'submodule.{submodule_path}.url', new_url]
                if Runner.execute(cmd, repo_dir):
                    submodules_to_sync.append(submodule_path)
            if new_branch:
                cmd = ['git', 'config', '-f', '.gitmodules', f'submodule.{submodule_path}.branch', new_branch]
                Runner.execute(cmd, repo_dir)
        if submodules_to_sync:
            for sub in submodules_to_sync:
                Runner.execute(['git', 'submodule', 'sync', '--', sub], repo_dir)
        cmd = ['git', 'submodule', 'update', '--init', '--recursive', '--force']
        if depth:
            cmd.extend(['--depth', str(depth)])
        return Runner.execute(cmd, repo_dir)


    @staticmethod
    def repair_repository(repo_dir, config):
        if not config:
            return False
        RichLogger.info(f"Attempting to repair repository: {repo_dir}")
        version = config['version']
        depth = config.get('depth')
        is_tag = GitHandler._is_tag(repo_dir, version)
        if GitHandler._update_ref(repo_dir, version, is_tag, depth):
            Runner.execute(['git', 'clean', '-fd'], repo_dir)
            recursive = config.get('recursive', True)
            if recursive:
                override_submodules = config.get('submodules', {})
                GitHandler._update_submodules(repo_dir, depth, override_submodules)
            return True
        RichLogger.info("Repair failed, performing full re-clone...")
        if FileUtils.delete_directory(repo_dir):
            time.sleep(1)
            return GitHandler.clone_repository(config, repo_dir)
        return False


    @staticmethod
    def get_last_commit_time(repo_dir):
        cmd = ['git', 'log', '-1', '--format=%cd', '--date=unix']
        output = Runner.capture_run(cmd, repo_dir)
        if output:
            return float(output)
        else:
            return 0
