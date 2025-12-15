#!/usr/bin/env python3
"""
Parse clustbench results with glob pattern matching.

Pattern:
out-{backend}_seed-{seed}_run-{run}/data/clustbench/dataset_generator-{generator}_dataset_name-{name}/clustering/{method}
"""

import csv
import gzip
import json
import re
from pathlib import Path
from typing import Dict, List, Optional


def parse_result_path(path: Path) -> List[Dict[str, str]]:
    """
    Parse a result path and extract components:
    - backend, seed, run (from out_* directories)
    - dataset generator and dataset name
    - method (immediate folder after clustering/)
    - method_full (method + variant symlink/subdir)

    Returns a list of dicts, one per available variant directory under {method}.
    """
    parts = path.parts
    base_result: Dict[str, str] = {}

    # parse out_{backend}_seed_{seed}_run_{run}
    out_match = re.match(
        r"out_(?P<backend>[a-zA-Z0-9]+)_seed_(?P<seed>\d+)_run_(?P<run>\d+)",
        parts[0]
    )
    if out_match:
        base_result["backend"] = out_match.group("backend")
        base_result["seed"] = out_match.group("seed")
        base_result["run"] = out_match.group("run")

    # find dataset_generator part
    for part in parts:
        if part.startswith("dataset_generator-"):
            dataset_match = re.match(
                r"dataset_generator-([^_]+)_dataset_name-(.+)", part
            )
            if dataset_match:
                base_result["generator"] = dataset_match.group(1)
                base_result["dataset_name"] = dataset_match.group(2)
            break

    results: List[Dict[str, str]] = []

    # The method is the folder after clustering/
    if "clustering" in parts:
        clustering_idx = parts.index("clustering")
        if clustering_idx + 1 < len(parts):
            method_dir = parts[clustering_idx + 1]
            base_result["method"] = method_dir

            method_path = path
            if method_path.is_dir():
                for child in method_path.iterdir():
                    # skip hidden dirs, hashes, and metrics folder
                    if child.name.startswith("."):
                        continue
                    if re.fullmatch(r"[0-9a-f]{32,}", child.name):
                        continue
                    if re.fullmatch(r"[0-9a-f]{8,}", child.name):
                        continue
                    if child.name == "metrics":
                        continue

                    if child.is_symlink() or child.is_dir():
                        r = base_result.copy()
                        r["method_full"] = f"{method_dir}_{child.name}"
                        r["path"] = str(child)
                        results.append(r)
            else:
                r = base_result.copy()
                r["method_full"] = "/".join(parts[clustering_idx + 1:])
                r["path"] = str(path)
                results.append(r)

    return results


def parse_performance_file(perf_file: Path) -> Optional[Dict]:
    """Parse a clustbench_performance.txt file (TSV format)."""
    if not perf_file.exists():
        return None

    try:
        with open(perf_file, 'r') as f:
            reader = csv.DictReader(f, delimiter='\t')
            for row in reader:
                result = {}
                for key, value in row.items():
                    if value:
                        value = value.strip()
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
    """Parse a clustbench.scores.gz file into {k: score} dict."""
    if not scores_file.exists():
        return None

    try:
        with gzip.open(scores_file, 'rt') as f:
            lines = f.readlines()

        if len(lines) != 2:
            return {'error': f'Expected 2 lines, got {len(lines)}'}

        k_strings = [k.strip().strip('"') for k in lines[0].strip().split(',')]
        k_values = []
        for k_str in k_strings:
            m = re.match(r'k=(\d+)', k_str)
            if m:
                k_values.append(int(m.group(1)))
            else:
                return {'error': f'Invalid k format: {k_str}'}

        score_strings = [s.strip().strip('"') for s in lines[1].strip().split(',')]
        scores = []
        for s in score_strings:
            try:
                scores.append(float(s))
            except ValueError:
                return {'error': f'Invalid score: {s}'}

        if len(k_values) != len(scores):
            return {'error': f'Mismatch: {len(k_values)} k values, {len(scores)} scores'}

        result = {}
        for k, score in zip(k_values, scores):
            if k in result and abs(result[k] - score) > 1e-10:
                return {'error': f'Duplicate k {k} with differing scores'}
            result[k] = score

        return result

    except Exception as e:
        return {'error': str(e)}


def parse_metrics(config_dir: Path) -> Dict[str, Dict[str, Dict[str, float]]]:
    """Parse metrics from a configuration directory."""
    metrics = {}
    metrics_dir = config_dir / 'metrics'
    if not metrics_dir.exists():
        return metrics

    for family_dir in metrics_dir.iterdir():
        if not family_dir.is_dir():
            continue
        family_name = family_dir.name
        metrics[family_name] = {}
        for metric_dir in family_dir.iterdir():
            if not metric_dir.is_dir():
                continue
            metric_match = re.match(r'metric-(.+)', metric_dir.name)
            if not metric_match:
                continue
            metric_name = metric_match.group(1)
            scores_file = metric_dir / 'clustbench.scores.gz'
            scores = parse_metric_scores(scores_file)
            if scores:
                metrics[family_name][metric_name] = scores
    return metrics


def find_results(
    base_dir: str = ".",
    pattern: str = "out_*/data/clustbench/dataset_generator-*/clustering/*"
) -> List[Dict[str, str]]:
    """
    Return one record per configuration folder with parameters, performance, and metrics.
    """
    base_path = Path(base_dir)
    results: List[Dict[str, str]] = []

    for path in base_path.glob(pattern):
        if not path.is_dir():
            continue
        if any(part.startswith(".") for part in path.parts):
            continue

        variants = parse_result_path(path)
        for variant in variants:
            config_dir = Path(variant["path"])
            if not config_dir.is_dir() or config_dir.name == "metrics":
                continue

            record = variant.copy()

            # Parameters
            params_file = config_dir / "parameters.json"
            parameters = None
            if params_file.exists():
                try:
                    with open(params_file, "r") as f:
                        parameters = json.load(f)
                except Exception as e:
                    parameters = {"error": str(e)}
            record["parameters"] = parameters
            record["parameter_dir"] = config_dir.name

            # Performance
            perf_file = config_dir / "clustbench_performance.txt"
            performance = parse_performance_file(perf_file)
            if performance:
                record["performance"] = performance

            # Metrics
            metrics = parse_metrics(config_dir)
            if metrics:
                record["metrics"] = metrics

            # Normalize method name
            m = re.match(r"method-([^_]+)", config_dir.name)
            if m:
                record["method"] = m.group(1)

            # Ensure method_full includes config dir name once
            variant_name = record["method_full"]
            if config_dir.name not in variant_name:
                record["method_full"] = f"{variant_name}_{config_dir.name}"

            record["path"] = str(config_dir)
            results.append(record)

    return results


def main():
    results = find_results()
    print(json.dumps(results, indent=2))

    # Summary to stderr
    import sys
    print(f"\n# Found {len(results)} result directories", file=sys.stderr)

    by_backend, by_generator, by_method = {}, {}, {}
    for r in results:
        backend = r.get('backend', 'unknown')
        generator = r.get('generator', 'unknown')
        method = r.get('method', 'unknown')
        by_backend[backend] = by_backend.get(backend, 0) + 1
        by_generator[generator] = by_generator.get(generator, 0) + 1
        by_method[method] = by_method.get(method, 0) + 1

    print(f"# By backend: {by_backend}", file=sys.stderr)
    print(f"# By generator: {by_generator}", file=sys.stderr)
    print(f"# By method: {by_method}", file=sys.stderr)


if __name__ == '__main__':
    main()
