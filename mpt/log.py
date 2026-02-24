# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#
import logging
import os

from pathlib import Path

from rich.console import Console
from rich.logging import RichHandler
from rich.traceback import install


class RichLogger:
    # Class variables for logging state
    _initialized = False
    _logger = logging.getLogger("mpt")
    # Initialize and configure the console instance with Rich formatting.
    _console = Console(
        force_terminal=True,      # Ensure rich formatting in all terminal environments
        color_system="truecolor", # Enable 24-bit color support for vibrant output
        highlight=True,           # Apply syntax highlighting to code and structured text
        log_path=False            # Disable automatic logging to file for clean console output
    )
    _formatter = None
    _file_handler = None

    @classmethod
    def initialize(cls, log_level=logging.DEBUG):
        if cls._initialized:
            return
        cls._logger.setLevel(log_level)
        for handler in cls._logger.handlers[:]:
            cls._logger.removeHandler(handler)
            handler.close()
        console_handler = RichHandler(
            console=cls._console,
            markup=False,
            show_level=True,
            show_path=False,
            show_time=False,
            rich_tracebacks=True,
            tracebacks_show_locals=True
        )
        cls._formatter = logging.Formatter("%(message)s")
        console_handler.setFormatter(cls._formatter)
        cls._logger.addHandler(console_handler)
        install(console=cls._console, show_locals=True)
        cls._initialized = True


    @classmethod
    def add_file_logging(cls, log_file, level=logging.DEBUG):
        # Remove existing file handler if present
        cls.remove_file_logging()
        # Ensure directory exists
        log_dir = os.path.dirname(log_file)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        # Create file handler
        cls._file_handler = logging.FileHandler(log_file, mode='w', encoding='utf-8')
        cls._file_handler.setLevel(level)
        cls._file_handler.setFormatter(cls._formatter)
        # Add handler to logger
        cls._logger.addHandler(cls._file_handler)


    @classmethod
    def remove_file_logging(cls):
        if cls._file_handler:
            try:
                cls._logger.removeHandler(cls._file_handler)
                cls._file_handler.close()
            except Exception as e:
                cls._logger.error(f"Failed to remove file logging: {e}")
            finally:
                cls._file_handler = None


    @classmethod
    def debug(cls, msg, *args, markup=True, **kwargs):
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.debug(msg, *args, **kwargs)


    @classmethod
    def info(cls, msg, *args, markup=True, **kwargs):
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.info(msg, *args, **kwargs)


    @classmethod
    def warning(cls, msg, *args, markup=True, **kwargs):
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.warning(msg, *args, **kwargs)


    @classmethod
    def error(cls, msg, *args, markup=True, **kwargs):
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.error(msg, *args, **kwargs)


    @classmethod
    def critical(cls, msg, *args, markup=True, **kwargs):
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.critical(msg, *args, **kwargs)


    @classmethod
    def exception(cls, msg, *args, markup=True, **kwargs):
        if markup:
            kwargs['extra'] = {"markup": True}
        cls._logger.exception(msg, *args, **kwargs)


    @classmethod
    def print(cls, *args, **kwargs):
        cls._console.print(*args, **kwargs)


    @classmethod
    def get_console_width(cls):
        return cls._console.width
