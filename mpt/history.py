# -*- coding: utf-8 -*-
"""
History manager module for tracking library installation records per triplet

Copyright (c) 2024 Jianshan Jiang

"""

from datetime import datetime
from pathlib import Path

from mpt import root_dir
from mpt.log import RichLogger
from mpt.yaml import YamlUtils


class HistoryManager:

    @classmethod
    def _get_record_path(cls, triplet):
        return root_dir / 'buildtrees' / 'infos' / triplet / 'status.yaml'


    @classmethod
    def _load_records(cls, triplet: str) -> dict:
        record_path = cls._get_record_path(triplet)
        if not record_path.exists():
            return {}
        records = YamlUtils.load(record_path) or {}
        return records


    @classmethod
    def _save_records(cls, triplet: str, records: dict) -> bool:
        record_path = cls._get_record_path(triplet)
        record_path.parent.mkdir(parents=True, exist_ok=True)
        return YamlUtils.dump(record_path, records, sort_keys=True)


    @classmethod
    def add_record(cls, triplet: str, node_name: str, version: str) -> bool:
        records = cls._load_records(triplet)
        # Initialize library record if it doesn't exist
        if node_name not in records:
            records[node_name] = {}
        records[node_name] = {
            'version': version,
            'built': datetime.now()
        }
        success = cls._save_records(triplet, records)
        return success


    @classmethod
    def remove_record(cls, triplet: str, node_name: str) -> bool:
        records = cls._load_records(triplet)
        if not records:
            return True
        if node_name in records:
            # Remove the specific library record
            del records[node_name]
            success = cls._save_records(triplet, records)
            return success
        return True


    @classmethod
    def check_installed(cls, triplet: str, node_name: str) -> bool:
        records = cls._load_records(triplet)
        return node_name in records


    @classmethod
    def check_for_update(cls, triplet: str, node_name: str, config: dict) -> bool:
        # Check if library node is installed
        installed = cls.check_installed(triplet, node_name)
        if not installed:
            return True
        # Get library node information
        lib_info = cls.get_library_info(triplet, node_name)
        if not lib_info:
            return True
        # Compare versions
        current_version = config.get('version', 'unknown')
        if current_version != lib_info.get('version'):
            return True
        return False


    @classmethod
    def get_library_info(cls, triplet: str, node_name: str) -> dict:
        records = cls._load_records(triplet)
        if not records or node_name not in records:
            return None
        record = records[node_name]
        result = {
            'version': record.get('version')
        }
        time_val = record.get('built')
        if isinstance(time_val, datetime):
            result['built'] = time_val
        elif isinstance(time_val, str):
            result['built'] = datetime.fromisoformat(time_val)
        else:
            result['built'] = None
        return result


    @classmethod
    def get_records(cls, triplet: str) -> dict:
        records = cls._load_records(triplet)
        return records
