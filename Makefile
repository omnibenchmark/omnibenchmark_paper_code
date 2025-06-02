MAX_CORES ?= 12

# with continue on error (-k)
OB_CMD=ob run benchmark -k --local --cores ${MAX_CORES} --yes

# prepare_apptainer_env:
# 	cd envs && bash build_singularity.sh

run_with_apptainer_unpinned_oras:
	 ${OB_CMD} -b Clustering_oras.yml
	 mv out out_singularity_$(shell date +'%Y%m%d%H%M')
run_with_conda:
	 ${OB_CMD} -b Clustering_conda.yml
	 mv out out_conda_$(shell date +'%Y%m%d%H%M')

## knit_marks_report:
