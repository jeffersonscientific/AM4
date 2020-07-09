#!/bin/bash
#
#SBATCH -n 1
#SBATCH --output=compile_am4_%j.out
#SBATCH --error=compile_am4_%j.err
#
module purge
#
module load intel/19
module load impi_19/
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
# this shell script, part of mkmf, will create the file path_names
list_paths ${SRC_PATH}
#

#mkmf -t ${MKMF_TEMPLATE} -p fms.x -c"-Duse_libMPI -Duse_netCDF" path_names ${NETCDF_INC} ${NETCDF_FORTRAN_INC} ${HDF5_DIR}/include ${MPI_DIR}/include /usr/local/include ${NETCDF_LIB} ${NETCDF_FORTRAN_LIB} ${HDF5_DIR}/lib ${MPI_DIR}/lib /usr/local/lig /usr/local/lib64
#TODO: consider adding LDFLAGS to FFLAGS (or something) so HDF5, etc. are linked properly in some??
#  of the make components.
NPROC=8
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

for target in clean fms/libfms.a atmos_phys/libatmos_phys.a atmos_dyn/libatmos_dyn.a mom6/libmom6.a ice_sis/libice_sis.a  land_lad2/libland_lad2.a coupler/libcoupler.a fms_cm4p12_warsaw.x
do
    make -j${NPROCS} -f ${MAKEFILE} $target
    if [[ ! $? -eq 0 ]]; then
        echo "Failed building at: ${target}"
        exit 1
    fi
done
#
# Compile diagnostics:
echo " look for *.a and .x files: "
for fl in fms/libfms.a atmos_phys/libatmos_phys.a atmos_dyn/libatmos_dyn.a mom6/libmom6.a ice_sis/libice_sis.a  land_lad2/libland_lad2.a coupler/libcoupler.a fms_cm4p12_warsaw.x
do
if [[ "${fl}" = `ls $fl` ]]; then STAT="OK"; else STAT"not-OK"; fi
echo "built file $fl::  `ls $fl` :: ${STAT}"
done
#
# now, copy executable to target. Anything else need to get copied?
