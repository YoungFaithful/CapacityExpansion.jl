### Data structures ###
abstract type OptData <: InputData end

"""
     OptModelCEP
The essential elements of a CapacityExpansionProblem are organized as a `OptModelCEP` struct:
- `model`::JuMP.Model - contains the actual JuMP-Model
- `info`::Array{String} - contains the information about the model setup in form of multiple lines of equations
- `set`::Dict{String,Array} - contains the sets used by the model
"""
struct OptModelCEP
  model::JuMP.Model
  info::Array{String}
  set::Dict{String,Dict{String,Array}}
end

"""
    OptVariable{T,N,Ax,L<:NTuple{N,Dict}} <: AbstractArray{T,N}{
    data::Array{T,N},
    axes::Ax,
    lookup::L,
    axes_names::Array{String,1}}
    type::String
OptVariable is a structure that allows to have a multi-dimensional `data`-Array that can be indexed using keys. An examplary lookup can be done the following way: `optvar['key1','key2']=value`.
The value can be of any type like e.g. `Float64`.
The OptVariable is used both for data input and output.
- `data::Array` - includes the optimization variable output in  form of an array
- `axes_names::Array{String,1}`` - includes the names of the different axes and is equivalent to the sets in the optimization formulation
- `axes::Tuple` - includes the values of the different axes of the optimization variables
- `type::String` - defines the type of the variable being cv - cost variable - dv -design variable - ov - operating variable - sv - slack variable
"""
struct OptVariable{T,N,Ax,L<:NTuple{N,Dict}} <: AbstractArray{T,N}
    data::Array{T,N}
    axes::Ax
    lookup::L
    axes_names::Array{String,1}
    type::String
end

"""
  OptConfig{tech::Dict{String,Bool}
      model::Dict{String,Bool}
      limit_emission::Dict{String,Number}
      scale::Dict{Symbol,Int}
      print_flag::Bool
      optimizer::DataType
      optimizer_config::Dict{Symbol,Any}
      round_sigdigits::Int
      time_series_config::OptConfig}

contains the information that tweaks the model
"""
struct OptConfig
    descriptor::String
    region::String
    model::Dict{String,Bool}
    limit_emission::Dict{String,Dict{String,Number}}
    infrastructure::Dict{String,Array}
    scale::Dict{Symbol,Int}
    optimizer::DataType
    optimizer_config::Dict{Symbol,Any}
    time_series::Dict{String,Any}
    fixed_design_variables::Dict{String,Any}
    lost_load_cost::Dict{String,Number}
    lost_emission_cost::Dict{String,Number}
    print_flag::Bool
    round_sigdigits::Int
end

"""
      OptResult{status::Symbol,
                objective::Float64,
                variables::Dict{String,Any},
                sets::Dict{String,Dict{String,Array}},
                config::OptConfig,
                info::Dict{String,Any}}
The result of an optimized model is organized as an `OptResult` struct:
- `status`: Symbol about the solution status of the model in normal cases `:OPTIMAL`
- `objective`: Value of the objective function
- `variables`: Dictionary with each variables in form of `OptVariable` structs as entries. For details on indexing the `OptVariables` see the `OptVariable` documentation
- `sets`: Dictionary with each set as an entry
- `config`: The configuration of the model setup - for more detail see tye `run_opt` documentation that sets the `config` up
- `info`: Holds information about the model. E.g. `info["model"]` contains the exact equations used in the model.

## Sets
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
| name      | type | dimensions                 | unit                    | description |
|-----------|------|----------------------------|-------------------------|------------|
| COST      | `cv` | [account,impact,tech]      | EUR/USD, LCA-categories | Costs      |
| CAP       | `dv` | [tech,infrastruct,node]    | MW                      | Capacity   |
| GEN       | `ov` | [tech,carrier,t,k,node]    | MW                      | Generation |
| SLACK     | `sv` | [carrier,t,k,node]         | MW                      | Power gap, not provided by installed CAP |
| LL        | `sv` | [carrier]                  | MWh                     | LoastLoad Generation gap, not provided by installed CAP |
| LE        | `sv` | [impact]                   | LCA-categories          | LoastEmission Amount of emissions that installed CAP crosses the Emission constraint |
| INTRASTOR | `ov` | [tech,carrier,t,k,node]    | MWh                     | Storage level within a period |
| INTERSTOR | `ov` | [tech,carrier,i,node]      | MWh                     | Storage level between periods of the full time series |
| FLOW      | `ov` | [tech,carrier,dir,t,k,line]| MW                      | Flow over transmission line |
| TRANS     | `ov` | [tech,infrastruct,lines]   | MW                      | maximum capacity of transmission lines |
"""
struct OptResult
 status::Symbol
 objective::Float64
 variables::Dict{String,Any}
 sets::Dict{String,Dict{String,Array}}
 config::OptConfig
 info::Dict{String,Any}
