# msvc-pkgs

msvc-pkgs helps you manage C and C++ libraries to use Visual C++ toolset to do native build on Windows.

## Why?

- 🚀 **Native**: the file extension of all libraries build and install from source are .lib not .a.
- 💎 **Easily**: to use Visual C++ compiler to build those libraries based on GNU Autotools or some other open source are often a challenge and hard work, msvc-pkgs has created a series of scripts to make them easily
- 🌟 **Featured**: libtool don't have options can set the naming style of static and shared library. If without msvc-pkgs, the file extension of shared library will be .dll.lib, this is not good to other libraries which do not use libtool but need to link this shared library. msvc-pkgs has made a workaround to solve the naming style of static and shared library.
- ❤️ **Flexible**: Using same writing style and sharing the common scripts, all new available build script for libraries can be put into the ports folder

## Dependencies

- Cygwin (autoconf,automake,libtool,make,pkg-config,patch,flex,bison,dos2unix,gperf,zsh)
- Visual C++ Build Tools or Visual Studio
- Windows 10 SDK
- Git
- Python 3
- CMake
- wget
- ninja
- meson
- CUDA & CUDNN (For NVIDIA GPU)
- Windows Terminal (Optional but recommend to have it)

## Quick Start

First, download msvc-pkgs from github in your local location, e.g. E:\Githubs
```bat
cd /d E:\Githubs
git clone https://github.com/jiangjianshan/msvc-pkgs.git
```

