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


MAX_CORES ?= 120

# EasyBuild installation prefix (imallona; edit accordingly) ## <------------------------------------!!!!
EASYBUILD_PREFIX ?= /data/imallona/.local/easybuild
export EASYBUILD_PREFIX

# omnibenchmark command template
OB_CMD = ob run benchmark --cores ${MAX_CORES} -k --task-timeout 1min --yes

# actual benchmark plan repository - to be pinned (the commit/tag)
CLUSTERING_REPO   = https://github.com/omnibenchmark/clustering_example
CLUSTERING_BRANCH = full_yamls
CLUSTERING_DIR	  = clustering_example

# legacy reports in the wrong repository; to be moved to this one
REPORTS_REPO = https://github.com/imallona/clustering_report
REPORTS_DIR = clustering_report

all: clone_yamls clone_reports run_conda run_oras run_envs knit_report

# clone the clustering_example repo if not already present
clone_yamls:
	@if [ ! -d "$(CLUSTERING_DIR)" ]; then \
		echo "Cloning clustering_example repo..."; \
		git clone --branch ${CLUSTERING_BRANCH} $(CLUSTERING_REPO); \
	else \
		echo "clustering_example repo already present, pulling latest..."; \
		cd $(CLUSTERING_DIR) && git fetch  && git checkout ${CLUSTERING_BRANCH} && git pull; \
	fi

# clone the clustering_report repo (mark branch) if not already present
clone_reports:
	@if [ ! -d "$(REPORTS_DIR)" ]; then \
		echo "Cloning clustering_report repo (branch mark)..."; \
		git clone --branch mark $(REPORTS_REPO) $(REPORTS_DIR); \
	else \
		echo "clustering_report repo already present, pulling latest..."; \
		cd $(REPORTS_DIR) && git pull; \
	fi

run_conda: clone_yamls
	@for seed in 2 54 546 744 1443; do \
		echo "Running conda benchmark with seed $$seed..."; \
		cp $(CLUSTERING_DIR)/Clustering_conda.yml $(CLUSTERING_DIR)/Clustering_conda_tmp.yml; \
		sed -i "s/--seed, [0-9]\+/--seed, $$seed/" $(CLUSTERING_DIR)/Clustering_conda_tmp.yml; \
		for i in 1 2 3; do \
			echo "  Run $$i for seed $$seed..."; \
			${OB_CMD} -b $(CLUSTERING_DIR)/Clustering_conda_tmp.yml; \
			cp $(CLUSTERING_DIR)/Clustering_conda_tmp.yml out; \
			mv out out_conda_seed_$$seed\_run_$$i; \
		done; \
	rm $(CLUSTERING_DIR)/Clustering_conda_tmp.yml; \
	done

run_oras: clone_yamls
	@for seed in 2 54 546 744 1443; do \
		echo "Running oras benchmark with seed $$seed..."; \
		cp $(CLUSTERING_DIR)/Clustering_oras.yml $(CLUSTERING_DIR)/Clustering_oras_tmp.yml; \
		sed -i "s/--seed, [0-9]\+/--seed, $$seed/" $(CLUSTERING_DIR)/Clustering_oras_tmp.yml; \
		for i in 1 2 3; do \
			echo "  Run $$i for seed $$seed..."; \
			${OB_CMD} -b $(CLUSTERING_DIR)/Clustering_oras_tmp.yml; \
			cp $(CLUSTERING_DIR)/Clustering_oras_tmp.yml out; \
			mv out out_oras_seed_$$seed\_run_$$i; \
		done; \
	rm $(CLUSTERING_DIR)/Clustering_oras_tmp.yml; \
	done

run_envs: clone_yamls
	@bash -c '\
		source /cvmfs/software.eessi.io/versions/2025.06/init/lmod/bash && \
		module load EESSI-extend/2025.06-easybuild && \
		export MODULEPATH="$(EASYBUILD_PREFIX)/software/modules/all:$$MODULEPATH" && \
		module use $$MODULEPATH && \
                echo $$MODULEPATH && \
		for seed in 2 54 546 744 1443; do \
			echo "Running envmodules benchmark with seed $$seed..."; \
			cp $(CLUSTERING_DIR)/Clustering_envmodules.yml $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml; \
			sed -i "s/--seed, [0-9]\+/--seed, $$seed/" $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml; \
			for i in 1 2 3; do \
				echo "  Run $$i for seed $$seed..."; \
				${OB_CMD} -b $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml; \
				cp $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml out; \
				mv out out_envmodules_seed_$$seed\_run_$$i; \
			done; \
			rm $(CLUSTERING_DIR)/Clustering_envmodules_tmp.yml; \
		done \
	'

knit_report: clone_reports
	# R -e 'rmarkdown::render("$(REPORTS_DIR)/07_metrics_across_backends.Rmd", params = list(performance_bn = "performance-results.rds", metrics_bn = "metrics-results.rds", clustering_dir =  "."))'
	# R -e 'rmarkdown::render("$(REPORTS_DIR)/08_performances_across_backends.Rmd", params = list(performance_bn = "performance-results.rds", metrics_bn = "metrics-results.rds", clustering_dir =  "."))'
	python parse_results.py > aggregated_results.json
	R -e 'rmarkdown::render("analyze_results_izaskun.Rmd")'
