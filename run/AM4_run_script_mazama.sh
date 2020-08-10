#!/bin/bash
#
#SBATCH --ntasks=32
#SBATCH --output=AM4_out_%j.out
#SBATCH --error=AM4_OUT_$j.err
#
module purge
module load intel/19
module load openmpi_3/
#module load mpich_3/
module load gfdl_am4/1.0.0
#
# Sample run script to run the am4p0 experiment
#
# Getting the data:
# see:
# https://github.com/NOAA-GFDL/AM4#obtaining-the-input-data
# data:
# wget ftp://nomads.gfdl.noaa.gov/users/Ming.Zhao/AM4Documentation/GFDL-AM4.0/inputData/AM4_run.tar.gz
# checksums:
# wget ftp://nomads.gfdl.noaa.gov/users/Ming.Zhao/AM4Documentation/GFDL-AM4.0/inputData/AM4_run.tar.gz.sha256
# wget ftp://nomads.gfdl.noaa.gov/users/Ming.Zhao/AM4Documentation/GFDL-AM4.0/inputData/AM4_run.tar.gz.sig
# sha256sum -c AM4_run.tar.gz.sha256
#gpg --verify AM4_run.tar.gz.sig
#
# and you'll need to make some adjustments to inpuyt.nml. Instructions in README file:
# wget ftp://nomads.gfdl.noaa.gov/users/Ming.Zhao/AM4Documentation/GFDL-AM4.0/inputData/README.AM4_run
# NOTE: these are ftp links, which some browsers (Safari) might not permit access to. if you use a browser and get a "can't find address,"
#  or something, it might be a security exception.

# ***********************************************************************
# Modify the settings in this section to match your system's environment
# and the directory locations to the EXECUTABLE, input data, initial
# conditions data and work directory.

# Name of the mpiexec program to use
#mpiexec_prog=aprun
MPI_EXEC="mpirun"
#
# Option used to specify number of MPI process to run (usually -n or -np)
MPI_EXEC_NOPT="-np"
# Option used to specify number of OpenMP threads to run
MPI_EXEC_TOPT="-d"

# Where to perform the run
# If using AM4.tar, this should be AM4_run
#w=/path/to/run/dir
WORK_DIR="`pwd`/workdir"
#
# Input Data:
INPUT_DATA_ROOT="`cd ..;pwd`/data"
INPUT_DATA_PATH="${INPUT_DATA_ROOT}/AM4_run"
INPUT_DATA_TAR="${INPUT_DATA_ROOT}/AM4_run.tar.gz"
#
# right now, treat these as either-or... but we might just simplify our script by
# always copying and extracting the .tar...
DO_TAR=0
DO_DATA_COPY=0
#
# Location of EXECUTABLE (run with $mpiexec_prog)
#EXECUTABLE=/path/to/EXECUTABLE/fms_cm4p12_warsaw.x
EXECUTABLE=$AM4_GFDL_BIN/${AM4_GFDL_EXE}
#
#
## Run parameters
#total_npes is the number of cores to run on, omp_threads is the number of
# openMP threads
# if you can define cores/node or cpu/task?, it will probably be beneficial to set omp_threads > 1
# ie, i think something like --ntasks=16 --cpu-per-task=2 should be like:
# total_npes=32
# omp_threads=1
#
# factory default?
#total_npes=432
# TODO: work out the arithmetic and Env. Variables for this.
if [[ ! -z ${SLURM_NTASKS} ]]; then
	TOTAL_NPES=${SLURM_NTASKS}
    echo "setting TOTAL_NPES FROM SLURM: ${SLURM_NTASKS}/${TOTAL_NPES}"
else
	TOTAL_NPES=32
    echo "setting TOTAL_NPES FROM default: ${TOTAL_NPES}"
fi
#
OMP_THREADS=1

# End of configuration section
# ***********************************************************************

# Enviornment settings for run
export KMP_STACKSIZE=512m
export NC_BLKSZ=1M
export F_UFMTENDIAN=big

# Remember CWD
initialDir=`pwd`

# check of required programs
#if ! hash tar 2> /dev/null
#then
#  echo "ERROR: Unable to find \`tar\` in PATH." 1>&2
#  echo "ERROR: Halting script." 1>&2
#fi
#
if ! hash ${MPI_EXEC} 2> /dev/null
then
  echo "ERROR: Unable to find \`${MPI_EXEC}\` in PATH." 1>&2
  echo "ERROR: Halting script." 1>&2
