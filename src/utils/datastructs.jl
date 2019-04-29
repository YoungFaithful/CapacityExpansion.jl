### Data structures ###
abstract type OptData <: InputData end

"""
     OptModelCEP
-model::JuMP.Model
-info::Array{String}
-set::Dict{String,Array}
"""
struct OptModelCEP
  model::JuMP.Model
  info::Array{String}
  set::Dict{String,Array}
end

"""
     OptVariable
-`data::Array` - includes the optimization variable output in  form of an array
-`axes_names::Array{String,1}`` - includes the names of the different axes and is equivalent to the sets in the optimization formulation
-`axes::Tuple` - includes the values of the different axes of the optimization variables
-`type::String` - defines the type of the variable being cv - cost variable - dv -design variable - ov - operating variable - sv - slack variable
"""
struct OptVariable{T,N,Ax,L<:NTuple{N,Dict}} <: AbstractArray{T,N}
    data::Array{T,N}
    axes::Ax
    lookup::L
    axes_names::Array{String,1}
    type::String
end

"""
      OptResult{status::Symbol,objective::Float,variables::Dict{String,Any},sets::Dict{String,Array},opt_config::Dict{String,Any},opt_info::Dict{String,Any}}
- `status`: Symbol about the solution status of the model in normal cases `:OPTIMAL`
- `objective`: Value of the objective function
- `variables`: Dictionary with each OptVariable as an entry
- `sets`: Dictionary with each set as an entry
- `opt_config`: The configuration of the model setup - for more detail see tye `run_opt` documentation that sets the `opt_config` up
- `opt_info`: Holds information about the model. E.g. `opt_info["model"]` contains the exact equations used in the model. 
"""
struct OptResult
 status::Symbol
 objective::Float
 variables::Dict{String,Any}
 sets::Dict{String,Array}
 opt_config::Dict{String,Any}
 opt_info::Dict{String,Any}
end

"""
     OptDataCEP{region::String, costs::OptVariable, techs::OptVariable, nodes::OptVariable, lines::OptVariabl} <: OptData
- `region::String`:          name of state or region data belongs to
- `costs::OptVariable`:    costs[tech,node,year,account,impact] - Number
- `techs::OptVariable`:    techs[tech] - OptDataCEPTech
- `nodes::OptVariable`:    nodes[tech, node] - OptDataCEPNode
- `lines::OptVarible`:     lines[tech, line] - OptDataCEPLine
instead of USD you can also use your favorite currency like EUR
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
     OptDataCEPNode{name::String,value::Number,lat::Number,lon::Number} <: OptData
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
     OptDataCEPLine{name::String,node_start::String,node_end::String,reactance::Number,resistance::Number,power::Number,circuits::Int,voltage::Number,length::Number} <: OptData
- `name`
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
     OptDataCEPTech{name::String,categ::String,sector::String,eff::Number,time_series::String,lifetime::Number,financial_lifetime::Number,discount_rate::Number, annuityfactor::Number} <: OptData
- `name`
- `categ`: the category of this technology (is it storage, transmission or generation)
- `sector`: sector of the technology (electricity or heat)
- `eff`: efficiency of this technologies conversion [-]
- `time_series`: time_series name for availability
- `lifetime`: product lifetime [a]
- `financial_lifetime`: financial time to break even [a]
- `discount_rate`: discount rate for technology [a]
- `annuityfactor`: annuity factor, important for cap-costs [-]
"""
struct OptDataCEPTech <: OptData
  name::String
  categ::String
  sector::String
  eff::Number
  time_series::String
  lifetime::Number
  financial_lifetime::Number
  discount_rate::Number
  annuityfactor::Number
end

"""
  is_in(k::Symbol,table::DataFrame,alt_value::Any)
is Symbol `k` in `table`? Lookup value if true, return `alt_value` if false
"""
function is_in(k::Symbol,table::DataFrame,alt_value::Any)
  if k in names(table)
    return table[k][1]
  else
    @warn "$k not provided in $(repr(table))"
    return alt_value
  end
end


"""
     Scenario{descriptor::String,clust_res::ClustResult,opt_res::OptResult}
-`descriptor::String`
-`clust_res::ClustResult`
-`opt_res::OptResult`
"""
struct Scenario
 descriptor::String
 clust_res::ClustResult
 opt_res::OptResult
end
