# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os

from mpt import root_dir
from mpt.config import LibraryConfig
from mpt.file import FileUtils
from mpt.history import HistoryManager
from mpt.log import RichLogger


class CleanManager:
    @staticmethod
    def clean_logs(triplet, lib):
        log_file = root_dir / 'buildtrees' / 'logs' / triplet / f"{lib}.log"
        if log_file.exists():
            FileUtils.delete_file(log_file)


    @staticmethod
    def clean_source(lib):
        config = LibraryConfig.load(lib)
        url = config.get('url', '')
        source_root = root_dir / 'buildtrees' / 'sources'
        if url.endswith('.git'):
            source_dirs = [source_root / lib]
        else:
            source_dirs = list(source_root.glob(f"{lib}-[v0-9]*"))
        for source_dir in source_dirs:
            FileUtils.delete_directory(source_dir)


    @staticmethod
    def clean_archives(lib):
        cleaned_paths = []
        downloads_root = root_dir / 'buildtrees' / "downloads"
        archive_patterns = [
            f"{lib}-[v0-9]*.*",
            f"{lib}_[v0-9]*.*",
        ]
        for pattern in archive_patterns:
            for archive in downloads_root.glob(pattern):
                FileUtils.delete_file(archive)


    @staticmethod
    def clean_package(triplet, lib):
        HistoryManager.remove_record(triplet, lib)
        config = LibraryConfig.load(lib)
        lib = config.get('name')
        lib_ver = str(config.get('version'))
        prefix = root_dir / 'packages' / f"{lib}-{lib_ver}-{triplet}"
        FileUtils.delete_directory(prefix)


    @staticmethod
    def clean_library(triplet, lib):
        CleanManager.clean_logs(triplet, lib)
        CleanManager.clean_source(lib)
        CleanManager.clean_archives(lib)
