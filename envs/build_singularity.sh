#!/bin/bash

singularity build clustbench.sif clustbench_singularity.def

singularity build fcps.sif fcps_singularity.def
