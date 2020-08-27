![CapacityExpansion logo](docs/src/assets/cep_text.svg)
===
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/dev)
[![Build Status](https://travis-ci.com/YoungFaithful/CapacityExpansion.jl.svg?branch=master)](https://travis-ci.com/YoungFaithful/CapacityExpansion.jl)

[CapacityExpansion](https://github.com/YoungFaithful/CapacityExpansion.jl) is a [julia](https://julialang.org/) implementation of an input-data-scaling capacity expansion modeling framework.

The primary purpose of the package is providing an extensible, simple-to-use generation and transmission capacity expansion model that allows addressing a diverse set of research questions in the area of energy systems planning. The secondary purposes are:
1) Providing a simple process to integrate (clustered) time-series input data, geographical input data, cost input data, and technology input data.
2) Providing a model configuration, a modular model setup and model optimization.
3) Providing an interface between the optimization result and further analysis.

| Model Information |                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------ |
| Model class       | Capacity Expansion Planning                                                                      |
| Model type        | Optimization, Linear optimization model input-data depending energy system                       |
| Carriers          | Electricity, Hydrogen,...                                                                       |
| Technologies      | dispatchable and non-dispatchable Generation, Conversion, Storage (seasonal), Transmission, Demand |
| Decisions         | investment and dispatch                                                                          |
| Objective         | Total system cost                                                                                |
| Variables         | Cost, Capacities, Generation, Storage, Lost-Load, Lost-Emissions                                 |

| Input Data Depending  | Provided Input Data                                                                 |
| --------------------- | ----------------------------------------------------------------------------------- |
| Regions               | California, USA (single and multi-node) and Germany, Europe (single and multi-node) |
| Geographic Resolution | aggregated regions                                                                  |
| Time resolution       | hourly                                                                              |
| Network coverage      | transmission, DCOPF load flow                                                       |


The package uses [TimeSeriesClustering](https://github.com/holgerteichgraeber/TimeSeriesClustering.jl) as a basis for its time-series aggregation.

This package is developed by Elias Kuepper [@YoungFaithful](https://github.com/youngfaithful) and Holger Teichgraeber [@holgerteichgraeber](https://github.com/holgerteichgraeber).

## Installation
This package runs under julia v1.0 and higher.
It depends on multiple packages, which are also listed in the [`Project.toml`](https://github.com/YoungFaithful/CapacityExpansion.jl/blob/master/Project.toml). The packages are automatically installed by the julia package manager:
- `JuMP.jl` - for the modeling environment
- `CSV.jl` - for handling of `.csv`-Files
- `DataFrames.jl` - for handling of tables
- `StatsBase.jl` - for handling of basic  
- `JLD2` - for saving your result data
- `FileIO` - for file accessing
- `TimeSeriesClustering.jl` - for time-series data

You can install `CapacityExpansion` using the package mode:
```julia
]
add CapacityExpansion
```
or using the `Pkg.add` function:
```julia
using Pkg
Pkg.add("CapacityExpansion")
```

A solver is required to run an optimization, as explained in section [Solver](@ref).
Install, e.g. `Clp` using the package mode:
```julia
]
add Clp
```
or using the `Pkg.add` function:
```julia
using Pkg
Pkg.add("Clp")
```

## Links
- [Documentation of the stable version](https://YoungFaithful.github.io/CapacityExpansion.jl/stable)
- [Documentation of the development version](https://YoungFaithful.github.io/CapacityExpansion.jl/dev)
- [Contributing guidelines](https://github.com/YoungFaithful/CapacityExpansion.jl/blob/master/CONTRIBUTING.md)
