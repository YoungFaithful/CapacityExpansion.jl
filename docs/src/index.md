![CapacityExpansion logo](assets/cep_text.svg)
===
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/dev)
[![Build Status](https://travis-ci.com/holgerteichgraeber/TimeSeriesClustering.jl.svg?token=HRFemjSxM1NBCsbHGNDG&branch=master)](https://travis-ci.com/YoungFaithful/CapacityExpansion.jl)

[CapacityExpansion](https://github.com/YoungFaithful/CapacityExpansion.jl) is a [julia](https://www.juliaopt.com) implementation of an input-data-scaling, multi-sector capacity expansion modeling framework.

The main purpose of the package is providing an extensible, simple-to-use generation and transmission capacity expansion model that allows to address a diverse set of research questions in the area of energy systems planning. The secondary purposes are:
1) Providing a simple process to integrate (clustered) time-series input data, geographical input data, cost input data, and technology input data.
2) Providing a model configuration, a modular model setup and model optimization.
3) Providing an interface between the optimization result and further analysis.

|Model Information		|  																																									|
|---------------------|-----------------------------------------------------------------------------------|
|Model class          |	Capacity Expansion Planning                                                        |
|Model type						 | Optimization, Linear optimization model input-data depending energy system 				|
|Carriers         | Electricity, Hydrogen, ...                                                           |
|Technologies         |	dispathable and non-dispathable Generation, Conversion, Storage (seasonal), Transmission, Demand      |
|Decisions 	          | investment and dispatch                                                           |
|Objective						| Total system cost																																	|
|Variables 						| Cost, Capacities, Generation, Storage, Lost-Load, Lost-Emissions									|

|Input Data Depending | Provided Input Data																															 	 |
|---------------------|------------------------------------------------------------------------------------|
|Regions 	            | California, USA (single and multi-node) and Germany, Europe (single and multi-node)|
|Geographic Resolution| aggregated regions        					                            									 |
|Time resolution 	    | hourly                                                          									 |
|Network coverage 	  | transmission, DCOPF load flow                                   								   |

The package uses [TimeSeriesClustering](https://github.com/holgerteichgraeber/TimeSeriesClustering.jl) as a basis for its time-series aggregation.

This package is developed by Elias Kuepper [@YoungFaithful](https://github.com/youngfaithful) and Holger Teichgraeber [@holgerteichgraeber](https://github.com/holgerteichgraeber).

## Installation
This package runs under julia v1.0 and higher.
It depends on:
- `JuMP.jl` - for the modeling environment
- `CSV.jl` - for handling of `.csv`-Files
- `DataFrames.jl` - for handling of tables
- `StatsBase.jl` - for handling of basic  
- `JLD2.jl` - for saving your result data
- `FileIO.jl` - for file accessing
- `TimeSeriesClustering.jl` - for time-series data

```julia
using Pkg
Pkg.add("CapacityExpansion")
```

A solver is required to run an optimization as explained in section [Solver](@ref).
Install e.g.:
```julia
using Pkg
Pkg.add("Clp")
```
