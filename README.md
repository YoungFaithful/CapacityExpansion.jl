![CEP logo](docs/src/assets/cep_text.svg)
===
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://YoungFaithful.github.io/CEP.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://YoungFaithful.github.io/CEP.jl/dev)
[![Build Status](https://travis-ci.com/holgerteichgraeber/ClustForOpt.jl.svg?token=HRFemjSxM1NBCsbHGNDG&branch=master)](https://travis-ci.com/YoungFaithful/CEP.jl)

[CEP](https://github.com/YoungFaithful/CEP.jl) is a [julia](https://www.juliaopt.com) implementation of a input-data-scaling capacity expansion modeling framework.

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


The package uses [ClustForOpt](https://github.com/holgerteichgraeber/ClustForOpt.jl) as a basis for it's time-series aggregation.

This package is developed by Elias Kuepper [@YoungFaithful](https://github.com/youngfaithful) and Holger Teichgraeber [@holgerteichgraeber](https://github.com/holgerteichgraeber).

## Installation
This package runs under julia v1.0 and higher.
Install using:

```julia
]
add https://github.com/YoungFaithful/CEP.jl.git
```
where `]` opens the julia package manager.

## Example Workflow
```julia
using CEP
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
