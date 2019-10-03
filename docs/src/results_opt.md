Result
=========
Here, we describe the optimization result.

## Types
The optimization results are provided in an `OptResult` struct:
```@docs
OptResult
```

## Equations
!!! note
    The model tracks how it is setup and which equations are used. This can help you to understand the models exact configuration without looking up the source code.

The information of the model setup can be checked out the following way:
```@setup 4
using CapacityExpansion
using Clp
optimizer=Clp.Optimizer
state="GER_1"
years=[2016]
ts_input_data = load_timeseries_data_provided(state;T=24, years=years)
cep_data = load_cep_data_provided(state)
ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=5).clust_data
```
```@example 4
result = run_opt(ts_clust_data,cep_data,optimizer;descriptor="Model Name")
result.info["model"]
```
## Variables in Result
All variables are provided as dense `OptVariable` structs and can be indexed as explained in [Data Types](@ref).
The variables can be of different type as explained in [Variables](@ref). The different groups of variables can be extracted from the `OptResult` based on the `variable_type`:
```@docs
get_cep_variables
get_cep_slack_variables
get_cep_design_variables
```
The extraction of design variables is e.g. necessary for a [Second stage operational validation step](@ref), which validates the energy system design on a different time series.
