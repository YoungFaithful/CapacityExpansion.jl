Workflow
=========
Here, we describe the general workflow in more detail.

The workflow for this package can be broken down to:
- Data Preparation
- Optimization

## Data Preparation
The CEP needs two types of data
- Time series data in the type `ClustData` - [Preparing ClustData](@ref)
- Cost, node, (line), and technology data in the type `OptDataCEP` - [Preparing OptDataCEP](@ref)
They are kept separate as just the time series dependent data is used to determine representative periods (clustering).

![Plot](assets/workflow.svg)

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
