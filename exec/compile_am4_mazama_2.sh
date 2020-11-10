#!/bin/bash
#
#SBATCH -n 8
#SBATCH --output=compile_am4_%j.out
#SBATCH --error=compile_am4_%j.err
#
# optionally, clone the repo and navigate to that directory:
#git clone --recursive git@github.com:jeffersonscientific/AM4.git
#cd AM4/exec
#
module purge
#
COMP="intel19"
MPI="mpich3"
#
if [[ $1 != "" ]]; then
    COMP=$1
fi
if [[  $2 != "" ]]; then
    MPI=$2
fi
DO_CLEAN=1
if [[ $3 != "" ]]; then
    DO_CLEAN=$3
fi
#
case ${COMP} in
"intel19")
    echo "${COMP}/Intel configuration"
    module load intel/19
    COMP="intel19"
    #
    PREREQ_COMP="atleast(\"intel\", \"19.1.0.166\")"
    #PREREQ_COMP="intel/19.1.0.166"
    ;;
"gnu8")
    echo "${COMP}/gnu8 configuration"
    module load gnu/8
    #PREREQ_COMP="gnu8/8.3.0"
    PREREQ_COMP="atleast(\"gnu8\", \"8.3.0\")"
    ;;
*)
    echo "Else Compile config (${COMP})"
    module load intel/19
    COMP="intel19"
    PREREQ_COMP="atleast(\"intel\", \"19.1.0.166\")"
    ;;
esac
#
case ${MPI} in
    "impi19")
        module load impi_19/2019.6.166
        MPI="impi19"
        #PREREQ_MPI='impi/2019.'
        PREREQ_MPI="atleast(\"impi\", \"2019.6.166\")"
        #
        MPI_FFLAGS="-I${MPI_DIR}/include -I${MPI_DIR}/lib "
        MPI_CFLAGS="-I${MPI_DIR}/include "
        # guessing a bit here. not sure there is a libmpi.* in
        MPI_LDFLAGS="-L${MPI_DIR}/lib -lmpi -lmpifort"
        ;;
    "openmpi3")
        module load openmpi_3/
        MPI="openmpi3"
        #PREREQ_MPI='impi/2019.'
        PREREQ_MPI="atleast(\"openmpi3\", \"3.1.0\")"
        #
        MPI_FFLAGS="`pkg-config --cflags ompi-fort` "
        MPI_CFLAGS="`pkg-config --cflags ompi` "
        MPI_LDFLAGS="`pkg-config --libs ompi-fort` "
        ;;
    "mpich3")
        module load mpich_3/
        MPI='mpich3'
        PREREQ_MPI="atleast(\"mpich\", \"3.3.1\")"
        #
        MPI_FFLAGS="`pkg-config --cflags mpich` -I${MPI_DIR}/lib "
        MPI_CFLAGS="`pkg-config --cflags mpich`"
        MPI_LDFLAGS="`pkg-config --libs mpich` "
        ;;
    *)
        module load openmpi_3/
        MPI="openmpi3"
        #PREREQ_MPI='impi/2019.'
        PREREQ_MPI="atleast(\"openmpi3\", \"3.1.0\")"
        #
        MPI_FFLAGS="`pkg-config --cflags ompi-fort` "
        MPI_CFLAGS="`pkg-config --cflags ompi` "
        MPI_LDFLAGS="`pkg-config --libs ompi-fort` "
        #MPI_FFLAGS="-I${MPI_DIR}/include $-I{MPI_DIR}/lib "
        #MPI_CFLAGS="-I${MPI_DIR}/include "
        ## guessing a bit here...
        #MPI_LDFLAGS="-L${MPI_DIR}/lib -lmpi "
        ;;
