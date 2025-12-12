#!/usr/bin/env python3
"""
Simple script to parse clustbench results with glob pattern matching.

Pattern: out-{backend}-{rep}/data/clustbench/dataset_generator-{generator}_dataset_name-{name}/clustering/{method}
"""

import csv
import gzip
import json
import re
from pathlib import Path
from typing import Dict, List, Optional

def parse_result_path(path: Path) -> Dict[str, str]:
    """
    Parse a result path and extract components:
    - backend, seed, run (from out_* directories)
    - dataset generator and dataset name
    - method (after clustering/)
    """
    parts = path.parts
    result: Dict[str, str] = {}

    # parse out_{backend}_seed_{seed}_run_{run}
    out_match = re.match(
        r"out_(?P<backend>[a-zA-Z0-9]+)_seed_(?P<seed>\d+)_run_(?P<run>\d+)",
        parts[0])

    if out_match:
        result["backend"] = out_match.group("backend")
        result["seed"] = out_match.group("seed")
        result["run"] = out_match.group("run")

    # Find dataset_generator part
    for part in parts:
        if part.startswith("dataset_generator-"):
            dataset_match = re.match(
                r"dataset_generator-([^_]+)_dataset_name-(.+)", part
            )
            if dataset_match:
                result["generator"] = dataset_match.group(1)
                result["dataset_name"] = dataset_match.group(2)
            break

    # The method is the last part (after clustering/)
    if "clustering" in parts:
        clustering_idx = parts.index("clustering")
        if clustering_idx + 1 < len(parts):
            result["method"] = parts[clustering_idx + 1]

    result["path"] = str(path)
    return result


def parse_performance_file(perf_file: Path) -> Optional[Dict]:
    """
    Parse a clustbench_performance.txt file (TSV format).

    Returns:
        Dictionary with performance metrics, or None if file doesn't exist
    """
    if not perf_file.exists():
        return None

    try:
        with open(perf_file, 'r') as f:
            reader = csv.DictReader(f, delimiter='\t')
            # Get the first (and only) data row
            for row in reader:
                # Convert values to appropriate types
                result = {}
                for key, value in row.items():
                    if value:
                        value = value.strip()
                        # Keep h:m:s as string, convert others to float
                        if key == 'h:m:s':
                            result[key] = value
                        else:
                            try:
                                result[key] = float(value)
                            except ValueError:
                                result[key] = value
                    else:
                        result[key] = None
                return result
    except Exception as e:
        return {'error': str(e)}

    return None


def parse_metric_scores(scores_file: Path) -> Optional[Dict[str, float]]:
    """
    Parse a clustbench.scores.gz file.
    
    Format:
    k=2,k=2,k=2,k=3,k=4
    1.0,1.0,1.0,0.7671742903354675,0.7289468426413069
    
    Returns:
        Dictionary mapping k values to scores, or None if file doesn't exist
    """
    if not scores_file.exists():
        return None
    
    try:
        with gzip.open(scores_file, 'rt') as f:
            lines = f.readlines()
            
        if len(lines) != 2:
            return {'error': f'Expected 2 lines, got {len(lines)}'}
        
        # Parse header (k values) - extract integers from "k=2" format
        k_strings = [k.strip() for k in lines[0].strip().split(',')]
        k_values = []
        for k_str in k_strings:
            match = re.match(r'k=(\d+)', k_str)
            if match:
                k_values.append(int(match.group(1)))
            else:
                return {'error': f'Invalid k format: {k_str}'}
        
        # Parse scores
        scores = [float(s.strip()) for s in lines[1].strip().split(',')]
        
        if len(k_values) != len(scores):
            return {'error': f'Mismatch: {len(k_values)} k values, {len(scores)} scores'}
        
        # Build result dict, checking for duplicate k values with different scores
        result = {}
        for k, score in zip(k_values, scores):
            if k in result:
                # Check if the score is different
                if abs(result[k] - score) > 1e-10:
                    raise ValueError(f'Duplicate k value {k} with different scores: {result[k]} vs {score}')
            else:
                result[k] = score
        
        return result
        
    except Exception as e:
        return {'error': str(e)}