end

"""
     OptDataCEP{region::String,
                costs::OptVariable,
                techs::OptVariable,
                nodes::OptVariable,
                lines::OptVariabl} <: OptData
All not timeseries depending data for the CapacityExpansionProblem is stored in an `OptDataCEP` struct. `OptVariable` structs are used to index an element of e.g. `.costs['pv','germany',2016,'var','EUR']=value`. Depending on the field the value has another type like `Number`, `OptDataCEPLine`,...
- `region::String`:          name of state or region data belongs to
- `costs::OptVariable`:    costs[tech,node,year,account,impact] - `Number`
- `techs::OptVariable`:    techs[tech] - `OptDataCEPTech`
- `nodes::OptVariable`:    nodes[tech, node] - `OptDataCEPNode`
- `lines::OptVariable`:     lines[tech, line] - `OptDataCEPLine`
"""
struct OptDataCEP <: OptData
   region::String
   costs::OptVariable
   techs::OptVariable
   nodes::OptVariable
   lines::OptVariable
end

#struct LatLon() adapted from Package Geodesy.jl: Copyright (c) 2014-2016: Ted Steiner, Sean Garborg, Yeesian Ng, Andy Ferris, Andrew Smith

#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
"""
    LatLon(lat, lon)
    LatLon(lat = ϕ, lon = Θ)
Latitude and longitude co-ordinates. *Note:* assumes degrees not radians
"""
struct LatLon{T <: Number}
    lat::T
    lon::T
end
LatLon(lat::Number, lon::Number) = LatLon(promote(lat, lon)...)
LatLon(;lat=NaN,lon=NaN) = LatLon(lat,lon) # Constructor that is independent of storage order
Base.show(io::IO, ll::LatLon) = print(io, "LatLon(lat=$(ll.lat)°, lon=$(ll.lon)°)")
Base.isapprox(ll1::LatLon, ll2::LatLon; atol = 1e-6, kwargs...) = isapprox(ll1.lat, ll2.lat; atol = 180*atol/6.371e6, kwargs...) & isapprox(ll1.lon, ll2.lon; atol = 180*atol/6.371e6, kwargs...) # atol in metres (1μm)

"""
     OptDataCEPNode{name::String,
                    value::Number,
                    lat::Number,
                    lon::Number} <: OptData
The information about the nodes in stored in an `OptDataCEPNode` struct:
- `name`
- `power_ex` existing capacity [MW or MWh (tech_e)]
- `power_lim` capacity limit [MW or MWh (tech_e)]
- `region`
- `latlon` hold geolocation information [°,°]
"""
struct OptDataCEPNode <: OptData
  name::String
  power_ex::Number
  power_lim::Number
  region::String
  latlon::LatLon
end

"""
     OptDataCEPLine{name::String,
                    node_start::String,
                    node_end::String,
                    reactance::Number,
                    resistance::Number,
                    power::Number,
                    circuits::Int,
                    voltage::Number,
                    length::Number} <: OptData
The information of the single lines is stored in an `OptDataCEPLine` struct:
- `name`: Name of the line
- `node_start` Node where line starts
- `node_end` Node where line ends
- `reactance`
- `resistance` [Ω]
- `power_ex`: existing power limit [MW]
- `power_lim`: limit power limit [MW]
- `circuits` [-]
- `voltage` [V]
- `length` [km]
- `eff` [-]
"""
struct OptDataCEPLine <: OptData
  name::String
  node_start::String
  node_end::String
  reactance::Number
  resistance::Number
  power_ex::Number
  power_lim::Number
  circuits::Int
  voltage::Number
  length::Number
  eff::Number
end

"""
     OptDataCEPTech{name::String
                   tech_group::Array{String,1}
                   unit::String
                   structure::String
                   plant_lifetime::Number
                   financial_lifetime::Number
                   discount_rate::Number
                   annuityfactor::Number
                   input::Dict
                   output::Dict
                   constraints::Dict} <: OptData
The information of the single tech is stored in an `OptDataCEPTech` struct:
- `name`: A detailed name of the technology
- `tech_group`: technology-groups that the technology belongs to. Groups can be: `all`, `demand`, `generation`, `dispatchable_generation`, `non_dispatchable_generation`, `storage`, `conversion`, `transmission`
- `plant_lifetime`: the lifetime of this technologies plant [a]
- `financial_lifetime`: financial time to break even [a]
- `annuityfactor`: the annuityfactor is calculated based on the discount_rate and the plant_lifetime
- `discount_rate`: discount rate for technology [a]
- `structure`: `node` or `line` depending on the structure of the technology
- `unit`: the unit that the capacity of the technology scales with. It can be `power`[MW] or `energy`[MWh]
- `input`: the input can be a `carrier` like e.g. electricity `"carrier" => electricity, a `timeseries` like e.g. `"timeseries"=> demand_electricity`, or a `fuel` like e.g. `fuel: gas`
- `constraints`: a dictionary with information like an `efficiency` like e.g. `"efficiency"=> 0.53` or `cap_eq` (e.g. discharge capacity is same as charge capacity) `"cap_eq" => "bat_in"`
returns `techs::OptVariable`    techs[tech] - OptDataCEPTech
"""
struct OptDataCEPTech <: OptData
  name::String
  tech_group::Array{String,1}
  unit::String
  structure::String
  plant_lifetime::Number
  financial_lifetime::Number
  discount_rate::Number
  annuityfactor::Number
  input::Dict
  output::Dict
  constraints::Dict
