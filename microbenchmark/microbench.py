"""
This script exercises a few common linear algebra operations in numpy.
It's intended mostly to gauge whether it makes sense to descend into
compiler optimizations for the Python binary that we ship within the SIF images,
but it can be easily repurposed for other specific microbenchmarks (i.e., numba or GPU perf gains).

Be aware that here we're profiling simple operations; it would make sense to carefully
profile the libraries of interest to see where the computational bottlenecks really are.

Usage:

singularity exec clustbench-vanilla.sif python3 microbench.py
singularity exec clustbench-optimized.sif python3 microbench.py

References: https://pythonspeed.com/articles/faster-python/
"""
import numpy as np
import time
import json
from statistics import mean, stdev

DEFAULT_REPETITIONS = 10

def run_operation(operation, func, repetitions):
    timings = []
    for _ in range(repetitions):
        start = time.perf_counter()
        func()
        elapsed = time.perf_counter() - start
        timings.append(elapsed)
    return {
        'operation': operation,
        'mean': mean(timings),
        'stdev': stdev(timings),
        'runs': repetitions
    }

def benchmark(repetitions=DEFAULT_REPETITIONS):
    np.random.seed(42)
    size = 1000

    # Create random matrices
    A = np.random.rand(size, size)
    B = np.random.rand(size, size)
    C = A @ A.T  # Ensure positive definite for Cholesky

    # Define operations
    operations = [
        ('mat_mul', lambda: np.dot(A, B)),
        ('svd', lambda: np.linalg.svd(A)),
        ('chol_decomp', lambda: np.linalg.cholesky(C))
    ]

    results = []
    for operation, func in operations:
        try:
            result = run_operation(operation, func, repetitions)
        except np.linalg.LinAlgError:
            result = {
                'operation': operation,
                'error': 'Operation failed due to numerical instability'
            }
        results.append(result)

    # Output results as JSON
    print(json.dumps(results, indent=2))

if __name__ == "__main__":
    import sys
    repetitions = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_REPETITIONS
    benchmark(repetitions)
