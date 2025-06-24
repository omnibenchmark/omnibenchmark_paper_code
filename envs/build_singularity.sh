#!/bin/bash
CMD=singularity
BUILD='build --fakeroot'
$CMD ${BUILD} clustbench.sif clustbench_singularity.def
$CMD ${BUILD} fcps.sif fcps_singularity.def
