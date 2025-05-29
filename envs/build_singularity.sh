#!/bin/sh
# Builds singularity images.
# Installation guide: check https://apptainer.org/docs/user/latest/quick_start.html#installation
# Additionally, you will need:
# apt install fakeroot uidmap
CMD=singularity
BUILD='build --fakeroot'
# enable this if you want to compare with the custom python compilation
# $CMD ${BUILD} clustbench-optimized.sif clustbench_apptainer_optimized.def
$CMD ${BUILD} clustbench.sif clustbench_apptainer_vanillapy.def
$CMD ${BUILD} fcps.sif fcps.def
