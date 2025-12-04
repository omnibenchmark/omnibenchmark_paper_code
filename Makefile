MAX_CORES ?= 50

# omnibenchmark command
OB_CMD = ob run benchmark --local-storage --cores ${MAX_CORES}

# actual benchmark plan repository - to be pinned (the commit/tag)
CLUSTERING_REPO = https://github.com/omnibenchmark/clustering_example
CLUSTERING_DIR	= clustering_example

# legacy reports in the wrong repository; to be moved to this one
REPORTS_REPO = https://github.com/imallona/clustering_report
REPORTS_DIR = clustering_report

all: clone_yamls clone_reports run_conda run_oras run_envs knit_report

# clone the clustering_example repo if not already present
clone_yamls:
	@if [ ! -d "$(CLUSTERING_DIR)" ]; then \
		echo "Cloning clustering_example repo..."; \
		git clone $(CLUSTERING_REPO); \
	else \
		echo "clustering_example repo already present, pulling latest..."; \
		cd $(CLUSTERING_DIR) && git pull; \
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
	@for i in 1 2 3; do \
		echo "Running conda benchmark $$i..."; \
		${OB_CMD} -b $(CLUSTERING_DIR)/Clustering_conda.yml; \
		cp $(CLUSTERING_DIR)/Clustering_conda.yml out; \
		mv out out_conda_$$(date +'%Y%m%d_%H%M')_$$i; \
	done

run_oras: clone_yamls
	@for i in 1 2 3; do \
		echo "Running oras benchmark $$i..."; \
		${OB_CMD} -b $(CLUSTERING_DIR)/Clustering_oras.yml; \
		cp $(CLUSTERING_DIR)/Clustering_oras.yml out; \
		mv out out_singularity_$$(date +'%Y%m%d_%H%M')_$$i; \
	done

run_envs: clone_yamls
	@bash -c '\
		source /cvmfs/software.eessi.io/versions/2025.06/init/lmod/bash && \
		module load EESSI-extend/2025.06-easybuild && \
		export MODULEPATH="$$EASYBUILD_PREFIX/software/modules/all:$$MODULEPATH" && \
		module Use $$MODULEPATH && \
		for i in 1 2 3; do \
		    echo "Running envmodules benchmark $$i..."; \
	    		${OB_CMD} -b $(CLUSTERING_DIR)/Clustering_envmodules.yml; \
	    		cp $(CLUSTERING_DIR)/Clustering_envmodules.yml out; \
	    		mv out out_envmodules_$$(date +'%Y%m%d_%H%M')_$$i; \
		done \
	'

knit_report: clone_reports
	R -e 'rmarkdown::render("$(REPORTS_DIR)/07_metrics_across_backends.Rmd", params = list(performance_bn = "performance-results.rds", metrics_bn = "metrics-results.rds", clustering_dir =  "."))'
	R -e 'rmarkdown::render("$(REPORTS_DIR)/08_performances_across_backends.Rmd", params = list(performance_bn = "performance-results.rds", metrics_bn = "metrics-results.rds", clustering_dir =  "."))'
	python parse_results.py
	R -e 'rmarkdown::render("analyze_results.Rmd")'
