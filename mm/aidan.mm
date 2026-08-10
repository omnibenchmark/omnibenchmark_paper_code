---
config:
  layout: dagre
  look: classic
title: omni-OpenProblems-svg
---
flowchart TB
 subgraph datasets["datasets"]
        load_spatial_data["load_spatial_data"]
  end
 subgraph methods["methods"]
        boostgp["boostgp"]
        gpcounts["gpcounts"]
        spark["spark"]
        spark_x["spark_x"]
        moran_i["moran_i"]
        nnsvg["nnsvg"]
        scgco["scgco"]
        SpaGCN["SpaGCN"]
        spatialde2["spatialde2"]
        ...["..."]
  end
 subgraph metric["metric"]
        correlation["correlation"]
  end
    load_spatial_data --> boostgp & gpcounts & spark & spark_x & moran_i & nnsvg & scgco & SpaGCN & spatialde2 & ...
    boostgp --> correlation
    gpcounts --> correlation
    spark --> correlation
    spark_x --> correlation
    moran_i --> correlation
    nnsvg --> correlation
    scgco --> correlation
    SpaGCN --> correlation
    spatialde2 --> correlation
    ... --> correlation

    classDef param fill:#f96
