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
ls
>> opensbli_ops_recipe.def 

cat opensbli_ops_recipe.def
>>>
Bootstrap: docker
From: ubuntu:noble

%post
    # Update system
    apt update -y && apt upgrade -y

    # Python old repositories
    apt install software-properties-common -y 
    add-apt-repository ppa:deadsnakes/ppa -y

    apt install -y python3.7
    apt install -y python3.7-venv
    apt install -y python3-pip

    apt install -y python3.8
    apt install -y python3.8-venv

    # Fortran compiler
    apt install -y gfortran

    # General build requirements
    apt install -y git cmake libhdf5-openmpi-dev wget

    # MPI
    apt install -y openmpi-bin openmpi-common libopenmpi-dev

    wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda-repo-debian12-12-8-local_12.8.0-570.86.10-1_amd64.deb
    dpkg -i cuda-repo-debian12-12-8-local_12.8.0-570.86.10-1_amd64.deb
    cp /var/cuda-repo-debian12-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
    apt-get update
    apt-get -y install cuda-toolkit-12-8

%environment
    export CXX=gnu
    export OPS_INSTALL_PATH=/home/<username>/containerised-opensbli/OPS/ops/
    export OPS_TRANSLATOR=/home/<username>/containerised-opensbli/OPS/ops_translator/ops-translator/
    export OPS_COMPILER=gnu
    export MPI_INSTALL_PATH=/usr/
    export HDF5_INSTALL_PATH=/usr/lib/x86_64-linux-gnu/hdf5/openmpi/
    export CUDA_INSTALL_PATH=/usr/local/cuda
    export USE_HDF5=1
%runscript
    exec "$@"
```

Build the Apptainer and enter a Shell 

```sh
apptainer build environment.sif opensbli_ops_recipe.def
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
make cuda mpi_cuda opencl mpi_opencl
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

python3.8 -m venv $OPS_INSTALL_PATH/../ops_translator/ops_venv

source $OPS_INSTALL_PATH/../ops_translator/ops_venv/bin/activate

python3.8 -m pip install -r $OPS_INSTALL_PATH/../ops_translator/requirements.txt

python3.8 -m pip install --force-reinstall libclang==16.0.6

echo "run \"source $OPS_INSTALL_PATH/../ops_translator/ops_venv/bin/activate\""
```


## Python 3.7 Environment

Create a python environment to install all the necessary packages

```sh
python3.7 -m venv venv3Dot7

source venv3Dot7/bin/activate

python3.7 -m pip install scipy numpy h5py matplotlib
python3.7 -m pip install sympy==1.1
```

## OpenSBLI

Run clone_and_build_opensbli.sh
```sh
#!/bin/bash
git clone https://github.com/rfj82982/opensbli.git

cd opensbli

git checkout Training_2025_09
```

Export PYTHONPATH variable

```sh
export PYTHONPATH=$PYTHONPATH:/home/<username>/containerised-opensbli/opensbli
```

Run an app

```sh
cd opensbli
cd apps
cd euler_wave

python3.7 euler_wave.py
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
python3.8 $OPS_TRANSLATOR/ops.py opensbli.cpp
```

Copy the Makefile into the directory and build your target executable (mpi/cuda/openmp/etc)

```sh
cp ../Makefile ./
make opensbli_mpi
```

Run the executable
```sh
mpirun -np 4 ./opensbli_mpi
```
