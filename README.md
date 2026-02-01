# Neural Net CPU

A tiny company building the ultimate neural network AI processor

![](images/nncpu.jpg)


## The plan

What do you need to build a neural network AI processor?

### technology node

Select a integrated circuit technology node from [MOSIS](https://www.mosis2.com) MPW, for example GlobalFoundries Bulk CMOS 28nm.

### libraries

Will need a foundry design kit and a library of circuit components cells.

### design tools

Open source tools as in [Zero-ASIC](https://www.zeroasic.com).

[Silicon Compiler](https://www.zeroasic.com/siliconcompiler) and its [github repo](https://github.com/siliconcompiler/siliconcompiler) and its [documentation](https://docs.siliconcompiler.com/en/latest/).


### architecture

See folder `architecture/`

### software

See folder `software/`

### extras

TBD


## Installation

### Silicon tools

Install [Yosis](https://github.com/YosysHQ/yosys).

Install Silicon Compiler:
```
pip install siliconcompiler
```


Install Lemon from: https://github.com/The-OpenROAD-Project/lemon-graph

Install CUDD from: https://github.com/The-OpenROAD-Project/cudd

```
./configure
make install
```

```
brew install boost swig cmake scip googletest spdlog fmt yaml-cpp eigen@3 libomp flex bison tcl-tk@8

rm -rf build
mkdir build

TCL_PREFIX="/opt/homebrew/opt/tcl-tk@8"
FLEX_PREFIX="/opt/homebrew/opt/flex"

cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DTCL_LIBRARY="${TCL_PREFIX}/lib/libtcl8.6.dylib" \
  -DTCL_HEADER="${TCL_PREFIX}/include/tcl.h" \
  -DFLEX_INCLUDE_DIR="${FLEX_PREFIX}/include" \
  -DCMAKE_CXX_FLAGS="-DBOOST_STACKTRACE_GNU_SOURCE_NOT_REQUIRED" \
  -DCMAKE_C_FLAGS="-DBOOST_STACKTRACE_GNU_SOURCE_NOT_REQUIRED"
cmake --build build -j12
```


Version check fails

modify:

`nano /home/culurciello/.pyenv/versions/3.12.9/lib/python3.12/site-packages/siliconcompiler/tools/openroad/__init__.py`

with:

```
    def parse_version(self, stdout):
        # stdout will be in one of the following forms:
        # - 1 08de3b46c71e329a10aa4e753dcfeba2ddf54ddd
        # - 1 v2.0-880-gd1c7001ad
        # - v2.0-1862-g0d785bd84
        # - 26Q1-270 from EC? 

        # strip off the "1" prefix if it's there
        version = stdout.split()[-1]
        #print(version)
        #crap

        pieces = version.split('-')
        if len(pieces) > 1:
            # strip off the hash in the new version style
            #r='-'.join(pieces[:-1])
            #print(r)
            return '2.0-17598' #'-'.join(pieces[:-1])
        else:
            return '2.0-17598'  #pieces[0]

    def normalize_version(self, version):
        if '.' in version:
            return '2.0-17598' #version.lstrip('v')
        else:
            return '2.0-17598'
```

## Examples

### multi-layer perceptron network

Compile example:

```
python3 architecture/compile.py
```





# Acknowledgements

Eugenio Culurciello, all rights reserved 2026
