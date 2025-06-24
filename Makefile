MAX_CORES ?= 50
TIMEOUT ?= 20m

YQ_MERGE=yq eval-all 'select(fileIndex==1) * select(fileIndex==0)'
YQ_REPOS=yq '.stages[].modules[] | .id + ": " + .repository.url + "@" + .repository.commit'

OB_CMD=ob run benchmark --continue-on-error --local --cores ${MAX_CORES} --task-timeout ${TIMEOUT} --yes

BASE=base.yml
CONDA=conda
ORAS=oras
ENVS=envmodules

.SILENT: generate

generate:
	${YQ_MERGE} overrides/${CONDA}.yml ${BASE} > Clustering_${CONDA}.yml
	${YQ_MERGE} overrides/${ORAS}.yml ${BASE} > Clustering_${ORAS}.yml
	${YQ_MERGE} overrides/${ENVS}.yml ${BASE} > Clustering_${ENVS}.yml


all: run_with_default_conda run_with_unpinned_oras run_with_default_envs # knit_report

run_with_default_conda:
	@OUT=out_${CONDA}-$$(date +'%Y%m%d%H%M') && \
	${OB_CMD} -b Clustering_${CONDA}.yml --out-dir $$OUT && \
	cp Clustering_${CONDA}.yml $$OUT

run_with_unpinned_oras:
	@OUT=out_apptainer-$$(date +'%Y%m%d%H%M') && \
	${OB_CMD} -b Clustering_${ORAS}.yml --out-dir $$OUT && \
	cp Clustering_${ORAS}.yml $$OUT

run_with_default_envs:
	@OUT=out_${ENVS}-$$(date +'%Y%m%d%H%M') && \
	${OB_CMD} -b Clustering_${ENVS}.yml --out-dir $$OUT && \
	cp Clustering_${ENVS}.yml $$OUT