If you don't install those [Dependencies](#dependencies) above, you can run
```bat
cd /d E:\Githubs\msvc-pkgs
bootstrap.bat
````
on the command prompt, ```bootstrap.bat``` will check and install them automatically except for some of them only ask you to install the newest version

## How to use
All the examples below are assume you download msvc-pkgs into E:\Githubs. If you download it on another location, please change the ```cd``` command according to you actual situation.

### Example: get help of msvc-pkgs

On command prompt, type
```bat
cd /d E:\Githubs\msvc-pkgs
msvc-pkgs.bat --help
```

On Cygwin terminal, type
```bash
cd /cygdrive/e/Githubs/msvc-pkgs
./msvc-pkgs.sh --help
```
### Example: get all available libraries have been ported success
On command prompt, type
```bat
cd /d E:\Githubs\msvc-pkgs
msvc-pkgs.bat --list
```

On Cygwin terminal, type
```bash
cd /cygdrive/e/Githubs/msvc-pkgs
./msvc-pkgs.sh --list
```

### Example: build all available libraries supported

Here only give the example of ```msvc-pkgs.sh```. ```msvc-pkgs.bat``` has same parameters as ```msvc-pkgs.sh```, the only different is that ```msvc-pkgs.bat``` run in command prompt and ```msvc-pkgs.sh``` run in cygwin terminal.

First enter the root location of msvc-pkgs
```bash
cd /cygdrive/e/Githubs/msvc-pkgs
```

Then run one of below command according to your requirements

```bash
# build all available libraries on default system architecture, and install them on default prefix, e.g. E:\Githubs\msvc-pkgs\x64
./msvc-pkgs.sh
```

```bash
# build and install all available libraries on x86 architecture, and install them on default prefix, e.g. E:\Githubs\msvc-pkgs\x86
./msvc-pkgs.sh --arch=x86
```

```bash
# build and install all available libraries on x86 architecture, and install them on default prefix, e.g. E:\Githubs\msvc-pkgs\x64
./msvc-pkgs.sh --arch=x64
```

```bash
# build all available libraries on default architecture and install them to D:\mswin64
./msvc-pkgs.sh --prefix="D:\mswin64"
```

```bash
# build all available libraries on default system architecture, and install them on default prefix except for llvm-project and lua have their own install prefix
./msvc-pkgs.sh --llvm-project-prefix="D:\LLVM" --lua-prefix="D:\Lua"
```

```bash
# build all available libraries on default system architecture, and install them on D:\mswin64 except for llvm-project and lua have their own install prefix
./msvc-pkgs.sh --llvm-project-prefix="D:\LLVM" --lua-prefix="D:\Lua" --prefix="D:\mswin64"
```

### Example: build a libraries that has been suppored

First enter the folder of ports

```bash
cd /cygdrive/e/Githubs/msvc-pkgs/ports
```

Then run one of below command according to your requirements

```bash
# build gmp on default system architecture and install it on default prefix, e.g. E:\Githubs\msvc-pkgs\x64
./gmp.sh
```

```bash
# build gmp on x86 architecture and install it on default prefix, e.g. E:\Githubs\msvc-pkgs\x86
./gmp.sh --arch=x86
```

```bash
# build gmp on x86 architecture and install it on default prefix, e.g. E:\Githubs\msvc-pkgs\x64
./gmp.sh --arch=x64
```

```bash
# build gmp on default system architecture and install it on D:\mswin64
./gmp.sh --prefix="D:\mswin64"
```

### Example: build some but not all libraries that have been supported

First enter the folder of ports

```bash
cd /cygdrive/e/Githubs/msvc-pkgs/ports
```

Then run one of below command according to your requirement

```bash
# build gmp on default system architecture and install it to default prefix, e.g. E:\Githubs\msvc-pkgs\x64
./msvc-pkgs.sh --ports=gmp
```

```bash
# build gmp and gettext on default system architecture and install them to default prefix, e.g. E:\Githubs\msvc-pkgs\x64
./msvc-pkgs.sh --ports=gmp,gettext
```

```bash
# build gmp and gettext on default architecture and install them to D:\mswin64
./msvc-pkgs.sh --prefix="D:\mswin64" --ports=gmp,gettext
```

## Contributors

This project follows the [all-contributors](https://allcontributors.org) specification.
Contributions of any kind are welcome!

## Available ports

| Name                        | Version    |
| --------------------------- | ---------- |
| abseil-cpp                  | 20240116.2 |
| blaspp                      | 2024.05.31 |
| boost                       | 1.85.0     |
| brotli                      | 1.1.0      |
| bzip2                       | 1.0.8      |
| cairo                       | 1.18.0     |
| cairomm                     | 1.18.0     |
| c-ares                      | 1.28.1     |
| ccls                        | 0.20240202 |
| cppcheck                    | 2.14.0     |
| cpp-httplib                 | 0.16.0     |
| ctags                       | git        |
| curl                        | 8_7_1      |
| doxygen                     | 1.11.0     |
| effcee                      | git        |
| eigen                       | 3.4.0      |
| expat                       | 2.6.2      |
| filament                    | 1.52.2     |
| flatbuffers                 | 24.3.25    |
| freetype                    | 2.13.2     |
| gettext                     | 0.22.5     |
| giflib                      | 5.2.2      |
| gklib                       | 5.1.1      |
| glib                        | 2.80.2     |
| gmp                         | 6.3.0      |
| googletest                  | 1.14.0     |
| grpc                        | 1.64.1     |
| gsl                         | 2.8        |
| guetzli                     | 1.0.1      |
| harfbuzz                    | 8.5.0      |
| HiGHS                       | 1.7.1      |
| hwloc                       | 2.10.0     |
| icu                         | 75_1       |
| intel-llvm                  | git        |
| lapack                      | 3.12.0     |
| leveldb                     | 1.23       |
| level-zero                  | 1.17.17    |
| libarchive                  | 3.7.3      |
| libdeflate                  | 1.19       |
| libevent                    | 2.1.12     |
| libffi                      | 3.4.6      |
| libgeotiff                  | 1.7.1      |
| libiconv                    | 1.17       |
| libidn2                     | 2.3.7      |
| libjpeg-turbo               | 3.0.2      |
| libpng                      | 1.6.43     |
| libsigcplusplus             | 3.6.0      |
| libsigsegv                  | 2.14       |
| libtasn1                    | 4.19.0     |
| libtiff                     | 4.6.0      |
| libunistring                | 1.2        |
| libvpx                      | 1.14.1     |
| libwebp                     | 1.4.0      |
| libxml2                     | 2.12.6     |
| libxslt                     | 1.1.39     |
| LightGBM                    | 4.4.0      |
| llvm-project                | 18.1.8     |
| lua                         | 5.4.6      |
| lz4                         | 1.9.4      |
| make                        | 4.4        |
| mimalloc                    | 2.1.7      |
| mpfr                        | 4.2.1      |
| nasm                        | 2.16.03    |
| oneTBB                      | 2021.13.0  |
| openblas                    | 0.3.27     |
| OpenCL-Headers              | 2024.05.08 |
| openssl                     | 3.3.1      |
| pcre                        | 8.45       |
| pcre2                       | 10.43      |
| perl                        | 5.38.2     |
| pixman                      | 0.43.4     |
| pkg-config                  | 0.29.2     |
| proj                        | 9.4.0      |
| re2                         | 2024-05-01 |
| ruby                        | 3.3.1      |
| scip                        | 9.0.1      |
| sed                         | 4.9        |
| sentencepiece               | 0.2.0      |
| soplex                      | 7.0.1      |
| SPIRV-Headers               | 1.3.283.0  |
| SPIRV-Tools                 | git        |
| sqlite3                     | 3.45.3     |
| suitesparse                 | 7.7.0      |
| tcl                         | 8.6.14     |
| tk                          | 8.6.14     |
| unified-memory-framework    | git        |
| unified-runtime             | 0.8.14     |
| winfile                     | 10.3.0.0   |
| xapian-core                 | 1.4.25     |
| xz                          | 5.4.6      |
| yaml                        | 0.2.5      |
| yasm                        | 1.3.0      |
| zlib                        | 1.3.1      |
| zstd                        | 1.5.6      |
