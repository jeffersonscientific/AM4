#!/bin/bash
#
#SBATCH -n 8
#SBATCH --output=compile_am4_%j.out
#SBATCH --error=compile_am4_%j.err
#
module purge
#
COMP="intel19"
MPI="openmpi3"
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
        module load impi_19/
        MPI="impi19"
        #PREREQ_MPI='impi/2019.'
        PREREQ_MPI="atleast(\"impi\", \"2019.6.166\")"
        ;;
    "openmpi3")
        module load openmpi_3/
        MPI="openmpi3"
        #PREREQ_MPI='impi/2019.'
        PREREQ_MPI="atleast(\"openmpi3\", \"3.1.0\")"
        ;;
    "mpich3")
        module load mpich_3/
        MPI='mpich3'
        PREREQ_MPI="atleast(\"mpich\", \"3.3.1\")"
        ;;
    *)
        module load openmpi_3/
        MPI="openmpi3"
        #PREREQ_MPI='impi/2019.'
        PREREQ_MPI="atleast(\"openmpi3\", \"3.1.0\")"
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
MKMF_TEMPLATE="templates/intel_mazama.mk"
MAKEFILE="Makefile_Mazama"
#
echo "Stuff: "
echo ${COMP_MPI}
echo ${PREREQ_MPI}
#exit 1
#
DO_COMPILE=1
WRITE_MODULE=1
VER="1.0.0"
SW_TARGET="/share/cees/software/gfdl_am4/${COMP_MPI}/${VER}"
MODULE_TARGET="/share/cees/modules/moduledeps/${COMP}-${MPI}/gfdl_am4"
#
# The executable: This is a little sloppy. The executable name is specified inthe Makefile, and could/should maybe
#  be modified. It looks like this binary is specific to an experiment, or something... but for now, as a mater of
#  deference, we'll leave it as is. Note we're not really setting it here; but if we get it wrong, the compile will
#  break (intentionally). We could, for example, name each compiled exe. for its compiler/MPI. but do we need to?
AM4_EXE="fms_cm4p12_warsaw.x"
#
# this shell script, part of mkmf, will create the file path_names
list_paths ${SRC_PATH}
#

#mkmf -t ${MKMF_TEMPLATE} -p fms.x -c"-Duse_libMPI -Duse_netCDF" path_names ${NETCDF_INC} ${NETCDF_FORTRAN_INC} ${HDF5_DIR}/include ${MPI_DIR}/include /usr/local/include ${NETCDF_LIB} ${NETCDF_FORTRAN_LIB} ${HDF5_DIR}/lib ${MPI_DIR}/lib /usr/local/lig /usr/local/lib64
#
#  of the make components.
if [[ -z ${SLURM_NTASKS} ]]; then
    NPROCS=${SLURM_NTASKS}
else
    NPROC=8
fi

# we seem to be tripping over ourselves, so let's explicitly do this one component at a time. Block it out here, then
#  write a loop.
#
#make -f Makefile_Mazama clean

#make -j${NPROC} -f Makefile_Mazama fms/libfms.a
#make -j${NPROC} -f Makefile_Mazama atmos_phys/libatmos_phys.a
## requires the two above:
#make -j${NPROC} -f Makefile_Mazama atmos_dyn/libatmos_dyn.a
#
## MOM6 is currently unable to run with OpenMP enabled
#make -j${NPROC} -f Makefile_Mazama mom6/libmom6.a
#make -j${NPROC} -f Makefile_Mazama ice_sis/libice_sis.a
#
#make -j1 -f Makefile_Mazama land_lad2/libland_lad2.a


##
#make -j${NPROC} -f Makefile_Mazama coupler/libcoupler.a
#make -j${NPROC} -f Makefile_Mazama fms_cm4p12_warsaw.x
#
if [[ ${DO_COMPILE} -eq 1 ]]; then
    # looks like it is not uncommon to break on certain components, so loop over each component
    # and try the make:
    for target in clean fms/libfms.a atmos_phys/libatmos_phys.a atmos_dyn/libatmos_dyn.a mom6/libmom6.a ice_sis/libice_sis.a  land_lad2/libland_lad2.a coupler/libcoupler.a ${AM4_EXE}
    do
        make -j${NPROCS} -f ${MAKEFILE} $target
        if [[ ! $? -eq 0 ]]; then
            echo "Failed building at: ${target}"
            exit 1
        fi
    done
    #
    # Compile diagnostics:
    echo " look for the target *.a and .x files: "
    for fl in fms/libfms.a atmos_phys/libatmos_phys.a atmos_dyn/libatmos_dyn.a mom6/libmom6.a ice_sis/libice_sis.a  land_lad2/libland_lad2.a coupler/libcoupler.a fms_cm4p12_warsaw.x
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
prereq("${PREREQ_COMP}")
prereq("${PREREQ_MPI}")
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

