#Functions to setup the set-dictionary
"""
    setup_opt_set_tech!(ts_data::ClustData,opt_data::CEPData,opt_config::Dict{String,Any})
Add the entry set["tech"]
"""
function setup_opt_set_tech!(set::Dict{String,Dict{String,Array}},
                            opt_data::OptDataCEP,
                            opt_config::Dict{String,Any})
      #`techs::OptVariable`: techs[tech] - OptDataCEPTech
      techs = opt_data.techs

      set["tech"]["limit"]=Array{String,1}()
      #Loop through all techs
      for tech in axes(techs,"tech")
        #Check if the primary tech-group (first entry within the Array of tech-groups) is in opt_config
        if opt_config[techs[tech].tech_group[1]]
          #Add the technology to the set of all techs
          push!(set["tech"],"all", tech)
          #Loop through all tech_groups for this technology
          for tech_group_name in techs[tech].tech_group
            #Push this tech to the set: `set[tech_group_name]`
            push!(set["tech"],tech_group_name,tech)
            #Existing infrastructure
            if haskey(opt_config["infrastructure"],"existing")
              #Add this tech to the tech-group "existing_infra" or "no_existing_infra" depending if the tech_group is a key within the dictionary `techgroups_exis_inf`
              if in(tech_group_name,opt_config["infrastructure"]["existing"])
                push!(set["tech"],"exist_inf",tech)
              else
                push!(set["tech"],"no_exist_inf",tech)
              end
            end
            #Add this tech to the tech-group "limit", if the tech_group is a key within the dictionary `techgroups_limit_inf`
            if haskey(opt_config["infrastructure"],"limit")
              if in(tech_group_name,opt_config["infrastructure"]["limit"])
                push!(set["tech"],"limit",tech)
              end
            end
          end
          #Push this tech to the set: `set[tech_unit]` - the unit describes if the capacity of this tech is either setup as power or energy capacity
          push!(set["tech"],techs[tech].unit,tech)
          #Push this tech to the set: `set[tech_structure]` - the structure describes if the capacity of this tech is either setup on a node or along a line
          push!(set["tech"],techs[tech].structure,tech)
          #Push the technology as an input-carrier
          if haskey(techs[tech].input, "carrier")
            #Add this technology to the group of the carrier
            push!(set["tech"],techs[tech].input["carrier"],tech)
          end
          #Push the technology as an output-carrier
          if haskey(techs[tech].output, "carrier")
            #Add this technology to the group of the carrier
            push!(set["tech"],techs[tech].output["carrier"],tech)
          end
        end
      end
      return set
end

"""
    setup_opt_set_carrier!(ts_data::ClustData,opt_data::CEPData,opt_config::Dict{String,Any})
Add the entry set["carrier"]
"""
function setup_opt_set_carrier!(set::Dict{String,Dict{String,Array}},
                            opt_data::OptDataCEP,
                            opt_config::Dict{String,Any})
      #`techs::OptVariable`: techs[tech] - OptDataCEPTech
      techs = opt_data.techs
      #Loop through all `tech`s to determine the input and output carriers for each `tech`
      for tech in set["tech"]["all"]
        #Push the technology as an input-carrier
        if haskey(techs[tech].input, "carrier")
          push!(set["carrier"],tech,techs[tech].input["carrier"])
        end
        #Push the technology as an output-carrier
        if haskey(techs[tech].output, "carrier")
          push!(set["carrier"],tech,techs[tech].output["carrier"])
        end
      end
      # Add an element containing all carriers
      set["carrier"]["all"]=unique(vcat(values(set["carrier"])...))
      # Add `carrier` to the tech-group `lost_load` if the carrier is a key within `lost_load_cost`
      set["carrier"]["lost_load"]=intersect(set["carrier"]["all"],keys(opt_config["lost_load_cost"]))
      # Add groups same to the tech_groups to the carriers
      for (k,v) in set["tech"]
        for tech in v
            for carrier in set["carrier"][tech]
              push!(set["carrier"],k,carrier)
          end
        end
      end
      return set
end

