![CapacityExpansion logo](assets/cep_text.svg)
===
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/dev)
[![Build Status](https://travis-ci.com/holgerteichgraeber/TimeSeriesClustering.jl.svg?token=HRFemjSxM1NBCsbHGNDG&branch=master)](https://travis-ci.com/YoungFaithful/CapacityExpansion.jl)

[CapacityExpansion](https://github.com/YoungFaithful/CapacityExpansion.jl) is a [julia](https://www.juliaopt.com) implementation of a input-data-scaling capacity expansion modeling framework.

|Model Information		|  																																									|
|---------------------|-----------------------------------------------------------------------------------|
|Model class          |	Capacity Expansion Problem                                                        |
|Model type						| Optimization, Linear optimization model input-data depending energy system 				|
|Sectors              | (currently) Electricity                                                           |
|Technologies         |	dispathable and non-dispathable Generation, Storage (seasonal), Transmission      |
|Decisions 	          | investment and dispatch                                                           |
|Objective						| Total system cost																																	|
|Variables 						| Cost, Capacities, Generation, Storage, Lost-Load, Lost-Emissions									|

|Input Data Depending | Provided Input Data																															 	 |
|---------------------|------------------------------------------------------------------------------------|
|Regions 	            | California, USA (single and multi-node) and Germany, Europe (single and multi-node)|
|Geographic Resolution| aggregated regions        					                            									 |
|Time resolution 	    | hourly                                                          									 |
|Network coverage 	  | transmission, DCOPF load flow                                   								   |


The package uses [TimeSeriesClustering](https://github.com/holgerteichgraeber/TimeSeriesClustering.jl) as a basis for it's time-series aggregation.

This package is developed by Elias Kuepper [@YoungFaithful](https://github.com/youngfaithful) and Holger Teichgraeber [@holgerteichgraeber](https://github.com/holgerteichgraeber).

## Installation
This package runs under julia v1.0 and higher.
It depends on:
- `JuMP.jl` - for the modeling environment
- `CSV.jl` - for handling of `.csv`-Files
- `DataFrames.jl` - for handling of tables
- `StatsBase.jl` - for handling of basic  
- `JLD2` - for saving your result data
- `FileIO` - for file accessing
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
