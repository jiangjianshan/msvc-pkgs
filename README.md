<div align="center">
  <img alt="logo" src="https://raw.githubusercontent.com/jiangjianshan/i/main/msforge-logo.png" width="600">
</div>

## Core Features

`msforge` is dedicated to simplifying the compilation and installation process of open-source libraries on the Windows platform using the MSVC or MSVC-like toolchains. Its core capabilities are as follows:

*   🛠️ **Intelligent Environment Management**: Automatically detects, downloads, or guides the user to supplement missing system dependencies (such as Git, build tools).
*   🧩 **Automated Dependency Building**: Parses the library-specific `config.yaml` configuration file, automatically generates a dependency graph and calculates the build order, supporting bootstrapping builds.
*   📦 **Flexible Source Code Handling**: Supports compiling single libraries, multiple libraries, or all libraries. Compatible with fetching source code from archives or Git repositories.
*   🚧 **Isolated Build Environment**: Each library's build process runs in an independent and isolated command-line environment, preventing environment variable pollution.
*   📊 **Clear Build Feedback**: Provides color-highlighted real-time output in the terminal and generates independent colorized log files for each library, facilitating tracking and debugging.
*   🗑️ **Convenient Resource Management**: Supports one-click cleanup of source code, logs, or installed library files via a unified command.
*   🧭 **Rapid Configuration Generation**: Provides an interactive wizard to quickly generate a basic `config.yaml` configuration template for a library, requiring only minor adjustments for use.
*   ⚙️ **Out-of-the-box Autotools Support**: Eliminates the need to pre-install a full Cygwin/MSYS2 environment. Automatically supplements only the necessary components to support building Autotools-based libraries within the Git for Windows environment.
*   ⚡ **Optimized Build Output**: For libraries using libtool, optimizes their build artifacts to uniformly output `.lib` library files natively supported by MSVC.
*   🔄 **Continuous Iteration**: More practical features are under active development.

## Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/jiangjianshan/msforge.git
cd msforge

# 2. View all commands and option descriptions
mpt --help

# 3. View the installation status of all libraries
mpt --list

# 4. Compile a specified library (using ffmpeg as an example)
mpt ffmpeg

# 5. One-click compile and install all supported libraries (default build architecture is x86_64-pc-windows-msvc)
mpt
```

## Frequently Asked Questions (FAQ)

### 1. Why was `msforge` developed?
Compiling open-source libraries using the native MSVC toolchain on Windows is highly complex. `msforge` focuses on solving this core pain point, aiming to provide a one-stop solution to tackle the build challenges of various libraries in the Windows + MSVC environment.

### 2. Why is the compilation/installation directory separate for each library?
Some libraries (e.g., OpenSSL, LibreSSL) produce header and library files with the same name but different versions or configurations. A shared directory would lead to conflicts. `msforge` installs each library independently in the `packages/{lib}-{version}-{triplet}` directory, fundamentally avoiding interference. Compile-time dependencies between libraries are precisely defined and managed by the `dependencies` field in `config.yaml`.

### 3. Why use a combination of YAML + Batch/Bash scripts, instead of JSON + CMake?
`msforge` pursues simplicity, efficiency, and maintainability: YAML is responsible for clearly defining library metadata and dependencies; Batch and Bash scripts efficiently handle the build process for non-Autotools and Autotools projects respectively. This clear division of labor significantly reduces development and maintenance costs.

### 4. Why do Batch and Bash scripts coexist, instead of unifying on Bash?
On Windows, many build tools (e.g., CMake, Meson) often require extensive additional handling or simply fail to compile successfully when run within a Bash environment. `msforge` adopts a more pragmatic approach: using Batch scripts for non-Autotools libraries and Bash scripts for Autotools libraries. Both script types maintain highly consistent function interfaces and structures, ensuring compatibility while also balancing development efficiency.

## Contribution Guidelines

`msforge` already supports a variety of open-source libraries. Use `mpt --list` to view the complete list. As a personal project, its development relies on contributions from the community. Your involvement is welcome and greatly appreciated!

### Ways to Contribute:
-   **Report Issues or Suggestions**: Report bugs or share ideas via https://github.com/jiangjianshan/msforge/issues.
-   **Extend or Improve Library Support**: Follow the process below to add a new library or optimize the build script for an existing one.

### Steps to Add a New Library
1.  **Generate Configuration Template**  
    Run `mpt --add <library-name>`. This will create a new library directory under `ports` and generate a base `config.yaml` file. Adjust the configuration as needed.

2.  **Apply Patches (Optional)**  
    If Windows/MSVC specific fixes are required, place the `.diff` patch file in the library directory.

3.  **Write the Build Script**  
    Create a `build.bat` (for non-autotools based) or `build.sh` (for autotools based) script in the `ports/<library-name>` directory. You can refer to the scripts of other existing libraries within the `ports` subdirectories.

4.  **Test and Submit**  
    Run `mpt <library-name>` to test. Once it passes, submit a Pull Request containing the complete `ports/<library-name>` directory.