#!/bin/bash

# OPS Library
git clone https://github.com/OP-DSL/OPS.git

cd OPS/ops/c/
make seq mpi hdf5_seq hdf5_mpi
make cuda mpi_cuda opencl mpi_opencl
