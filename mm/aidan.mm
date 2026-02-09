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
        nnsvg["nnsvg"]
        spark["spark"]
        spark_x["spark_x"]
        gpcounts["gpcounts"]
        moran_i["moran_i"]
        scgco["scgco"]
        sepal["sepal"]
        somde["somde"]
        spagcn["spagcn"]
        spagft["spagft"]
        spanve["spanve"]
        spatialde["spatialde"]
        spatialde2["spatialde2"]
  end
 subgraph metric["metric"]
        correlation["correlation"]
  end
    load_spatial_data --> boostgp & nnsvg & spark & spark_x & gpcounts & moran_i & scgco & sepal & somde & spagcn & spagft & spanve & spatialde & spatialde2
    boostgp --> correlation
    gpcounts --> correlation
    moran_i --> correlation
    nnsvg --> correlation
    scgco --> correlation
    sepal --> correlation
    somde --> correlation
    spagcn --> correlation
    spagft --> correlation
    spanve --> correlation
    spark --> correlation
    spark_x --> correlation
    spatialde --> correlation
    spatialde2 --> correlation
    
    classDef param fill:#f96