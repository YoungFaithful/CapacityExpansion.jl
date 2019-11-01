### Data structures ###
abstract type OptData <: InputData end

"""
     OptModelCEP{
     model::JuMP.Model
     info::Array{String}
     set::Dict{String,Dict{String,Array}}}
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
      OptResult{status::Symbol,
                objective::Float64,
                variables::Dict{String,Any},
                sets::Dict{String,Dict{String,Array}},
                config::Dict{String,Any},
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
 config::Dict{String,Any}
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
                   power_ex::Number
                   power_lim::Number
                   region::String
                   latlon::LatLon} <: OptData
The information about the nodes in stored in an `OptDataCEPNode` struct:
- `name`
- `power_ex` existing capacity [MW or MWh (tech_e)]
- `power_lim` capacity limit [MW or MWh (tech_e)]
- `region` name of the region
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
     OptDataCEPLine{name::String
                   node_start::String
                   node_end::String
                   reactance::Number
                   resistance::Number
                   power_ex::Number
                   power_lim::Number
                   circuits::Int
                   voltage::Number
                   length::Number
                   eff::Number} <: OptData
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
- `unit`: the unit that the capacity of the technology scales with. It can be `power`[MW] or `energy`[MWh]
- `tech_group`: technology-groups that the technology belongs to. Groups can be: `all`, `demand`, `generation`, `dispatchable_generation`, `non_dispatchable_generation`, `storage`, `conversion`, `transmission`
- `plant_lifetime`: the lifetime of this technologies plant [a]
- `financial_lifetime`: financial time to break even [a]
- `annuityfactor`: the annuityfactor is calculated based on the discount_rate and the plant_lifetime
- `discount_rate`: discount rate for technology [a]
- `structure`: `node` or `line` depending on the structure of the technology
- `input`: the input can be a `carrier` like e.g. electricity `"carrier" => "electricity", a `timeseries` like e.g. `"timeseries"=> "demand_electricity"`, or a `fuel` like e.g. `"fuel" => "gas"`
- `output`: the output can be a `carrier` as well
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
