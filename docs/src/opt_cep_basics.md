# Basics
## Variables and Sets
The models scalability is relying on the usage of sets. The elements of the sets are extracted from the input data and scale the different variables. An overview of the sets is provided in the table. Depending on the models configuration the necessary sets are initialized.

| name             | description                                                           |
|------------------|-----------------------------------------------------------------------|
| lines            | transmission lines connecting the nodes                               |
| nodes            | spacial energy system nodes                                           |
| tech             | fossil and renewable generation as well as storage technologies       |
| impact           | impact categories like EUR or USD, CO 2 − eq., ...                    |
| account          | fixed costs for installation and yearly expenses, variable costs      |
| infrastruct      | infrastructure status being either new or existing                    |
| sector           | energy sector like electricity                                        |
| time K           | numeration of the representative periods                              |
| time T           | numeration of the time intervals within a period                      |
| time T e         | numeration of the time steps within a period                          |
| time I           | numeration of the time invervals of the full input data periods       |
| time I e         | numeration of the time steps of the full input data periods           |
| dir transmission | direction of the flow uniform with or opposite to the lines direction |



An overview of the variables used in the CEP is provided in the table:

| name      | dimensions                 | unit                    | description                                                                          |
|-----------|----------------------------|-------------------------|--------------------------------------------------------------------------------------|
| COST      | [account,impact,tech]      | EUR/USD, LCA-categories | Costs                                                                                |
| CAP       | [tech,infrastruct,node]    | MW                      | Capacity                                                                             |
| GEN       | [sector,tech,t,k,node]     | MW                      | Generation                                                                           |
| SLACK     | [sector,t,k,node]          | MW                      | Power gap, not provided by installed CAP                                             |
| LL        | [sector]                   | MWh                     | LoastLoad Generation gap, not provided by installed CAP                              |
| LE        | [impact]                   | LCA-categories          | LoastEmission Amount of emissions that installed CAP crosses the Emission constraint |
| INTRASTOR | [sector, tech,t,k,node]    | MWh                     | Storage level within a period                                                        |
| INTERSTOR | [sector,tech,i,node]       | MWh                     | Storage level between periods of the full time series                                |
| FLOW      | [sector,dir,tech,t,k,line] | MW                      | Flow over transmission line                                                          |
| TRANS     | [tech,infrastruct,lines]   | MW                      | maximum capacity of transmission lines                                               |

## Data

The package provides data [Capacity Expansion Data](@ref) for:

| name   | nodes                                                | lines | years     | tech                                                                         |
|--------|------------------------------------------------------|-------|-----------|------------------------------------------------------------------------------|
| GER-1  | 1 – germany as single node                           | none  | 2006-2016 | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| GER-18 | 18 – dena-zones within germany                       | 49    | 2015      | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| CA-1   | 1 - california as single node                        | none  | 2016      | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| CA-14 ! currently not included ! | 14 – multiple nodes within CA and neighboring states | 46    | 2016      | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| TX-1   | 1 – single node within Texas                         | none  | 2008      | Pv, wind, coal, nuc, gas, bat-e, bat-in, bat-out                             |

### Units
- Power - MW
- Energy - MWh
- lengths - km

## Running the Capacity Expansion Problem

!!! note
    The CEP model can be run with many configurations. The configurations themselves don't mess with each other though the provided input data must fulfill the ability to have e.g. lines in order for transmission to work.

An overview is provided in the following table:

| description                                                                          |  unit            | configuration           | values                                      | type           | default value |
|--------------------------------------------------------------------------------------|------------------|-------------------------|---------------------------------------------|----------------|---------------|
| enforce a CO2-limit                                                                  | kg-CO2-eq./MW    | co2_limit               | >0                                          | ::Number       | Inf           |
| including existing infrastructure (no extra costs)                                   | -                | existing_infrastructure | true or false                               | ::Bool         | false         |
| type of storage implementation                                                       | -                | storage                 | "none", "simple" or "seasonal"              | ::String       | "none"        |
| allowing transmission                                                                | -                | transmission            | true or false                               | ::Bool         | false         |
| fix. var and CEO to dispatch problem | -                | fixed_design_variables  | design variables from design run or nothing | ::OptVariables | nothing       |
| allowing lost load (necessary for dispatch)                        | price/MWh        | lost_el_load_cost       | >1e6                                        | ::Number       | Inf           |
| allowing lost emission (necessary for dispatch)                    | price/kg_CO2-eq. | lost_CO2_emission_cost  | >700                                        | ::Number       | Inf           |

They can be applied in the following way:
```@docs
run_opt
```
## Opt Result - A closer look
```@docs
OptVariable
OptResult
```
!!! note
    The model tracks how it is setup and which equations are used. This can help you to understand the models exact configuration without looking up the source code.

The information of the model setup can be checked out the following way:
```@setup opt_info
using CEP
using Clp
optimizer=Clp.Optimizer
state="GER_1"
years=[2016]
ts_input_data = load_timeseries_data_provided(state;T=24, years=years)
cep_data = load_cep_data_provided(state)
## CLUSTERING ##
ts_clust_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=10,n_clust=5) # default k-means make sure that n_init is high enough otherwise the results could
```
```@example opt_info
result = run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="Model Name")
result.opt_info["model"]
```