end

"""
     Scenario{descriptor::String,
     clust_res::AbstractClustResult,
     opt_res::OptResult}
A scenario is organized in a `Scenario` struct:
-`descriptor::String`
-`clust_res::AbstractClustResult`
-`opt_res::OptResult`
"""
struct Scenario
    descriptor::String
    clust_res::AbstractClustResult
    opt_res::OptResult
end

"""
        OptConfig(ts_data::ClustData,
                    opt_data::OptDataCEP;
                    descriptor::String="",
                    storage_type::String="none",
                    limit_emission::Dict{String,Number}=Dict{String,Number}(),
                    demand::Bool=true,
                    dispatchable_generation::Bool=true,
                    non_dispatchable_generation::Bool=true,
                    conversion::Bool=false,
                    transmission::Bool=false,
                    lost_load_cost::Dict{String,Number}=Dict{String,Number}(),
                    lost_emission_cost::Dict{String,Number}=Dict{String,Number}(),
                    limit_emission::Dict{String,Number}=Dict{String,Number}(),
                    infrastructure::Dict{String,Array}=Dict{String,Array}("existing"=>["demand"],"limit"=>Array{String,1}()),
                    scale::Dict{Symbol,Int}=Dict{Symbol,Int}(:COST => 1e9, :CAP => 1e3, :GEN => 1e3, :SLACK => 1e3, :INTRASTOR => 1e3, :INTERSTOR => 1e6, :FLOW => 1e3, :TRANS =>1e3, :LL => 1e6, :LE => 1e9),
                    print_flag::Bool=true,
                    optimizer_config::Dict{Symbol,Any}=Dict{Symbol,Any}(),
                    round_sigdigits::Int=9,
                    time_series::Dict{String,Any}=Dict{String,Any}())
Setup the OptConfig that tweaks the model. Options to tweak the model are:
- `descriptor`: A name for the model
- `storage_type`: String `"none"` for no storage, `"simple"` to include simple (only intra-day storage), or `"seasonal"` to include seasonal storage (inter-day)
- `demand`: Bool `true` or `false` for technology-group
- `dispatchable_generation`: Bool `true` or `false` for technology-group
- `non_dispatchable_generation`: Bool `true` or `false` for technology-group
- `conversion`: Bool `true` or `false` for technology-group
- `transmission`:Bool `true` or `false` for technology-group. If no transmission should be modeled, a 'copperplate' is assumed with no transmission restrictions between the nodes
- `limit`: Dictionary with numbers limiting the kg.-emission-eq./MWh (e.g. `CO2` normally in a range from 5-1250 kg-CO2-eq/MWh), give Inf or no kw if unlimited
- `lost_load_cost`: Dictionary with numbers indicating the lost load price per carrier (e.g. `electricity` in price/MWh should be greater than 1e6), give Inf for no SLACK and LL (Lost Load - a variable for unmet demand by the installed capacities)
- `lost_emission_cost`: Dictionary with numbers indicating the emission price/kg-emission (should be greater than 1e6), give Inf for no LE (Lost Emissions - a variable for emissions that will exceed the limit in order to provide the demand with the installed capacities)
- `infrastructure` : Dictionary with Arrays indicating which technology groups should have `existing` infrastructure (`"existing" => ["demand","dispatchable_generation"]`) and which technology groups should have infrastructure `limit`ed (`"limit" => ["non_dispatchable_generation"]`)
- `scale`: Dict{Symbol,Int} with a number for each variable (like `:COST`) to scale the variables and equations to similar quantities. Try to acchieve that the numerical model only has to solve numerical variables in a scale of 0.01 and 100. The following equation is used as a relationship between the real value, which is provided in the solution (real-VAR), and the numerical variable, which is used within the model formulation (VAR): real-VAR [`EUR`, `MW` or `MWh`] = scale[:VAR] ⋅ VAR.
- `descriptor`: String with the name of this paricular model like "kmeans-10-co2-500"
- `print_flag`: Bool to decide if a summary of the Optimization result should be printed.
- `optimizer_config`: Each Symbol and the corresponding value in the Dictionary is passed on to the `with_optimizer` function in addition to the `optimizer`. For Gurobi an example Dictionary could look like `Dict{Symbol,Any}(:Method => 2, :OutputFlag => 0, :Threads => 2)` more information can be found in the optimizer specific documentation.
- `round_sigdigits`: Can be used to round the values of the result to a certain number of `sigdigits`.
"""
function OptConfig(ts_data::ClustData,
                    opt_data::OptDataCEP;
                    descriptor::String="",
                    storage_type::String="none",
                    demand::Bool=true,
                    dispatchable_generation::Bool=true,
                    non_dispatchable_generation::Bool=true,
                    conversion::Bool=false,
                    transmission::Bool=false,
                    lost_load_cost::Dict{String,Number}=Dict{String,Number}(),
                    lost_emission_cost::Dict{String,Number}=Dict{String,Number}(),
                    limit_emission::Dict{String,Number}=Dict{String,Number}(),
                    infrastructure::Dict{String,Array}=Dict{String,Array}("existing"=>["demand"],"limit"=>Array{String,1}()),
                    scale::Dict{Symbol,Int}=Dict{Symbol,Int}(:COST => 1e9, :CAP => 1e3, :GEN => 1e3, :SLACK => 1e3, :INTRASTOR => 1e3, :INTERSTOR => 1e6, :FLOW => 1e3, :TRANS =>1e3, :LL => 1e6, :LE => 1e9),
                    print_flag::Bool=true,
                    optimizer::DataType=DataType,
                    optimizer_config::Dict{Symbol,Any}=Dict{Symbol,Any}(),
                    round_sigdigits::Int=9,
                    time_series_config::Dict{String,Any}=Dict{String,Any}())
    # Activated seasonal or simple storage corresponds with storage
    if storage_type=="seasonal"
        storage=true
        seasonalstorage=true
    elseif storage_type=="simple"
        storage=true
        seasonalstorage=false
    elseif storage_type =="none"
        storage=false
        seasonalstorage=false
    else
        storage=false
        seasonalstorage=false
        warn("String indicating `storage_type` not identified as 'none', 'seasonal' or 'simple' → no storage")
     end
    #The limit_dir is organized as two dictionaries in each other: limit_dir[impact][carrier]='impact/carrier' The first dictionary has the keys of the impacts, the second level dictionary has the keys of the carriers and value of the limit per carrier
    limit_emission=get_limit_dir(limit_emission)

    #Add the modular model configuration
    model=get_model(opt_data; demand=demand, dispatchable_generation=dispatchable_generation, non_dispatchable_generation=non_dispatchable_generation, storage=storage, seasonalstorage=seasonalstorage, conversion=conversion, transmission=transmission)

    #Add the information of the timeseries
    time_series=Dict{String,Any}("years" => ts_data.years, "K" => ts_data.K, "T"=> ts_data.T, "config" => time_series_config, "weights"=>ts_data.weights, "delta_t"=>ts_data.delta_t)

    # Return Directory with the information
    return OptConfig(descriptor, opt_data.region, model, limit_emission, infrastructure, scale, optimizer, optimizer_config, time_series, Dict{String,Any}(), lost_load_cost, lost_emission_cost, print_flag, round_sigdigits)