esac
#
COMP_MPI=${COMP}_${MPI}
#
module load netcdf/
module load netcdf-fortran/
#
# compile stuff:
module load cmake/
module load autotools/
module load mkmf/
#
# how the F does mkmf (really) work?
# We should be in the exec dir:
SRC_PATH=`cd ..;pwd`/src
#BUILD_PATH="`pwd`/build_${COMP_MPI}"
BUILD_PATH="`cd ..;pwd`/build_${COMP_MPI}_prod"
EXEC_SRC=`pwd`
MKMF_TEMPLATE="templates/intel_mazama.mk"
MAKEFILE="Makefile_Mazama_2"
#
#MKMF_TEMPLATE_SRC="`pwd`/templates/intel_mazama.mk"
#MAKEFILE_SRC="`pwd`/Makefile_Mazama"
#
#MKMF_TEMPLATE="${BUILD_PATH}/exec/intel_mazama.mk"
#MAKEFILE="${BUILD_PATH}/exec/Makefile_Mazama"
#
echo "* ***: ${MAKEFILE}, ${MKMF_TEMPLATE}, ${EXEC_SRC}, ${BUILD_PATH}"
#exit 1
#
if [[ ! -d ${BUILD_PATH} ]]; then
    mkdir -p ${BUILD_PATH}
fi
#cp ${MKMF_TEMPLATE_SRC} ${MKMF_TEMPLATE}
#cp ${MAKEFILE_SRC} ${MAKEFILE}
#cd ${BUILD_PATH}
cp -r ${EXEC_SRC} ${BUILD_PATH}/
cd ${BUILD_PATH}/exec
export BUILD_PATH=${BUILD_PATH}
export SRC_PATH=${SRC_PATH}
#
echo "in exec: `pwd`"
ls
#
# Linker and single processor cc compiler (if we have to constript the SPP compilers to MPI)
LD=$FC
CC_pp=${CC}
#
FC=${MPIFC}
CC=${MPICC}
CXCC=${MPICXX}
LD=${MPIFC}
#
#echo "*** *** `which $MPICXX`"
#
echo "Stuff: "
echo ${COMP_MPI}
echo ${PREREQ_MPI}
module list
#
echo "Compilers: "
for cc in ${FC} ${CC} ${CXX} ${LD} ${MPIFC} ${MPICC} ${MPICXX}
do
    echo "** `which $cc`"
done
#
#exit 1
#
[[ -z ${DO_COMPILE} ]] && DO_COMPILE=1
WRITE_MODULE=1
#VER="1.0.0"
VER="1.0.1"
TARGET_ROOT="/share/cees"
#TARGET_ROOT="/scratch/${USER}/.local"
SW_TARGET="${TARGET_ROOT}/software/gfdl_am4/${COMP_MPI}/${VER}"
MODULE_TARGET="${TARGET_ROOT}/modules/moduledeps/${COMP}-${MPI}/gfdl_am4"
#
# The executable: This is a little sloppy. The executable name is specified inthe Makefile, and could/should maybe
#  be modified. It looks like this binary is specific to an experiment, or something... but for now, as a mater of
#  deference, we'll leave it as is. Note we're not really setting it here; but if we get it wrong, the compile will
#  break (intentionally). We could, for example, name each compiled exe. for its compiler/MPI. but do we need to?
export AM4_EXE="fms_cm4p12_warsaw.x"
#
# this shell script, part of mkmf, creates the file path_names
list_paths ${SRC_PATH}
#
export MPI_FFLAGS=${MPI_FFLAGS}
export MPI_CFLAGS=${MPI_CFLAGS}
export MPI_LDFLAGS=${MPI_LDFLAGS}
# now, set up all the _FLAGS variables here, instead of the template. see if we can get rid of the template...
export NETCDF_FLAGS=`nf-config --cflags`
export NETCDF_LIBS=`nf-config --flibs`
#
#mkmf -t ${MKMF_TEMPLATE} -p fms.x -c"-Duse_libMPI -Duse_netCDF" path_names ${NETCDF_INC} ${NETCDF_FORTRAN_INC} ${HDF5_DIR}/include ${MPI_DIR}/include /usr/local/include ${NETCDF_LIB} ${NETCDF_FORTRAN_LIB} ${HDF5_DIR}/lib ${MPI_DIR}/lib /usr/local/lig /usr/local/lib64
#
#  of the make components.
if [[ -z ${SLURM_NTASKS} ]]; then
    NPROCS=${SLURM_NTASKS}
