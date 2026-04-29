# Setting up Containerised OpenSBLI

Requires apptainer

```sh
sudo apt update
sudo apt install -y software-properties-common

sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt update
sudo apt install -y apptainer

apptainer --version
```

## Apptainer Recipe
```sh
cat containerised_cuda_with_make.def
Bootstrap: docker
From: ubuntu:noble

%post
    # Update system
    apt update -y && apt upgrade -y

    apt install software-properties-common -y 
    apt install python3 -y
    apt install python3-venv -y

    # Fortran compiler
    apt install -y gfortran

    # General build requirements
    apt install -y git cmake libhdf5-openmpi-dev wget

    # MPI
    apt install -y openmpi-bin openmpi-common libopenmpi-dev

    # New C++23 requirement
    apt install -y cpp-14 libstdc++-14-dev libc++-dev libc++abi-dev

    wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda-repo-debian12-12-8-local_12.8.0-570.86.10-1_amd64.deb
    dpkg -i cuda-repo-debian12-12-8-local_12.8.0-570.86.10-1_amd64.deb
    cp /var/cuda-repo-debian12-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
    apt-get update
    apt-get -y install cuda-toolkit-12-8

%environment
    export HERE=~/containerised-opensbli/
    export CXX=g++
    export OPS_COMPILER=gnu
    export OPS_INSTALL_PATH=${HERE}/OPS/ops
    export HDF5_INSTALL_PATH=/usr/lib/x86_64-linux-gnu/hdf5/openmpi/
    export MPI_INSTALL_PATH=/usr/
    export USE_HDF5=1
    export NV_ARCH=Turing
    export MPICXX=mpicxx 
    export CUDA_HOME=/usr/local/cuda
    export CUDA_INSTALL_PATH=/usr/local/cuda
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

Build the Apptainer and enter a Shell 

```sh
apptainer build environment.sif containerised_cuda_with_make.def
...
apptainer shell environment.sif
```

## OPS Setup

Run the script `build_ops_library.sh`

```sh
#!/bin/bash

# OPS Library
git clone https://github.com/OP-DSL/OPS.git

cd OPS/ops/c/
make seq mpi hdf5_seq hdf5_mpi
make cuda mpi_cuda 
```

Export the $OPS_TRANSLATOR variable to the location of the `ops.ps` file
```sh
export OPS_TRANSLATOR=~/containerised-opensbli/OPS/ops_translator/ops-translator/
```

## OPS Translator

Run `ops_translator_setup_venv.sh`

```sh
./ops_translator_setup_venv.sh
```

```sh
cat ops_translator_setup_venv.sh

>>>
#!/bin/bash

if [[ -z $OPS_INSTALL_PATH ]]; then
    echo "Please set OPS_INSTALL_PATH before running this script"
    exit
fi

mkdir -p $OPS_INSTALL_PATH/../ops_translator/ops_venv

python3 -m venv $OPS_INSTALL_PATH/../ops_translator/ops_venv

source $OPS_INSTALL_PATH/../ops_translator/ops_venv/bin/activate

python3 -m pip install -r $OPS_INSTALL_PATH/../ops_translator/requirements.txt

python3 -m pip install --force-reinstall libclang==16.0.6
```

## OpenSBLI Python Environment

Create a python environment to install all the necessary packages

```sh
python3 -m venv venv

python3 -m pip install scipy numpy h5py matplotlib
    
python3 -m pip install sympy
```

## OpenSBLI

Run clone_and_build_opensbli.sh
```sh
#!/bin/bash
git clone git@github.com:opensbli/opensbli_development.git opensbli

cd opensbli

git checkout thermochemical
```

Export PYTHONPATH variable to the install location of opensbli 

```sh
export PYTHONPATH=$PYTHONPATH:.../containerised-opensbli/opensbli
```

Source your OpenSBLI environment and run an app

```sh
source venv/bin/activate

cd opensbli
cd apps
cd euler_wave

python3 euler_wave.py
```

This will generate a bunch of headers and cpp file called 'opensbli.cpp'

## Running an App

Deactivate the previous environment and run the source command for the ops 
```sh
deactivate

source $OPS_INSTALL_PATH/../ops_translator/ops_venv/bin/activate
```

Translate the code using OPS to generate parallel versions

```sh
python3 $OPS_TRANSLATOR/ops.py opensbli.cpp
```

Copy the Makefile into the directory and build your target executable (mpi/cuda/openmp/etc)

```sh
cp ../Makefile ./
make opensbli_cuda
```

Run the executable
```sh
./opensbli_cuda
```