"""
    setup_cep_opt_set_impact!(ts_data::ClustData,opt_data::CEPData,opt_config::Dict{String,Any})
Add the entry set["impact"]
"""
function setup_opt_set_impact!(set::Dict{String,Dict{String,Array}},
                            opt_data::OptDataCEP,
                            opt_config::Dict{String,Any})
      #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
      costs = opt_data.costs

      ## IMPACT ##
      #Ensure that group `limit` and `lost_emission` exist empty
      set["impact"]["limit"]=Array{String,1}()
      set["impact"]["lost_emission"]=Array{String,1}()
      #Loop through all impacts
      for impact in axes(costs,"impact")
        #Add impacts to the set of all impacts
        push!(set["impact"],"all",impact)
        #The first impact shall always be monetary impact
        if impact==first(axes(costs,"impact"))
          push!(set["impact"],"mon",impact)
        #All other impacts are environmental impacts
        else
          push!(set["impact"],"env",impact)
        end
        #Add impact to tech-group `limit` if impact is a key within the `limit_emission`
        if haskey(opt_config["limit_emission"],impact)
          push!(set["impact"],"limit",impact)
        end
        # Add impact to tech-group `lost_emission` if impact is a key within the `lost_emission_cost`
        if haskey(opt_config["lost_emission_cost"],impact)
          push!(set["impact"],"lost_emission",impact)
        end
      end
      return set
end

"""
    get_opt_set_impact!(ts_data::ClustData,opt_data::CEPData,opt_config::Dict{String,Any})
Add the entry set["impact"]
"""
function get_opt_set_names(opt_config::Dict{String,Any})

      #Define all set-names that are always included
      set_names=["nodes", "carrier", "tech", "impact", "year", "account", "infrastruct", "time_K", "time_T_point", "time_T_period"]
      #Add set-names that are specific for certain configurations
      if opt_config["transmission"]
        push!(set_names,"lines")
        push!(set_names,"dir_transmission")
      end
      if opt_config["seasonalstorage"]
        push!(set_names,"time_I_point")
        push!(set_names,"time_I_period")
      end
      return set_names
end

"""
    setup_opt_sets(ts_data::ClustData,opt_data::CEPData,opt_config::Dict{String,Any})
fetching sets from the time series (ts_data) and capacity expansion model data (opt_data) and returning dictionary `set`
The dictionary is organized as:
- `set[tech_name][tech_group]=[elements...]`
- `tech_name` is the name of the dimension like e.g. `tech`, or `node`
- `tech_group` is the name of a group of elements within each dimension like e.g. `["all", "generation"]`. The group `'all'` always contains all elements of the dimension
- `[elements...]` is the Array with the different elements like `["pv", "wind", "gas"]`
"""
function setup_opt_set(ts_data::ClustData,
                            opt_data::OptDataCEP,
                            opt_config::Dict{String,Any})
  #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
  costs = opt_data.costs
  #`techs::OptVariable`: techs[tech] - OptDataCEPTech
  techs = opt_data.techs
  #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
  nodes = opt_data.nodes
  #`lines::OptVarible`: lines[tech,line] - OptDataCEPLine
  lines = opt_data.lines

  #Create dictionaries for each set_name
  set=Dict{String,Dict{String,Array}}()
  for set_name in get_opt_set_names(opt_config)
    set[set_name]=Dict{String,Array}()
  end
  # tech - dimension of elements that can do generate, transmit, store, or demand
  setup_opt_set_tech!(set,opt_data,opt_config)
  # carrier - dimension of energy-carriers like `electricity`, `hydrogen`
  setup_opt_set_carrier!(set,opt_data,opt_config)
  # impact - dimension of impact categories (first is monetary)
  setup_opt_set_impact!(set,opt_data,opt_config)
  # node - dimension of spacial resolution for elements with nodal resolution
  set["nodes"]["all"]=axes(nodes,"node")
  # year - annual time dimension
  set["year"]["all"]=axes(costs,"year")
  # account - dimension of cost calculation: capacity&fixed costs that do not vary with the generated power or variable costs that do vary with generated power
  set["account"]["all"]=axes(costs,"account")
  if opt_config["transmission"]
    # lines - dimension of spacial resolution for elements along lines
    set["lines"]["all"]=axes(opt_data.lines,"line")
    # dir_transmission - dimension of directions along a transmission line
    set["dir_transmission"]["all"]=["uniform","opposite"]
  end
  # infrastruct - dimension of status of infrastructure new or existing
  set["infrastruct"]["all"]=["new","ex"]
  # time_K - dimension of clustered time-series periods
  set["time_K"]["all"]=1:ts_data.K
  # time_T - dimension of time within each clustered time-series period:
  #                                         |-----|-----|...
  # either the number of periods            |<-1->|<-2->|...
  set["time_T_period"]["all"]=1:ts_data.T
  # or the number of the points in time    <0>---<1>---<2>...
  set["time_T_point"]["all"]=0:ts_data.T
  if opt_config["seasonalstorage"]
    # time_I - dimension of time within the original timeseries throughout original periods
    # either the number of periods
    set["time_I_period"]["all"]=1:length(ts_data.k_ids)
    # or the number of the points in time
    set["time_I_point"]["all"]=0:length(ts_data.k_ids)
  end
  return set
end