else
    NPROC=12
fi

# we seem to be tripping over ourselves, so let's explicitly do this one component at a time. Block it out here, then
#  write a loop.
#
echo "** DEBUG: exiting. STatus:"
echo "Path: `pwd`"
echo "Makefile: ${MAKEFILE}"
echo "ls: `ls`"
#exit 1

if [[ ${DO_COMPILE} -eq 1 ]]; then
    # looks like it is not uncommon to break on certain components, so loop over each component
    # and try the make:
    if [[ ${DO_CLEAN} -eq 1 ]]; then
        make -j${NPROCS} -f ${MAKEFILE} clean
        for pth in mom6 land_lad2 ice_sis fms coupler atmos_phys atmos_dyn
        do
            rm ${pth}/*.o
            rm ${pth}/*.mod
        done
    fi
    #make -j${NPROCS} -f ${MAKEFILE}
    #
    for target in clean fms/libfms.a atmos_phys/libatmos_phys.a atmos_dyn/libatmos_dyn.a mom6/libmom6.a ice_sis/libice_sis.a coupler/libcoupler.a land_lad2/libland_lad2.a coupler/libcoupler.a ${AM4_EXE}
    do
	echo "\n** Compiling component: $target"
        make -j${NPROCS} -f ${MAKEFILE} $target
        if [[ ! $? -eq 0 ]]; then
            echo "Failed building at: ${target}"
            exit 1
        fi
    done
    if [[ $? -eq 0 ]]; then
        echo "broke on makefile"
    fi
    #
    # Compile diagnostics:
    echo " look for the target *.a and .x files: "
    for fl in fms/libfms.a atmos_phys/libatmos_phys.a atmos_dyn/libatmos_dyn.a mom6/libmom6.a ice_sis/libice_sis.a  land_lad2/libland_lad2.a coupler/libcoupler.a ${AM4_EXE}
    do
    if [[ "${fl}" = `ls $fl` ]]; then STAT="OK"; else STAT"not-OK"; fi
    echo "built file $fl::  `ls $fl` :: ${STAT}"
   done
fi
#
# now, copy executable to target. Anything else need to get copied?
if [[ ! -d ${SW_TARGET}/bin ]]; then
    mkdir -p ${SW_TARGET}/bin
fi
# anything else?
cp ${AM4_EXE} ${SW_TARGET}/bin
#
# Write Module:
echo "module path: ${MODULE_TARGET}"
if [[ ! -d ${MODULE_TARGET} ]]; then mkdir -p ${MODULE_TARGET}; fi
#
# I think the conditional syntax might just not work (well) when we do a write-script, so be careful with this.
if [[ WRITE_MODULE -eq 1 ]]; then

cat > ${MODULE_TARGET}/${VER}.lua <<EOF
-- -*- lua
--
prereq(${PREREQ_COMP})
prereq(${PREREQ_MPI})
--
depends_on("netcdf/")
depends_on("netcdf-fortran/")
--
whatis("Name: AM4-GFDL model, built from ${COMP_MPI} toolchain.")
--
VER="${VER}"
SW_DIR="${SW_TARGET}"
BIN_DIR=pathJoin(SW_DIR, "bin")
--
pushenv("AM4_GFDL_DIR", SW_DIR)
pushenv("AM4_GFDL_BIN", BIN_DIR)
pushenv("AM4_GFDL_EXE", "${AM4_EXE}")
--
prepend_path("PATH", BIN_DIR)
--
EOF

fi

