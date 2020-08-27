Workflow
=========
Here, we describe the terminology and the general workflow in more detail.

# Terminology

We define the terminology used within this documentation, the code, and input data:
- Technology: a technology that produces, consumes, converts or transports energy
- Node: a site which can contain multiple technologies
- Line: a link between two sites that can carry energy between those sites
- Carrier: an energy carrier that groups technologies together into the same network, for example, electricity or heat
- Parameter: a fixed coefficient that enters into model equations
- Variable: a variable coefficient (decision variable) that enters into model equations
- Set: an index in the algebraic formulation of the equations
- Constraint: equality or inequality expression that constrains one or several variables

# Workflow

The workflow for this package can be broken down to:
- Data Preparation
- Optimization

## Data Preparation
CEP needs two types of data:
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