end

"""
        OptConfig(config::OptConfig;
                fixed_design_variables::Dict{String,Any};
                lost_load_cost::Dict{String,Number}=Dict{String,Number}(),
                lost_emission_cost::Dict{String,Number}=Dict{String,Number}())
`fixed_design_variables`: All the design variables that are determined by the previous design run.
- `optimizer`: The used optimizer, which could e.g. be Clp: `using Clp` `optimizer=Clp.Optimizer` or Gurobi: `using Gurobi` `optimizer=Gurobi.Optimizer`.
What you can change in the `config`:
- `lost_load_cost`: Dictionary with numbers indicating the lost load price per carrier (e.g. `electricity` in price/MWh should be greater than 1e6), give Inf for no SLACK and LL (Lost Load - a variable for unmet demand by the installed capacities)
- `lost_emission_cost`: Dictionary with numbers indicating the emission price/kg-emission (should be greater than 1e6), give Inf for no LE (Lost Emissions - a variable for emissions that will exceed the limit in order to provide the demand with the installed capacities)
"""
function OptConfig(config::OptConfig,
                fixed_design_variables::Dict{String,Any};
                lost_load_cost::Dict{String,Number}=Dict{String,Number}("electricity" => 1e6),
                lost_emission_cost::Dict{String,Number}=Dict{String,Number}("CO2" => 700))
    return OptConfig(config.descriptor, config.region, config.model, config.limit_emission, config.infrastructure, config.scale, config.optimizer, config.optimizer_config, config.time_series, fixed_design_variables, lost_load_cost, lost_emission_cost, config.print_flag, config.round_sigdigits)
end
