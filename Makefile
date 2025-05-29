MAX_CORES ?= 10
TIMEOUT ?= 4h
YQ_MERGE=yq eval-all 'select(fileIndex==1) * select(fileIndex==0)'
YQ_REPOS=yq '.stages[].modules[] | .id + ": " + .repository.url + "@" + .repository.commit'

# by default, we want to run all snakemake rules even if there are failures (-k)
OB_CMD=ob run benchmark -k --local --task-timeout ${TIMEOUT} --cores ${MAX_CORES} --yes

APPTR = apptainer
APPTV = apptainer_vanilla
APPTO = apptainer_optimized
CONDA = conda
ENVMD = envmodules

BASE       = base.yml
BASE_SHORT = smoketest/base.yml

# Install dependencies to generate files (requires go in the system)
deps:
	go install github.com/mikefarah/yq/v4@latest

# Generate all the yaml files from base + overrides
.SILENT: generate
generate:
	${YQ_MERGE} overrides/${APPTR}.yml ${BASE} > Clustering_${APPTR}.yml
	${YQ_MERGE} overrides/${APPTV}.yml ${BASE} > Clustering_${APPTV}.yml
	${YQ_MERGE} overrides/${APPTO}.yml ${BASE} > Clustering_${APPTO}.yml
	${YQ_MERGE} overrides/${CONDA}.yml ${BASE} > Clustering_${CONDA}.yml
	${YQ_MERGE} overrides/${ENVMD}.yml ${BASE} > Clustering_${ENVMD}.yml
	${YQ_MERGE} overrides/${APPTR}.yml ${BASE_SHORT} > Clustering_${APPTR}_short.yml
	${YQ_MERGE} overrides/${APPTV}.yml ${BASE_SHORT} > Clustering_${APPTV}_short.yml
	${YQ_MERGE} overrides/${APPTO}.yml ${BASE_SHORT} > Clustering_${APPTO}_short.yml
	${YQ_MERGE} overrides/${CONDA}.yml ${BASE_SHORT} > Clustering_${CONDA}_short.yml
	${YQ_MERGE} overrides/${ENVMD}.yml ${BASE_SHORT} > Clustering_${ENVMD}_short.yml
	echo "[+] The following files have been generated:"
	ls Clustering_*.yml
	echo "[+] You can use 'make clean' to delete them"

clean:
	rm Clustering_*.yml

prepare_apptainer_env:
	cd envs && ./build_singularity.sh
prepare_envmodules_env:
	cd envs && eb clustbench.eb --robot
	cd envs && eb fcps.eb --robot
	cd envs && eb rmarkdown.eb --robot

# short versions, to debug runs & environments
run_with_apptainer_backend_short:
	 ${OB_CMD} -b Clustering_${APPTR}_short.yml
	 mv out out_${APPTR}_short-$(shell date +'%Y%m%d%H%M')
run_with_apptainer_backend_vanilla_short:
	 ${OB_CMD} -b Clustering_${APPTV}_short.yml
	 mv out out_${APPTV}_short-$(shell date +'%Y%m%d%H%M')
run_with_conda_backend_short:
	 ${OB_CMD} -b Clustering_${CONDA}_short.yml
	 mv out out_${CONDA}_short-$(shell date +'%Y%m%d%H%M')
run_with_envmodules_backend_short:
	 ${OB_CMD} -b Clustering_${ENVMD}_short.yml
	 mv out out_${ENVMD}_short-$(shell date +'%Y%m%d%H%M')

# full versions (expect hours)
run_with_apptainer_backend:
	 ${OB_CMD} -b Clustering_${APPTR}.yml
	 mv out out_${APPTR}-$(shell date +'%Y%m%d%H%M')
run_with_apptainer_backend_vanilla:
	 ${OB_CMD} -b Clustering_${APPTV}.yml
	 mv out out_${APPTV}-$(shell date +'%Y%m%d%H%M')
run_with_conda_backend:
	 ${OB_CMD} -b Clustering_${CONDA}.yml
	 mv out out_${CONDA}-$(shell date +'%Y%m%d%H%M')
run_with_envmodules_backend:
	 ${OB_CMD} -b Clustering_${ENVMD}.yml
	 mv out out_${ENVMD}-$(shell date +'%Y%m%d%H%M')

extract_modules:
	@${YQ_REPOS} base.yml