def parse_metrics(param_dir: Path) -> Dict[str, Dict[str, Dict[str, float]]]:
    """
    Parse metrics from a parameter directory.
    
    Structure: {param_dir}/metrics/{metric_family}/metric-{metric_name}/clustbench.scores.gz
    
    Returns:
        Nested dict: {metric_family: {metric_name: {k: score}}}
    """
    metrics = {}
    metrics_dir = param_dir / 'metrics'
    
    if not metrics_dir.exists():
        return metrics
    
    # Iterate over metric families
    for family_dir in metrics_dir.iterdir():
        if not family_dir.is_dir():
            continue
        
        family_name = family_dir.name
        metrics[family_name] = {}
        
        # Iterate over metrics in this family
        for metric_dir in family_dir.iterdir():
            if not metric_dir.is_dir():
                continue
            
            # Extract metric name from metric-{name} pattern
            metric_match = re.match(r'metric-(.+)', metric_dir.name)
            if not metric_match:
                continue
            
            metric_name = metric_match.group(1)
            
            # Parse the scores file
            scores_file = metric_dir / 'clustbench.scores.gz'
            scores = parse_metric_scores(scores_file)
            
            if scores:
                metrics[family_name][metric_name] = scores
    
    return metrics


def find_results(base_dir: str = '.', pattern: str = 'out_*/data/clustbench/dataset_generator-*/clustering/*') -> List[Dict[str, str]]:
    """
    Find all result directories matching the pattern.

    Args:
        base_dir: Base directory to search from
        pattern: Glob pattern to match

    Returns:
        List of parsed result dictionaries
    """
    base_path = Path(base_dir)
    results = []

    for path in base_path.glob(pattern):
        if path.is_dir():
            # Skip hidden directories (starting with .)
            if not any(part.startswith('.') for part in path.parts):
                parsed = parse_result_path(path)

                # Find all parameter directories (subdirectories with parameter patterns)
                param_dirs = [d for d in path.iterdir() if d.is_dir() and not d.name.startswith('.')]

                if param_dirs:
                    # Parse configurations and their performance
                    parsed['configurations'] = []

                    # Assume first param_dir for method-level data
                    first_param_dir = param_dirs[0]

                    # Parse performance file at method level
                    perf_file = first_param_dir / 'clustbench_performance.txt'
                    performance = parse_performance_file(perf_file)
                    if performance:
                        parsed['performance'] = performance

                    # Parse metrics at method level
                    metrics = parse_metrics(first_param_dir)
                    if metrics:
                        parsed['metrics'] = metrics

                    # Add method_params and method_full at method level
                    method_params = first_param_dir.name

                    # Extract method from method-{method} pattern if present
                    method_match = re.match(r'method-([^_]+)', method_params)
                    if method_match:
                        extracted_method = method_match.group(1)
                        parsed['method'] = extracted_method

                    method_full = f"{parsed.get('method', '')}_{method_params}"
                    parsed['method_params'] = method_params
                    parsed['method_full'] = method_full

                    for param_dir in param_dirs:
                        # Load parameters.json if it exists
                        params_file = param_dir / 'parameters.json'
                        parameters = None
                        if params_file.exists():
                            try:
                                with open(params_file, 'r') as f:
                                    parameters = json.load(f)
                            except Exception as e:
                                parameters = {'error': str(e)}

                        config = {
                            'parameter_dir': param_dir.name,
                            'parameters': parameters
                        }

                        parsed['configurations'].append(config)

                results.append(parsed)

    return results


def main():
    """Main function to run the parser."""
    # Find all matching results
    results = find_results()

    # Print as JSON
    print(json.dumps(results, indent=2))

    # Print summary
    print(f"\n# Found {len(results)} result directories", file=__import__('sys').stderr)

    # Group by backend, generator, method
    by_backend = {}
    by_generator = {}
    by_method = {}

    for r in results:
        backend = r.get('backend', 'unknown')
        generator = r.get('generator', 'unknown')
        method = r.get('method', 'unknown')

        by_backend[backend] = by_backend.get(backend, 0) + 1
        by_generator[generator] = by_generator.get(generator, 0) + 1
        by_method[method] = by_method.get(method, 0) + 1

    print(f"# By backend: {by_backend}", file=__import__('sys').stderr)
    print(f"# By generator: {by_generator}", file=__import__('sys').stderr)
    print(f"# By method: {by_method}", file=__import__('sys').stderr)


if __name__ == '__main__':
    main()
