# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#

from rich.text import Text
from rich.table import Table
from rich import box

from mpt.log import RichLogger
from mpt.view import RichPanel


class CommandLineHelp:

    # Constants for table formatting
    OPTION_WIDTH = 20
    DESCRIPTION_WIDTH = 60
    EXAMPLES_WIDTH = 40

    @staticmethod
    def display_help():
        usage_text = Text("📝 Usage:\n", style="bold")
        usage_text.append("     mpt [OPTIONS] [LIBRARIES...]\n", style="bold green")
        RichLogger.print(usage_text)

        RichLogger.print("⚙️ Options:", style="bold")
        CommandLineHelp._display_options_table()

        RichLogger.print("🚀 Examples:", style="bold")
        CommandLineHelp._display_examples_table()


    @staticmethod
    def _display_options_table():
        options_table = Table(
            show_header=False,
            box=box.SIMPLE,
            min_width=80,
            show_lines=False
        )

        options_table.add_column("Option", style="bold cyan", no_wrap=True, width=CommandLineHelp.OPTION_WIDTH)
        options_table.add_column("Description", style="dim", justify="left", min_width=CommandLineHelp.DESCRIPTION_WIDTH)

        option_rows = [
            ("--install", "🛠️ Install specified libraries or all libraries (default action)"),
            ("--uninstall", "🚮 Uninstall specified libraries or all libraries"),
            ("--list", "📋 List installation status of libraries"),
            ("--dependency", "🌳 Show dependency tree for specified libraries"),
            ("--clean", "🧹 Clean build artifacts for specified libraries"),
            ("--fetch", "📥 Download source archives for specified libraries"),
            ("--arch ARCH", "🎯 Specify target architecture in format {arch} (default: x64)"),
            ("--add", "➕ Add and configure a new library with build system detection"),
            ("--remove", "➖ Remove library configuration files"),
            ("-h, --help", "💡 Show this help message and exit"),
            ("[LIBRARIES]", "📦 List of libraries to process (optional)")
        ]

        for option, description in option_rows:
            options_table.add_row(option, description)

        RichLogger.print(options_table)


    @staticmethod
    def _display_examples_table():
        examples_table = Table(
            show_header=False,
            box=box.SIMPLE,
            min_width=80,
            show_lines=False,
            padding=(0, 1)
        )
        examples_table.add_column("Command", style="bold green", no_wrap=True, width=CommandLineHelp.EXAMPLES_WIDTH)
        examples_table.add_column("Description", style="italic", justify="left", min_width=CommandLineHelp.DESCRIPTION_WIDTH)
        example_rows = [
            ("mpt", "🔄 Install all libraries for x64 (default behavior)"),
            ("mpt gmp ffmpeg fftw", "🧮 Install libraries (ffmpeg, gmp, fftw) for x64"),
            ("mpt --arch x86", "🔧 Install all libraries for x86 architecture"),
            ("mpt --add gmp", "➕ Add library configuration"),
            ("mpt --remove gmp", "➖ Remove library configuration"),
            ("mpt --arch x86 gmp ffmpeg fftw", "🧮 Install libraries for x86 architecture"),
            ("mpt --uninstall", "🗑️ Uninstall all libraries for x64"),
            ("mpt --arch x86 --uninstall gmp fftw", "🗑️ Uninstall libraries (gmp, fftw) for x86 architecture"),
            ("mpt --list", "📋 List status of all libraries for x64"),
            ("mpt --list gmp fftw", "📋 List status of specific libraries"),
            ("mpt --dependency", "🌳 Show dependency tree for all libraries"),
            ("mpt --dependency gmp fftw", "🌿 Show dependency tree for specific libraries"),
            ("mpt --clean", "🧹 Clean artifacts for all libraries"),
            ("mpt --clean gmp fftw", "🧹 Clean artifacts for specific libraries"),
            ("mpt --fetch", "📥 Download sources for all libraries"),
            ("mpt --fetch gmp fftw", "📥 Download sources for specific libraries"),
        ]
        for command, description in example_rows:
            examples_table.add_row(command, description)
        RichLogger.print(examples_table)