fi


# Verify work directory exists, if not create it.
# NOTE: the workflow for $WORK_DIR is really not one size fits all. Users will probably
#  want to design this script for their own purposes, queue properties, etc.
#  For our initial test purposes,let's leave all these checks in place but we'll do a
#  drocanian, nuclear option setup here:
#
if [[ ${DO_COPY} -eq 1 ]]; then
    rm -rf ${WORK_DIR}
    mkdir -p ${WORK_DIR}
    cp -r ${INPUT_DATA_PATH}/* ${WORK_DIR}/
fi
#
#exit 1
#
if [ ! -e ${WORK_DIR} ]
then
  mkdir -p ${WORK_DIR}
  if [ $? -ne 0 ]
  then
    echo "ERROR: Unable to create work directory \"${WORK_DIR}\"." 1>&2
    echo "ERROR: Halting script." 1>&2
    exit 1
  fi
elif [ ! -d ${WORK_DIR} ]
then
  echo "ERROR: Work directory \"${WORK_DIR}\" is not a directory." 1>&2
  echo "ERROR: Halting script." 1>&2
  exit 1
fi

# Check if work directory is empty, warn if not
if [ $(ls -1qA ${WORK_DIR} | wc -l) -gt 0 ]
then
  echo "NOTE: Work directory \"${WORK_DIR}\" is not empty." 1>&2
  echo "NOTE: Data in \"${WORK_DIR}\" will be overwritten." 1>&2
fi

# Enter working directory, and setup the directory
cd ${WORK_DIR}
if [ $? -ne 0 ]
then
  echo "ERROR: Unable \`cd\` into work directory \"${WORK_DIR}\"." 1>&2
  echo "ERROR: Halting script." 1>&2
  exit 1
fi

# Create RESTART directory, if it doesn't eixt.
if [ ! -e RESTART ]
then
  mkdir RESTART
  if [ $? -ne 0 ]
  then
    echo "ERROR: Unable to create directory \"${WORK_DIR}/RESTART\"." 1>&2
    echo "ERROR: Halting script." 1>&2
    exit 1
  fi
elif [ ! -d RESTART ]
then
  echo "ERROR: Directory \"${WORK_DIR}/RESTART\" is not a directory." 1>&2
  echo "ERROR: Halting script." 1>&2
  exit 1
elif [ $(ls -1qA ${WORK_DIR}/RESTART | wc -l) -gt 0 ]
then
  # TODO: this would be a good place to automate restarts, aka (but be sure the full syntax is complete and correct):
  # mv RESTART/* INPUT/
  echo "WARNING: Directory \"${WORK_DIR}/RESTART\" is not empty." 1>&2
  echo "WARNING: Contents will be overwritten." 1>&2
fi

## Use this section if you are untar'ing the input data ##
## Not required if using AM4.tar out of the box          ##
## Extract the input data
#tar xf ${inputDataTar}
#if [ $? -ne 0 ]
#then
#  echo "ERROR: Unable to extract data from \"${inputDataTar}\"." 1>&2
#  echo "ERROR: Halting script." 1>&2
#fi
#
#tar xf ${initCondTar}
#if [ $? -ne 0 ]
#then
#  echo "ERROR: Unable to extract data from \"${initCondTar}\"." 1>&2
#  echo "ERROR: Halting script." 1>&2
#fi
#

# Run the model
ulimit -s unlimited
echo "MPI Execute command: "
#${mpiexec_prog} ${mpiexec_nopt} ${total_npes} ${mpiexec_topt} ${omp_threads} ${EXECUTABLE} 2>&1 | tee ${WORK_DIR}/fms.out
echo ${MPI_EXEC} ${MPI_EXEC_NOPT} ${TOTAL_NPES} ${MPI_EXEC_TOPT} ${OMP_THREADS} ${EXECUTABLE}
#exit 1
#${MPI_EXEC} ${MPI_EXEC_NOPT} ${TOTAL_NPES} ${MPI_EXEC_TOPT} ${OMP_THREADS} ${EXECUTABLE}
${MPI_EXEC} ${MPI_EXEC_NOPT} ${TOTAL_NPES} ${EXECUTABLE}
#
if [ $? -ne 0 ]
then
  echo "ERROR: Run failed." 1>&2
  echo "ERROR: Output from run in \"${WORK_DIR}/fms.out\"." 1>&2
  exit 1
fi

# Return to the initial directory
cd ${initialDir}
