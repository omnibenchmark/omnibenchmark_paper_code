We distribute `Clustering.yml` runs with different backends.

- `Clustering_envmodules.yml`. Easybuild backend with default optimization.
- `Clustering_apptainer.yml`. Apptainer, pinned, prebuilt remote images from [omnibenchmark's registry](https://quay.io/organization/omnibenchmark).
- `Clustering_apptainer_vanilla.yml`. Singularity, pinnned, from local SIF images.
- `Clustering_apptainer_optimized.yml`. Singularity, pinnned, from local SIF images. This image compiles a custom python with optimization flags.
- `Clustering_conda.yml`. Conda semi-reproducible (no pinning, using pip)

The `_short` variants are meant to run smoketests and see that there's no operational problems when running the environments, abnormal terminations etc.


## envmodules - reproducible builds with easybuild

### Files

- `clustbench.eb`
- `fcps.eb`
- `rmarkdown.eb`
- `rmarkdown-python.eb`

### How to build

- `make prepare_envmodules_env` from the root folder.

## Aptainer, pinned, with registry pull

No need to prepare/build anything, since it fetches the apptainer images from a remote registry"

```bash
make run_with_apptainer_backend
```

## Apptainer, pinned, local build

### Files

The apptainer images are based in ubuntu-noble docker images.

The "optimized" flavor does a custom python 3.12 compilation; the vanillapy stocks the default py3.12 interpreter from the official ubuntu docker image.

- `clustbench_apptainer_optimized.def`
- `clustbench_apptainer_vanillapy.def`
- `fcps.def`

### How to build the SIF images

- `make prepare_apptainer_env` from the root folder.

## Conda

### Files

- `clustbench.yml`
- `fcps.yml`
- `rmarkdown.yml`

### How to build

No need to `ob software conda pin / prepare`. Just use `ob run benchmark -b Clustering_conda.yml --local`.


