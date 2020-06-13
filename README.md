![CapacityExpansion logo](docs/src/assets/cep_text.svg)
===
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://YoungFaithful.github.io/CapacityExpansion.jl/dev)
[![Build Status](https://travis-ci.com/YoungFaithful/CapacityExpansion.jl.svg?branch=master)](https://travis-ci.com/YoungFaithful/CapacityExpansion.jl)

[CapacityExpansion](https://github.com/YoungFaithful/CapacityExpansion.jl) is a [julia](https://www.juliaopt.com) implementation of an input-data-scaling capacity expansion modeling framework.

The main purpose of the package is providing an extensible, simple-to-use generation and transmission capacity extension model that allows to address a diverse set of research questions in the area of energy systems planning. The secondary purposes are:
1) Providing a simple process to integrate (clustered) time-series input data, geographical input data, cost input data, and technology input data.
2) Providing a model configuration, a modular model setup and model optimization.
3) Providing an interface between the optimization result and further analysis.

Please refer to the [documentation](https://YoungFaithful.github.io/CapacityExpansion.jl/stable) for details on how to use this software.

|Model Information		|  																																									|
|---------------------|-----------------------------------------------------------------------------------|
|Model class          |	Capacity Expansion Problem                                                        |
|Model type						| Optimization, Linear optimization model input-data depending energy system 				|
|Carriers             | Electricity, Hydrogen, ...                                                           |
|Technologies         |	dispatchable and non-dispatchable Generation, Conversion, Storage (seasonal), Transmission      |
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
- `JLD2` - for saving your result data
- `FileIO` - for file accessing
- `TimeSeriesClustering.jl` - for time-series data

```julia
using Pkg
Pkg.add("CapacityExpansion")
```

A solver is required to run an optimization as explained in section [Solver](https://youngfaithful.github.io/CapacityExpansion.jl/stable/opt_cep/#Solver-1).
Install e.g.:
```julia
using Pkg
Pkg.add("Clp")
```
## Example Workflow
```julia
using CapacityExpansion
using Clp
optimizer=Clp.Optimizer # select optimizer

## LOAD DATA ##
# laod ts-data
ts_input_data = load_timeseries_data_provided("GER_1"; T=24, years=[2016])
# load cep-data
cep_data = load_cep_data_provided("GER_1")

## OPTIMIZATION ##
# run a simple
run_opt(ts_input_data,cep_data,optimizer)
```
