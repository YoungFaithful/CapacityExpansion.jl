Optimization Problem Formulation
=========
Here, we describe how to load provided non time-series dependent data or your non time-series dependent data as `OptDataCEP`. We second describe the datatypes within the `OptDataCEP` and how to access it.

## General
The capacity expansion problem (CEP) is designed as a linear optimization model. It is implemented in the algebraic modeling language [JUMP](http://www.juliaopt.org/JuMP.jl/latest/). The implementation within JuMP allows to optimize multiple models in parallel and handle the steps from data input to result analysis and diagram export in one open source programming language. The coding of the model enables scalability based on the provided data input, single command based configuration of the setup model, result and configuration collection for further analysis and the opportunity to run design and operation in different optimizations.

![Plot](assets/opt_cep.svg)

The basic idea for the energy system is to have a spacial resolution of the energy system in discrete nodes. Each node has demand, non-dispatchable generation, dispatachable generation and storage capacities of varying technologies connected to itself. The different energy system nodes are interconnected with each other by transmission lines.
The model is designed to minimize social costs by minimizing the following objective function:

```math
min \sum_{account,tech}COST_{account,'EUR/USD',tech} + \sum LL \cdot  cost_{LL} + LE \cdot  cos_{LE}
```

## Sets
The models scalability is relying on the usage of sets. The elements of the sets are extracted from the input data and scale the different variables. An overview of the sets is provided in the table. Depending on the models configuration the necessary sets are initialized.

The sets are setup as a dictionary and organized as `set[tech_name][tech_group]=[elements...]`, where:
- `tech_name` is the name of the dimension like e.g. `tech`, or `node`
- `tech_group` is the name of a group of elements within each dimension like e.g. `["all", "generation"]`. The group `'all'` always contains all elements of the dimension
- `[elements...]` is the Array with the different elements like `["pv", "wind", "gas"]`

| name             | description                                                           |
|------------------|-----------------------------------------------------------------------|
| lines            | transmission lines connecting the nodes                               |
| nodes            | spacial energy system nodes                                           |
| tech             | generation, conversion, storage, and transmission technologies        |
| carrier          | carrier that an energy balance is calculated for `electricity`, `hydrogen`...|
| impact           | impact categories like EUR or USD, CO 2 − eq., ...                    |
| account          | fixed costs for installation and yearly expenses, variable costs      |
| infrastruct      | infrastructure status being either new or existing                    |
| time K           | numeration of the representative periods                              |
| time T period    | numeration of the time intervals within a period                      |
| time T point     | numeration of the time points within a period                          |
| time I period    | numeration of the time invervals of the full input data periods       |
| time I point     | numeration of the time points of the full input data periods           |
| dir transmission | direction of the flow uniform with or opposite to the lines direction |

## Variables
The variables can have different types:
- `cv`: cost variable - information of the costs
- `dv`: design variable - information of the energy system design
- `ov`: operation variable - information of the energy system operation
- `sv`: slack variable - information of unmet demands or exceeded emission limits
An overview of the variables used in the CEP is provided in the table:

| name      | type | dimensions                 | unit                       | description   |
|-----------|------|----------------------------|----------------------------|------------------|
| COST      | `cv` | [account,impact,tech]      | EUR or USD, LCA-categories | Costs            |
| CAP       | `dv` | [tech,infrastruct,node]    | MW                         | Capacity         |
| GEN       | `ov`  | [tech,carrier,t,k,node]   | MW                         | Generation     |
| SLACK     | `sv`  | [carrier,t,k,node]        | MW                         | Power gap, not provided by installed CAP  |
| LL        | `sv`  | [carrier]                 | MWh                        | LoastLoad Generation gap, not provided by installed CAP  |
| LE        | `sv`  | [impact]                  | LCA-categories             | LoastEmission Amount of emissions that installed CAP crosses the Emission constraint |
| INTRASTOR | `ov` | [tech,carrier,t,k,node]    | MWh                        | Storage level within a period     |
| INTERSTOR | `ov` | [tech,carrier,i,node]      | MWh                        | Storage level between periods of the full time series  |
| FLOW      | `ov` | [tech,carrier,dir,t,k,line]| MW                         | Flow over transmission line   |
| TRANS     | `ov` | [tech,infrastruct,lines]   | MW                         | maximum capacity of transmission lines    |

## Running the Capacity Expansion Problem

!!! note
    The CEP model can be run with many configurations. The configurations themselves don't mess with each other though the provided input data must fulfill the ability to have e.g. lines in order for transmission to work.

An overview is provided in the following table:

| description                                        |  unit            | configuration           | values                                      | type           | default value |
|--------------------------------------------------------------------------------------|------------------|-------------------------|---------------------------------------------|----------------|---------------|
| enforce an emission-limit                          | kg-impact/MWh-carrier | `limit_emission`               | Dict{String,Number}(impact/carrier=>value)                                      | ::Dict{String,Number}       | Dict{String,Number}()           |
| including existing infrastructure (no extra costs) and limit infrastructure   | -                | `infrastructure`| Dict{String,Array}("existing"=>[tech-groups...], "limit"=>[tech-groups...])                             | ::Dict{String,Array}       | Dict{String,Array}("existing"=>["demand"])         |
| type of storage implementation                     | -                | `storage_type`                 | "none", "simple" or "seasonal"              | ::String       | "none"        |
| allowing conversion (necessary for storage)        | -                | `conversion`            | `true` or `false`                               | ::Bool         | false         |
| allowing demand                                    | -                | `demand`            | `true` or `false`                               | ::Bool         | true         |
| allowing dispatchable generation                   | -                | `dispatchable_generation`            | `true` or `false`                               | ::Bool         | false         |
| allowing non dispatchable generation               | -                | `non_dispatchable_generation`            | `true` or `false`                               | ::Bool         | true         |
| allowing transmission                              | -                | `transmission`            | `true` or `false`                               | ::Bool         | false         |
| fix. var and CEO to dispatch problem               | -                | `fixed_design_variables`  | design variables from design run or nothing | ::OptVariables | nothing       |
| allowing lost load (necessary for dispatch)        | price/MWh-carrier| `lost_load_cost`       | Dict{String,Number}(carrier=>value)            | ::Dict{String,Number}      | Dict{String,Number}()           |
| allowing lost emission (necessary for dispatch)    | price/kg-impact  | `lost_emission_cost`  | Dict{String,Number}(impact=>value)              | ::Dict{String,Number}       | Dict{String,Number}()          |

They can be applied in the following way:
```@docs
run_opt
```
## Transmission
A CapacityExpansion model can be run with or without the technology transmission.
!!! note
    If the technology `transmission` is not modeled (`transmission=false`), the transmission between nodes is not restricted, which is equivalent to a copperplate assumption.

!!! note
    Include `transmission=true` and `infrastructure = Dict{String,Array}("existing"=>[...,"transmission"], "limit"=>[...,"transmission"])` to model existing `transmission` and limit the total transmission `TRANS` to the values defined in the `lines.csv` file. If no new transmission should be setup, use the same values for existing transmission and the limit.
## Solver
The package provides no `optimizer` and a solver has to be added separately. For the linear optimization problem suggestions are:
- `Clp` as an open source solver
- `Gurobi` as a proprietary solver with free academic licenses. Gurobi is faster than Clp and we prefer it in the academic setting.
- `CPLEX` as an alternative proprietary solver

Install the corresponding julia-package for the solver and call its `optimizer` like e.g.:
```julia
using Pkg
Pkg.add("Clp")
using Clp
optimizer=Clp.Optimizer
```

## Solver Configuration
Depending on the Solver different solver configurations are possible. The information is always provided as `Dict{Symbol,Any}`. The keys of the dictionary are the parameters and the values of the dictionary are the values passed to the solver.

For example the `Gurobi` solver can be configured to have no OutputFlag and run on two threads (per julia thread) the following way:
```julia
optimizer_config=Dict{Symbol,Any}(:OutputFlag => 0, :Threads => 2)
```
Further information on possible keys for Gurobi can be found at [Gurobi parameter description](https://www.gurobi.com/documentation/8.1/refman/parameter_descriptions.html).

## Scaling
The package features the scaling of variables and equations. Scaling variables, which are used in the numerical model, to `0.01 ≤ x ≤ 100` and scaling equations to `3⋅x = 1` instead of `3000⋅x = 1000` improves the shape of the optimization space and significantly reduces the computational time used to solve the numerical model.

The values are only scaled within the numerical model formulation, where we call the variable `VAR`, but the values are unscaled in the solution, which we call `real-VAR`. The following logic is used to scale the variables:
`real-VAR [EUR, USD, MW, or MWh] = scale[:VAR] ⋅ VAR`
`  0.01 ≤ VAR  ≤ 100`
`⇔ 0.01 ≤ real-VAR / scale[:VAR] ≤ 100`

The equations are scaled with the scaling parameter of the first variable, which is `scale[:COST]` in the following example:
`  scale[:COST]⋅COST = 10⋅scale[:CAP]⋅CAP`
`⇔              COST = 10⋅(scale[:CAP]/scale[:COST])⋅CAP`

### Change scaling parameters
Changing the scaling parameters is useful if the data you use represents a much smaller or bigger energy system than the ones representing Germany and California provided in this package Determine the right scaling parameters by checking the real-values of COST, CAP, GEN... (real-VAR) in a solution using your data. Select the scaling parameters to match the following:
`0.01 ≤ real-VAR / scale[:VAR] ≤ 100`
Create a dictionary with the new scaling parameters for EACH variable and include it as the optional `scale` input to overwrite the default scale in `run_opt`:
```julia
scale=Dict{Symbol,Int}(:COST => 1e9, :CAP => 1e3, :GEN => 1e3, :SLACK => 1e3, :INTRASTOR => 1e3, :INTERSTOR => 1e6, :FLOW => 1e3, :TRANS =>1e3, :LL => 1e6, :LE => 1e9)
scale_result = run_opt(ts_clust_data,cep_data,optimizer;scale=scale)
```

### Adding another variable
- Extend the default `scale`-dictionary in the `src/optim_problems/run_opt`-file to include the new variable as well.
- Include the new variable in the problem formulation in the `src/optim_problems/opt_cep`-file. Reformulate the equations by dividing them by the scaling parameter of the first variable, which is `scale[:COST]` in the following example:
- `  scale[:COST]⋅COST = 10⋅scale[:CAP]⋅CAP                  + 100`
- `⇔              COST = 10⋅(scale[:CAP]/scale[:COST])⋅CAP   + 100/scale[:COST]`
