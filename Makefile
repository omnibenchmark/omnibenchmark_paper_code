# ============================================================
# Seed and result stability Makefile
#
# Run with `make`
#
# Key features:
# - seeds: benchmarks are repeated with multiple random seeds
#   (2, 54, 546, 744, 1443) to ensure reproducibility.
# - runs: for each seed, three independent runs are
#   executed to capture variability in performance.
# - output dirs: results are stored in directories
#   named according to backend, seed, and run number.
#
# Targets:
#   all             clone repos, run benchmarks, knit reports
#   run_conda       run conda backend with seeds + repeats
#   run_oras        run oras backend with seeds + repeats
#   run_envs        run envmodules backend with seeds + repeats
#   knit_report     generate RMarkdown reports and an aggregated CSV - not fully tested
#
# Environment:
# - MAX_CORES controls num concurrent rules
# - EASYBUILD_PREFIX needs to be tuned to access the envmodules built extending EESSI <--------------!!!!
#    see: https://github.com/omnibenchmark/clustering_example/pull/43
#
# ============================================================


MAX_CORES ?= 40

# EasyBuild installation prefix (imallona; edit accordingly) ## <------------------------------------!!!!
EASYBUILD_PREFIX ?= /data/imallona/.local/easybuild
export EASYBUILD_PREFIX

# omnibenchmark command template
OB_CMD = ob run --cores ${MAX_CORES} --continue-on-error --task-timeout 10min --yes

# actual benchmark plan repository - to be pinned (the commit/tag)
CLUSTERING_REPO   = https://github.com/omnibenchmark/clustering_example
CLUSTERING_BRANCH = update-to-0.4-full
CLUSTERING_DIR	  = clustering_example

# legacy reports in the wrong repository; to be moved to this one
REPORTS_REPO   = https://github.com/imallona/clustering_report
REPORTS_BRANCH = 040
REPORTS_DIR    = clustering_report

## seeds to explore
SEEDS := 20 54

## repeated runs per seed
RUNS := 1 #2

all: clone_yamls clone_reports run_conda run_oras run_envs knit_report

clean:
	/bin/rm -rf results/ clustering_example/ clustering_report/ .omnibenchmark/ .snakemake/

find:
	find . | grep clustbench.scores.gz | wc -l

# clone the clustering_example repo if not already present
clone_yamls:
	@if [ ! -d "$(CLUSTERING_DIR)" ]; then \
		echo "Cloning clustering_example repo..."; \
		git clone --branch ${CLUSTERING_BRANCH} $(CLUSTERING_REPO); \
	else \
		echo "clustering_example repo already present, pulling latest..."; \
		cd $(CLUSTERING_DIR) && git fetch  && git checkout ${CLUSTERING_BRANCH} && git pull; \
	fi

# clone the clustering_report repo if not already present
clone_reports:
	@if [ ! -d "$(REPORTS_DIR)" ]; then \
		echo "Cloning clustering_report repo (branch mark)..."; \
		git clone --branch $(REPORTS_BRANCH) $(REPORTS_REPO) $(REPORTS_DIR); \
	else \
		echo "clustering_report repo already present, pulling latest..."; \
		cd $(REPORTS_DIR) && git pull; \
	fi

run_conda: clone_yamls
	mkdir -p results
	@for seed in $(SEEDS); do \
		echo "Running conda benchmark with seed $$seed..."; \
		cp $(CLUSTERING_DIR)/Clustering_conda.yml $(CLUSTERING_DIR)/Clustering_conda_tmp.yml; \
		sed -i "s/seed: 2/seed: $$seed/" $(CLUSTERING_DIR)/Clustering_conda_tmp.yml; \
		for i in $(RUNS); do \
			echo " RUN: seed $$seed and run $$i."; \
                        echo "DEST: results/out_conda-seed_$$seed-run_$$i"; \
	                mkdir -p "results/out_conda-seed_$$seed-run_$$i"; \
			cp $(CLUSTERING_DIR)/Clustering_conda_tmp.yml results/out_conda-seed_$$seed-run_$$i/bench.yaml; \
			${OB_CMD} $(CLUSTERING_DIR)/Clustering_conda_tmp.yml --out-dir results/out_conda-seed_$$seed-run_$$i; \
		done; \
	done

run_oras: clone_yamls
	@for seed in $(SEEDS); do \
		echo "Running oras benchmark with seed $$seed..."; \
		cp $(CLUSTERING_DIR)/Clustering_oras.yml $(CLUSTERING_DIR)/Clustering_oras_tmp.yml; \
		sed -i "s/seed: 2/seed: $$seed/" $(CLUSTERING_DIR)/Clustering_oras_tmp.yml; \
		for i in $(RUNS); do \
			echo " RUN: seed $$seed and run $$i."; \
                        echo "DEST: results/out_oras-seed_$$seed-run_$$i" ;\
	                mkdir -p "results/out_oras-seed_$$seed-run_$$i"; \
			cp $(CLUSTERING_DIR)/Clustering_oras_tmp.yml results/out_oras-seed_$$seed-run_$$i/bench.yaml; \
			${OB_CMD}  $(CLUSTERING_DIR)/Clustering_oras_tmp.yml --out-dir results/out_oras-seed_$$seed-run_$$i; \
		done; \
	done

run_envs: clone_yamls
	@bash -c '\
 		source /cvmfs/software.eessi.io/versions/2025.06/init/lmod/bash && \
 		module load EESSI-extend/2025.06-easybuild && \
 		export MODULEPATH="$(EASYBUILD_PREFIX)/software/modules/all:$$MODULEPATH" && \
 		module use $$MODULEPATH && \
                 echo $$MODULEPATH && \
 		for seed in $(SEEDS); do \
 			echo "Running envmodules benchmark with seed $$seed..."; \
 			cp $(CLUSTERING_DIR)/Clustering_envmodules.yml $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml; \
		        sed -i "s/seed: 2/seed: $$seed/" $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml; \
 			for i in $(RUNS); do \
				echo " RUN: seed $$seed and run $$i..."; \
                                echo "DEST: results/out_oras-seed_$$seed-run_$$i" ;\
	                        mkdir -p "results/out_envmodules-seed_$$seed-run_$$i"; \
 				cp $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml results/out_envmodules-seed_$$seed-run_$$i/bench.yaml; \
				${OB_CMD} $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml --out-dir results/out_envmodules-seed_$$seed-run_$$i; \
 			done; \
 		done \
 	'

knit_report: clone_reports
	## R -e 'rmarkdown::render("$(REPORTS_DIR)/07_metrics_across_backends.Rmd", params = list(performance_bn = "performance-results.rds", metrics_bn = "metrics-results.rds", clustering_dir =  "."))'
	## R -e 'rmarkdown::render("$(REPORTS_DIR)/08_performances_across_backends.Rmd", params = list(performance_bn = "performance-results.rds", metrics_bn = "metrics-results.rds", clustering_dir =  "."))'
	#python parse_results.py > aggregated_results.json
	#R -e 'rmarkdown::render("analyze_results_mark.Rmd")'
