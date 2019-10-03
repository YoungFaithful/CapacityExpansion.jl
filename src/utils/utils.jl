"""
    check_column(df::DataFrame, names_array::Array{Symbol,1})
check if the columns provided in `names_array` exist in the DataFrame `df`
throw an error if they don't
"""
function check_column(df::DataFrame, names_array::Array{Symbol,1})
    for name in names_array
        #Check existance of necessary column
        name in names(df) || throw(@error "No column called `$name` in $(repr(df))")
    end
end

#Use getindex to return all rows of the DataFrame fulfilling that in column `col` value `val` is found
function Base.getindex(df::DataFrame, col_and_val::Tuple{Symbol,Any})
    return df[findall(df[!,col_and_val[1]].==col_and_val[2]), :]
end

#Use getindex to return all rows of the DataFrame fulfilling that in column `col` value `val` is found and the column `colon_ind`
function Base.getindex(df::DataFrame, col_and_val::Tuple{Symbol,Any}, colon_ind::Symbol)
    return df[findall(df[!,col_and_val[1]].==col_and_val[2]), colon_ind]
end

"""
    get_cep_design_variables(opt_result::OptResult)
Returns all design variables in this opt_result matching the type "dv"
Additionally you can add capacity factors, which scale the design variables by multiplying it with the value in the Dict
"""
function get_cep_design_variables(opt_result::OptResult)
  design_variables=get_cep_variables(opt_result, "dv")
  return design_variables
end

"""
    get_cep_slack_variables(opt_result::OptResult)
Returns all slack variables in this `opt_result` mathing the type "sv"
"""
function get_cep_slack_variables(opt_result::OptResult)
  return get_cep_variables(opt_result, "sv")
end

"""
    get_cep_variables(opt_result::OptResult, variable_type::String)
The variables can be of different type. The different groups of variables can be extracted from the `OptResult` based on the `variable_type`:
Returns all variables which types match the String `variable_type`
"""
function get_cep_variables(opt_result::OptResult, variable_type::String)
  variables=Dict{String,Any}()
  for (key,val) in opt_result.variables
      if val.type==variable_type
          variables[key]=val
      end
  end
  if isempty(variables)
      throw(@error("$variable_type-Variable not provided in $(opt_result.descriptor)"))
  else
      return variables
  end
end

"""
    set_config_cep(opt_data::OptDataCEP; kwargs...)
kwargs can be whatever you need to run the run_opt
it can hold
  -  `fixed_design_variables`: Dictionary{String,Any}
  -  `transmission`: true or false
  -  `generation`: true or false
  -  `storage_p`: true or false
  -  `storage_e`: true or false
  -  `existing_infrastructure`: true or false
  -  `descritor`: a String like "kmeans-10-co2-500" to describe this CEP-Model
  -  `first_stage_vars`: a Dictionary containing the OptVariables from a previous run
The function also checks if the provided data matches your kwargs options (e.g. it let's you know if you asked for transmission, but you have no tech with it in your data)
Returning Dictionary with the variables as entries
"""
function set_config_cep(opt_data::OptDataCEP
                            ;kwargs...)
  # Create new Dictionary and set possible unique tech_groups to false to later check wrong setting
  config=Dict{String,Any}("demand"=>false, "transmission"=>false, "storage"=>false, "conversion"=>false, "non_dispatchable_generation"=>false, "dispatchable_generation"=>false)
  # Check the existence of the tech_group (like generation or storage - see techs.yml) and write it into Dictionary
  for tech_group in unique(vcat(getfield.(opt_data.techs[:], :tech_group)...))
    config[tech_group]=true
  end
  # Loop through the kwargs and write them into Dictionary
  for kwarg in kwargs
    # Check for false combination
    if String(kwarg[1]) in keys(config)
      if config[String(kwarg[1])]==false && kwarg[2]
        throw(@error("Option "*String(kwarg[1])*" cannot be selected with input data provided for "*opt_data.region))
      end
    end
    config[String(kwarg[1])]=kwarg[2]
  end

  # Return Directory with the information
  return config
end

"""
    set_config_cep!(config::Dict{String,Any}; kwargs...)
add or replace items to an existing config:
- `fixed_design_variables`: `Dict{String,OptVariable}``
- `slack_cost`: Number
"""
function set_config_cep!(config::Dict{String,Any}
                            ;kwargs...)
  # Loop through the kwargs and add them to Dictionary
  for kwarg in kwargs
    config[String(kwarg[1])]=kwarg[2]
  end

  # Return Directory with the information
  return config
end

"""
    check_opt_data_cep(opt_data::OptDataCEP)
Check the consistency of the data
"""
function check_opt_data_cep(opt_data::OptDataCEP)
  # Check lines
  # Only when Data provided
  if !isempty(opt_data.lines)
    # Check existence of start and end node
    for tech in axes(opt_data.lines,"tech")
      for node in getfield.(opt_data.lines[tech,:],:node_end)
        if !(node in axes(opt_data.nodes, "node"))
          throw(@error("Node "*node*" set as ending node, but not included in nodes-Data"))
        end
      end
    end
  end
end

"""
    get_total_demand(cep::OptModelCEP, ts_data::ClustData)
Return the total demand by multiplying demand with deltas and weights for the OptModel CEP
"""
function get_total_demand(cep::OptModelCEP,
                          ts_data::ClustData)
  ## DATA ##
  set=cep.set
  #ts          Dict( tech-node ): t x k
  ts=ts_data.data
  #ts_weights: k - weight of each period:
  ts_weights=ts_data.weights
  #ts_deltas:  t x k - Δt of each segment x period
  ts_deltas=ts_data.delta_t
  total_demand=0
  for node in set["nodes"]["all"]
    for t in set["time_T_period"]["all"]
      for k in set["time_K"]["all"]
        total_demand+=ts["demand_electricity-"*node][t,k]*ts_deltas[t,k]*ts_weights[k]
      end
    end
  end

  return total_demand
