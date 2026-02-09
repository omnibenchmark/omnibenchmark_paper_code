---
config:
  layout: dagre
  look: classic
title: omni-clustering-benchmarks
---
flowchart LR
	classDef param fill:#f96
	subgraph data
		clustbench
	end
	subgraph clustering
		fastcluster
		clustbench --> fastcluster
		sklearn
		clustbench --> sklearn
		agglomerative
		clustbench --> agglomerative
		genieclust
		clustbench --> genieclust
		fcps
		clustbench --> fcps
	end
	subgraph metrics
		partition_metrics
		agglomerative --> partition_metrics
		fastcluster --> partition_metrics
		fcps --> partition_metrics
		genieclust --> partition_metrics
		sklearn --> partition_metrics
	end