end

"""
        get_cost_series(nodes::DataFrame,
                        var_costs::DataFrame,
                       clust_res::ClustResult,
                       set::Dict{String,Array},
                       variables::Dict{String,OptVariable})
Return an array for the time series of costs in all the impact dimensions and the set of impacts
"""
function get_cost_series(nodes::DataFrame,
                        var_costs::DataFrame,
                       clust_res::ClustResult,
                       set::Dict{String,Array},
                       variables::Dict{String,OptVariable})
  ## DATA ##
  # ts_ids:   n_clustered periods
  ts_ids=clust_res.best_ids
  #ts_weights: k - weight of each period:
  ts_weights=clust_res.clust_data.weights
  #ts_deltas:  t x k - Δt of each segment x period
  ts_deltas=clust_res.clust_data.delta_t

  #emision at each period-step
  cost_ts=zeros(length(ts_ids)+1,length(set["impact"]))
  #At the beginning yearly fixed and cap costs
  cost_ts[1,:]=sum(get_cep_variable_value(variables["COST"],["cap_fix",:,:]),dims=2)

  for n in 1:length(ts_ids)
        var_cost=zeros(length(set["impact"]))
        i=1
        for impact in set["impact"]
          for tech in set["tech"]
            for node in set["nodes"]["all"]
              var_cost[i] += find_cost_in_df(var_costs,nodes,tech,node,impact)*  sum(get_cep_variable_value(variables["GEN"],["el",tech,:,ts_ids[n],node])' * ts_deltas[:,ts_ids[n]])
            end
          end
          i+=1
        end
        cost_ts[n+1,:]=cost_ts[n,:]+var_cost
  end
  return cost_ts, set["impact"]
end

"""
    get_cost_series(opt_data::OptDataCEP,scenario::Scenario)
Return an array for the time series of costs in all the impact dimensions and the set of impacts
"""
function get_cost_series(opt_data::OptDataCEP,scenario::Scenario)
  return get_cost_series(opt_data.nodes,opt_data.var_costs,scenario.clust_res, scenario.opt_res.model_set,scenario.opt_res.variables)
end

"""
    get_met_cap_limit(cep::OptModelCEP, opt_data::OptDataCEP, variables::Dict{String,OptVariable})
Return the technologies that meet the capacity limit
"""
function get_met_cap_limit(cep::OptModelCEP, opt_data::OptDataCEP, variables::Dict{String,Any})
  ## DATA ##
  # Set
  set=cep.set
  # nodes with limits
  nodes=opt_data.nodes
  lines=opt_data.lines

  met_cap_limit=Array{String,1}()
  # For all
  if haskey(set["tech"],"node")
    for tech in set["tech"]["node"]
      for node in set["nodes"]["all"]
        #Check if the limit is reached in any capacity at any node
        if sum(variables["CAP"][tech,:,node]) == nodes[tech,node].power_lim
          #Add this technology and node to the met_cap_limit Array
          push!(met_cap_limit,tech*"-"*node)
        end
      end
    end
  end
  if haskey(set["tech"],"line")
    for tech in set["tech"]["line"]
      for line in set["lines"]["all"]
        #Check if the limit is reached in any capacity at any line
        if sum(variables["TRANS"][tech,:,line]) == lines[tech,line].power_lim
          #Add this technology and line to the met_cap_limit Array
          push!(met_cap_limit,tech*"-"*line)
        end
      end
    end
  end
  # If the array isn't empty throw an error (as limits are only for numerical speedup)
  if !isempty(met_cap_limit)
    #TODO change to warning
    @warn("Limit is reached for techs $met_cap_limit")
  end
  return met_cap_limit
end

import Base.push!
"""
  push!(set::Dict{String,Array},key::String,value::Any)

Push a `value` into the Array of `set[key]`. If no Array `set[key]` exists, setup new Array
"""
function push!(set::Dict{String,Array},key::String,value::Any)
  if key in keys(set)
    #If value not already in set[key]
    if !(value in set[key])
      push!(set[key],value)
    end
  else
    set[key]=[value]
  end
end

"""
    get_limit_dir(limit::Dict{String,Number})
The limit_dir is organized as two dictionaries in each other: limit_dir[impact][carrier]='impact/carrier' The first dictionary has the keys of the impacts, the second level dictionary has the keys of the carriers and value of the limit per carrier
"""
function get_limit_dir(limit::Dict{String,Number})
    limit_dir=Dict{String,Dict}()
    for (impact, carrier) in split.(keys(limit),"/")
        if !haskey(limit_dir, impact)
            limit_dir[impact]=Dict{String,Number}()
        end
        limit_dir[impact][String(carrier)]=limit[join([impact carrier], "/")]
    end
    return limit_dir
end

"""
    text_limit_emission(limit_emission::Dict{String,Dict{String,Number}})
Return text with the information of the `limit_emission` as a text
"""
function text_limit_emission(limit_emission::Dict{String,Dict})
  text_limit=""
  for (emission,carriers) in limit_emission
    for (carrier,value) in carriers
      text_limit*="$emission-Emission ≤ $value [kg-$emission-eq. per MWh-$carrier],"
    end
  end
  return text_limit
end
