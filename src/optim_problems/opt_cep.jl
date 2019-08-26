# CEP
"""
    setup_cep_opt_sets(ts_data::ClustData,opt_data::CEPData,opt_config::Dict{String,Any})
fetching sets from the time series (ts_data) and capacity expansion model data (opt_data) and returning Dictionary with Sets as Symbols
"""
function setup_opt_cep_set(ts_data::ClustData,
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

  set=Dict{String,Any}()
  set["nodes"]=axes(nodes,"node")
  #Set for all carriers used as inputs and outputs in techs
  set["carrier"]=Dict{String,Array}()
  #Set for all tech in techs
  set["tech"]=Dict{String,Array}()
  #Loop through all techs
  for tech in axes(techs,"tech")
    #Check if the primary tech-group (first entry within the Array of tech-groups) is in opt_config
    if opt_config[techs[tech].tech_group[1]]
      #Add the technology to the set of all techs
      push!(set["tech"],"all", tech)
      #Loop through all tech_groups for this technology
      for tech_group in techs[tech].tech_group
        #Define the name for the tech-group as a combination of `tech_` and the tech-group-name
        tech_group_name=tech_group
        #Push this tech to the set: `set[tech_group_name]`
        push!(set["tech"],tech_group_name,tech)
      end
      #Push this tech to the set: `set[tech_unit]` - the unit describes if the capacity of this tech is either setup as power or energy capacity
      push!(set["tech"],techs[tech].unit,tech)
      #Push this tech to the set: `set[tech_structure]` - the structure describes if the capacity of this tech is either setup on a node or along a line
      push!(set["tech"],techs[tech].structure,tech)
      #Push the technology as an input-carrier
      if haskey(techs[tech].input, "carrier")
        push!(set["carrier"],tech,techs[tech].input["carrier"])
        #Add this technology to the group of the carrier
        push!(set["tech"],techs[tech].input["carrier"],tech)
      end
      #Push the technology as an output-carrier
      if haskey(techs[tech].output, "carrier")
        push!(set["carrier"],tech,techs[tech].output["carrier"])
        #Add this technology to the group of the carrier
        push!(set["tech"],techs[tech].output["carrier"],tech)
      end
    end
  end
  # Add an element containing all carriers
  set["carrier"]["all"]=unique(vcat(values(set["carrier"])...))
  # Add groups same to the tech_groups to the carriers
  for (k,v) in set["tech"]
    for tech in v
        for carrier in set["carrier"][tech]
          push!(set["carrier"],k,carrier)
      end
    end
  end
  #Create new Dictionary for impacts with the sets impact-all, impact-mon (monetary), and impact-env (environmental)
  set["impact"]=Dict{String,Array}()
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
  end
  set["year"]=axes(costs,"year")
  set["account"]=axes(costs,"account")
  if opt_config["transmission"]
    set["lines"]=axes(opt_data.lines,"line")
    set["dir_transmission"]=["uniform","opposite"]
  end
  if opt_config["existing_infrastructure"]
    set["infrastruct"]=["new","ex"]
  else
    set["infrastruct"]=["new"]
  end
  set["time_K"]=1:ts_data.K
  set["time_T_period"]=1:ts_data.T
  set["time_T_point"]=0:ts_data.T
  if opt_config["seasonalstorage"]
    set["time_I_point"]=0:length(ts_data.k_ids)
    set["time_I_period"]=1:length(ts_data.k_ids)
  end
  return set
end


"""
    setup_cep_opt_basic(ts_data::ClustData,opt_data::CEPData,opt_config::Dict{String,Any},optimizer::DataType,optimizer_config::Dict{Symbol,Any})
setting up the basic core elements for a CEP-model
- a JuMP Model is setup and the optimizer is configured. The optimizer itself is passed on as a `optimizer`. It's configuration with `optimizer_config` - Each Symbol and the corresponding value in the Dictionary is passed on to the `with_optimizer` function in addition to the optimizer. For Gurobi an example Dictionary could look like `Dict{Symbol,Any}(:Method => 2, :OutputFlag => 0, :Threads => 2)`
- the sets are setup
"""
function setup_opt_cep_basic(ts_data::ClustData,
                            opt_data::OptDataCEP,
                            opt_config::Dict{String,Any},
                            optimizer::DataType,
                            optimizer_config::Dict{Symbol,Any})
   ## MODEL CEP ##
   # Initialize model
   model =  JuMP.Model(with_optimizer(optimizer;optimizer_config...))
   # Initialize info
   info=[opt_config["descriptor"]]
   # Setup set
   set=setup_opt_cep_set(ts_data, opt_data, opt_config)
   # Setup Model CEP
   return OptModelCEP(model,info,set)
 end


"""
    setup_opt_cep_basic_variables!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
Adding basic variables COST, CAP and GEN based on set
"""
function setup_opt_cep_basic_variables!(cep::OptModelCEP,
                                  ts_data::ClustData,
                                  opt_data::OptDataCEP)
  ## DATA ##
  set=cep.set

  ## VARIABLES ##
  # Cost
  push!(cep.info,"Variable COST[account, impact, tech] in $(set["impact"]["all"].*" "...)") #Note that variable COST is scaled only within the model with the value scale[:COST]: Real-COST [`EUR` or `USD`] = scale[:COST] ⋅ COST (numeric variable within model)
  @variable(cep.model, COST[account=set["account"],impact=set["impact"]["all"],tech=set["tech"]["all"]])
  # Capacity
  push!(cep.info,"Variable CAP[tech_n, infrastruct, nodes] ≥ 0 in MW") #Note that variable CAP is scaled only within the model with the value scale[:CAP]: Real-CAP ['MW'] = scale[:CAP] ⋅ CAP (numeric variable within model)
  @variable(cep.model, CAP[tech=set["tech"]["node"],infrastruct=set["infrastruct"] ,node=set["nodes"]]>=0)
  # Generation #
  push!(cep.info,"Variable GEN[carrier, tech_power, t, k, node] in MW") #Note that variable is scaled only within the model
  @variable(cep.model, GEN[carrier=set["carrier"]["all"], tech=set["tech"][carrier], t=set["time_T_period"], k=set["time_K"], node=set["nodes"]])
  #end
  return cep
end

"""
     setup_opt_cep_lost_load!(cep::OptModelCEP, ts_data::ClustData, opt_data::OptDataCEP) set::Dict)
Adding variable SLACK, LL (LostLoad - if demand cannot be met with installed capacity -> Lost Load can be "purchased" to meet demand)
"""
function setup_opt_cep_lost_load!(cep::OptModelCEP,
                                  ts_data::ClustData,
                                  opt_data::OptDataCEP,
                                  scale::Dict{Symbol,Int})
  ## DATA ##
  set=cep.set
  #ts_weights: k - weight of each period:
  ts_weights=ts_data.weights
  #ts_deltas:  t x k - Δt of each segment x period
  ts_deltas=ts_data.delta_t

  ## LOST LOAD ##
  # Slack variable #
  push!(cep.info,"Variable SLACK[carrier, t, k, node] ≥ 0 in MW") #Note that variable is scaled only within the model
  @variable(cep.model, SLACK[carrier=set["carrier"]["all"], t=set["time_T_period"], k=set["time_K"], node=set["nodes"]] >=0)
  # Lost Load variable #
  push!(cep.info,"Variable LL[carrier, node] ≥ 0 in MWh") #Note that variable is scaled only within the model
  @variable(cep.model, LL[carrier=set["carrier"]["all"], node=set["nodes"]] >=0)
  # Calculation of Lost Load
  ### Scaling: Scaling is applied to all variables based on the parameters provided in the Dictionary scale. Each variable is multiplied with the scaling parameter 'scale[:VARNAME]' for numerical speedup of the code. We typically devide the equations with the scaling parameter of the left side variable: In this example we divided the entire equation with the scaling parameter of :SLACK which is 'scale[:SLACK]'
  push!(cep.info,"LL[carrier, node] = Σ SLACK[carrier, t, k, node] ⋅ ts_weights[k] ⋅ Δt[t,k] ∀ carrier, node")
  @constraint(cep.model, [carrier=set["carrier"]["all"], node=set["nodes"]], cep.model[:LL][carrier, node]==sum(cep.model[:SLACK][carrier, t, k, node]*ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"], k=set["time_K"])*scale[:SLACK]/scale[:LL])
  return cep
end

"""
     setup_opt_cep_lost_emission!(cep::OptModelCEP, ts_data::ClustData, opt_data::OptDataCEP)
Adding variable LE (LostEmission - if demand cannot be met without breaking Emission-constraint -> Lost Emission can be "purchased" to meet demand with "dirty" production)
"""
function setup_opt_cep_lost_emission!(cep::OptModelCEP,
                              ts_data::ClustData,
                              opt_data::OptDataCEP)
  ## DATA ##
  set=cep.set

  ## LOST EMISSION ##
  # Lost Emission variable #
  push!(cep.info,"Variable LE[impact_{environment}] ≥ 0 in kg")
  @variable(cep.model, LE[impact=set["impact"]["env"]] >=0)
  return cep
end

"""
     setup_opt_cep_fix_design_variables!(cep::OptModelCEP,ts_data::ClustData, opt_data::OptDataCEP,fixed_design_variables::Dict{String,Any})
Fixing variables CAP based on first stage vars
"""
function setup_opt_cep_fix_design_variables!(cep::OptModelCEP,
                                  ts_data::ClustData,
                                  opt_data::OptDataCEP,
                                  scale::Dict{Symbol,Int},
                                  fixed_design_variables::Dict{String,Any})
  ## DATA ##
  set=cep.set
  cap=fixed_design_variables["CAP"]
  ## VARIABLES ##
  # Line based
  if haskey(set["tech"],"line")
    trans=fixed_design_variables["TRANS"]
    push!(cep.info,"TRANS[tech, 'new', line] = existing infrastructure ∀ tech_trans, line")
    @constraint(cep.model, [line=set["lines"], tech=set["tech"]["line"]], cep.model[:TRANS][tech,"new",line]==trans[tech, "new", line]/scale[:TRANS])
  end
  # Node based
  push!(cep.info,"CAP[tech, 'new', node] = existing infrastructure ∀ tech_n, node")
  @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["node"]], cep.model[:CAP][tech,"new",node]==cap[tech, "new", node]/scale[:CAP])
  return cep
end

"""
     setup_opt_cep_demand!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
add variable and fixed Costs and limit generation to installed capacity (and limiting time_series, if dependency in techs defined) for fossil and renewable power plants
"""
function setup_opt_cep_demand!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech] - OptDataCEPTech
    techs = opt_data.techs
    #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
    nodes = opt_data.nodes
    #ts          Dict( tech-node ): t x k
    ts=ts_data.data
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    ## DEMAND ##
    # Calculate Variable Costs of the demand
    push!(cep.info,"COST['var',impact,tech] = Σ_{t,k,node}GEN[carrier_input,t,k,node]⋅ ts_weights[k] ⋅ ts_deltas[t,k]⋅ var_costs[tech,impact] ∀ impact, tech_demand")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["demand"]], cep.model[:COST]["var",impact,tech]==sum(cep.model[:GEN][techs[tech].input["carrier"],tech,t,k,node]*ts_weights[k]*ts_deltas[t,k]*costs[tech,node,set["year"][1],"var",impact] for node=set["nodes"], t=set["time_T_period"], k=set["time_K"])*scale[:GEN]/scale[:COST])
    # Calculate Fixed Costs for the capacity installed for the demand
    push!(cep.info,"COST['cap_fix',impact,tech] = Σ_{t,k}(ts_weights ⋅ ts_deltas[t,k])/8760h ⋅ Σ_{node}CAP[tech,'new',node] ⋅ cap_costs[tech,impact] ∀ impact, tech_demand")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["demand"]], cep.model[:COST]["cap_fix",impact,tech]==sum(ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"], k=set["time_K"])/8760* sum(cep.model[:CAP][tech,"new",node]*costs[tech,node,set["year"][1],"cap_fix",impact] for node=set["nodes"])*scale[:CAP]/scale[:COST])
    # Fix the demand
    push!(cep.info,"GEN[carrier,tech, t, k, node] = Σ_{infrastruct}CAP[tech,infrastruct,node]*ts[tech-node,t,k] ∀ node, tech_demand, t, k")
    @constraint(cep.model, [tech=set["tech"]["demand"], node=set["nodes"], t=set["time_T_period"], k=set["time_K"]], cep.model[:GEN][techs[tech].input["carrier"],tech,t,k,node] == sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"])*ts[techs[tech].output["timeseries"]*"-"*node][t,k]*scale[:CAP]/scale[:GEN])
    return cep
end

"""
     setup_opt_cep_generation!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
add variable and fixed Costs and limit generation to installed capacity (and limiting time_series, if dependency in techs defined) for fossil and renewable power plants
"""
function setup_opt_cep_generation!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech] - OptDataCEPTech
    techs = opt_data.techs
    #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
    nodes = opt_data.nodes
    #ts          Dict( tech-node ): t x k
    ts=ts_data.data
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t


    ## GENERATION ELECTRICITY ##
    # Calculate Variable Costs
    push!(cep.info,"COST['var',impact,tech] = Σ_{t,k,node}GEN[carrier_output,t,k,node]⋅ ts_weights[k] ⋅ ts_deltas[t,k]⋅ var_costs[tech,impact] ∀ impact, tech_generation")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["generation"]], cep.model[:COST]["var",impact,tech]==sum(cep.model[:GEN][techs[tech].output["carrier"],tech,t,k,node]*ts_weights[k]*ts_deltas[t,k]*costs[tech,node,set["year"][1],"var",impact] for node=set["nodes"], t=set["time_T_period"], k=set["time_K"])*scale[:GEN]/scale[:COST])
    # Calculate Fixed Costs
    push!(cep.info,"COST['cap_fix',impact,tech] = Σ_{t,k}(ts_weights ⋅ ts_deltas[t,k])/8760h ⋅ Σ_{node}CAP[tech,'new',node] ⋅ cap_costs[tech,impact] ∀ impact, tech_generation")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["generation"]], cep.model[:COST]["cap_fix",impact,tech]==sum(ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"], k=set["time_K"])/8760* sum(cep.model[:CAP][tech,"new",node]*costs[tech,node,set["year"][1],"cap_fix",impact] for node=set["nodes"])*scale[:CAP]/scale[:COST])
    # Limit the generation of dispathables to the infrastructing capacity of dispachable power plants
    push!(cep.info,"0 ≤ GEN[carrier,tech, t, k, node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_generation{dispatchable}, t, k")
    # Limit the generation of dispathables to the infrastructing capacity of dispachable power plants
    @constraint(cep.model, [tech=set["tech"]["dispatchable_generation"], node=set["nodes"], t=set["time_T_period"], k=set["time_K"]], 0 <=cep.model[:GEN][techs[tech].output["carrier"],tech, t, k, node])
    @constraint(cep.model, [tech=set["tech"]["dispatchable_generation"], node=set["nodes"], t=set["time_T_period"], k=set["time_K"]],     cep.model[:GEN][techs[tech].output["carrier"],tech, t, k, node] <=sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"])*scale[:CAP]/scale[:GEN])
    # Limit the generation of dispathables to the infrastructing capacity of non-dispachable power plants
    push!(cep.info,"0 ≤ GEN['el',tech, t, k, node] ≤ Σ_{infrastruct}CAP[tech,infrastruct,node]*ts[tech-node,t,k] ∀ node, tech_generation{non_dispatchable}, t, k")
    # Limit the generation of non-dispathable generation to the infrastructing capacity of non-dispachable power plants
    @constraint(cep.model, [tech=set["tech"]["non_dispatchable_generation"], node=set["nodes"], t=set["time_T_period"], k=set["time_K"]], 0 <=cep.model[:GEN][techs[tech].output["carrier"], tech, t, k, node])
    @constraint(cep.model, [tech=set["tech"]["non_dispatchable_generation"], node=set["nodes"], t=set["time_T_period"], k=set["time_K"]],  cep.model[:GEN][techs[tech].output["carrier"],tech,t,k,node] <= sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"])*ts[techs[tech].input["timeseries"]*"-"*node][t,k]*scale[:CAP]/scale[:GEN])
    return cep
end

"""
     setup_opt_cep_conversion!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
"""
function setup_opt_cep_conversion!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech] - OptDataCEPTech
    techs = opt_data.techs
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights

    ## conversion ELECTRICITY ##
    # Calculate Variable Costs
    push!(cep.info,"COST['var',impact,tech] = Σ_{t,k,node}GEN[carrier_output,t,k,node]⋅ ts_weights[k] ⋅ ts_deltas[t,k]⋅ var_costs[tech,impact] ∀ impact, tech_conversion")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["conversion"]], cep.model[:COST]["var",impact,tech]==sum(cep.model[:GEN][techs[tech].output["carrier"],tech,t,k,node]*ts_weights[k]*ts_deltas[t,k]*costs[tech,node,set["year"][1],"var",impact] for node=set["nodes"], t=set["time_T_period"], k=set["time_K"])*scale[:GEN]/scale[:COST])
    # Calculate Fixed Costs
    push!(cep.info,"COST['cap_fix',impact,tech] = Σ_{t,k}(ts_weights ⋅ ts_deltas[t,k])/8760h ⋅ Σ_{node}CAP[tech,'new',node] ⋅ cap_costs[tech,impact] ∀ impact, tech_conversion")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["conversion"]], cep.model[:COST]["cap_fix",impact,tech]==sum(ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"], k=set["time_K"])/8760* sum(cep.model[:CAP][tech,"new",node]*costs[tech,node,set["year"][1],"cap_fix",impact] for node=set["nodes"])*scale[:CAP]/scale[:COST])

    push!(cep.info,"0 ≥ GEN[carrier_input, tech, t, k, node] ≥ (-1) ⋅ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_conversion, t, k")
    @constraint(cep.model, [carrier=techs[tech].input["carrier"], node=set["nodes"], tech=set["tech"]["conversion"], t=set["time_T_period"], k=set["time_K"]], 0 >= cep.model[:GEN][carrier,tech,t,k,node])
    @constraint(cep.model, [carrier=techs[tech].input["carrier"], node=set["nodes"], tech=set["tech"]["conversion"], t=set["time_T_period"], k=set["time_K"]], cep.model[:GEN][carrier,tech,t,k,node]>=-sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"])*scale[:CAP]/scale[:GEN])

    push!(cep.info,"GEN[carrier_output,tech, t, k, node] = (-1) ⋅ η[carrier_output, tech] ⋅ GEN[carrier_input, tech, t, k, node] ∀ node, tech_storage_in, t, k")
    @constraint(cep.model, [carrier_in=techs[tech].input["carrier"], carrier_out=techs[tech].output["carrier"], node=set["nodes"], tech=set["tech"]["conversion"], t=set["time_T_period"], k=set["time_K"]], cep.model[:GEN][carrier_out,tech,t,k,node] == techs[tech].constraints["efficiency"] * cep.model[:GEN][carrier_in,tech,t,k,node])
    #TODO add multiple outputs and inputs
    push!(cep.info,"CAP[tech, 'new', node] = CAP[tech_{in}, 'new', node] ∀ node, tech_{EUR-Cap-Cost out/in==0}")
    if haskey("cap_eq", techs[tech].constraints)
        @constraint(cep.model, [node=set["nodes"]], cep.model[:CAP][tech,"new",node] == cep.model[:CAP][techs[tech].constraints["cap_eq"],"new",node])
    end
    return cep
end

"""
     setup_opt_cep_storage!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
add variables INTRASTORGEN and INTRASTOR, variable and fixed Costs, limit generation to installed power-capacity, connect simple-storage levels (within period) with generation
basis for either simplestorage or seasonalstorage
"""
function setup_opt_cep_storage!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech] - OptDataCEPTech
    techs = opt_data.techs
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    ## VARIABLE ##existing_infrastructure
    # Storage has additional element 0 for storage at hour 0 of day
    push!(cep.info,"Variable INTRASTOR[carrier, tech_storage_e, t, k, node] ≥ 0 in MWh") #Note that variable is scaled only within the model
    @variable(cep.model, INTRASTOR[carrier=set["carrier"]["storage"], tech=set["tech"][carrier], t=set["time_T_point"], k=set["time_K"], node=set["nodes"]] >=0)
    # Storage generation is necessary for the efficiency
    #push!(cep.info,"Variable INTRASTORGEN[carrier, dir, tech, t, k, node] ≥ 0 in MW")
    #@variable(cep.model, INTRASTORGEN[carrier=set["carrier"], dir=set["dir_storage"], tech=set["tech_storage_p"], t=set["time_T_period"], k=set["time_K"], node=set["nodes"]] >=0)
    ## STORAGE ##
    # Calculate Variable Costs
    push!(cep.info,"COST['var',impact,tech] = 0 ∀ impact, tech_storage")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=[set["tech"]["conversion"];set["tech"]["storage"]]], cep.model[:COST]["var",impact,tech]==0)
    # Fix Costs storage
    push!(cep.info,"COST['fix',impact,tech] = Σ_{t,k}(ts_weights ⋅ ts_deltas[t,k])/8760h ⋅ Σ_{node}CAP[tech,'new',node] ⋅ costs[tech,node,year,'cap_fix',impact] ∀ impact, tech_storage")
    @constraint(cep.model, [tech=set["tech"]["storage"], impact=set["impact"]["all"]], cep.model[:COST]["cap_fix",impact,tech]==sum(ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"], k=set["time_K"])/8760* sum(cep.model[:CAP][tech,"new",node]*costs[tech,node,set["year"][1],"cap_fix",impact] for node=set["nodes"])*scale[:CAP]/scale[:COST])

    # Connect the previous storage level and the integral of the flows with the new storage level
    push!(cep.info,"INTRASTOR[carrier,tech, t, k, node] = INTRASTOR[carrier,tech, t-1, k, node] η[tech]^(ts_deltas[t,k]/732h) + ts_deltas[t,k] ⋅ (-1) ⋅ (GEN[carrier,tech, t, k, node] ∀ carrier(tech), node, tech_storage, t, k")
    @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"], t in set["time_T_period"], k=set["time_K"]], cep.model[:INTRASTOR][techs[tech].input["carrier"],tech,t,k,node]==cep.model[:INTRASTOR][techs[tech].input["carrier"],tech,t-1,k,node]*(techs[tech].constraints["efficiency"])^(ts_deltas[t,k]/732) - ts_deltas[t,k] * (cep.model[:GEN][techs[tech].input["carrier"],tech,t,k,node])*scale[:GEN]/scale[:INTRASTOR])

    return cep
end

"""
     setup_opt_cep_simplestorage!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
Adding only intra-day storage:
Looping constraint for each period (same start and end level for all periods) and limit storage to installed energy-capacity
"""
function setup_opt_cep_simplestorage!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`techs::OptVariable`: techs[tech] - OptDataCEPTech
    techs = opt_data.techs

    ## INTRASTORAGE ##
    # Limit the storage of the theoretical energy part of the battery to its installed power
    push!(cep.info,"INTRASTOR['el',tech, t, k, node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_storage, t, k")
    @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"], t=set["time_T_period"], k=set["time_K"]], cep.model[:INTRASTOR][techs[tech].input["carrier"],tech,t,k,node]<=sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"])*scale[:CAP]/scale[:INTRASTOR])
    # Set storage level at beginning and end of day equal
    push!(cep.info,"INTRASTOR['el',tech, '0', k, node] = INTRASTOR['el',tech, 't[end]', k, node] ∀ node, tech_storage_e, k")
    @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"], k=set["time_K"]], cep.model[:INTRASTOR][techs[tech].input["carrier"],tech,0,k,node]== cep.model[:INTRASTOR][techs[tech].input["carrier"],tech,set["time_T_point"][end],k,node])
    # Set the storage level at the beginning of each representative day to the same
    push!(cep.info,"INTRASTOR['el',tech, '0', k, node] = INTRASTOR['el',tech, '0', k, node] ∀ node, tech_storage_e, k")
    @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"], k=set["time_K"]], cep.model[:INTRASTOR][techs[tech].input["carrier"],tech,0,k,node]== cep.model[:INTRASTOR][techs[tech].input["carrier"],tech,0,1,node])
    return cep
end

"""
     setup_opt_cep_seasonalstorage!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
Adding inter-day storage:
add variable INTERSTOR, calculate seasonal-storage-level and limit total storage to installed energy-capacity
"""
function setup_opt_cep_seasonalstorage!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #K identification numbers
    k_ids=ts_data.k_ids

    ## VARIABLE ##
    # Storage
    push!(cep.info,"Variable INTERSTOR[carrier, tech, i, node] ≥ 0 in MWh") #Note that variable is scaled only within the model
    @variable(cep.model, INTERSTOR[carrier=set["carrier"]["all"], tech=set["tech"]["storage"], i=set["time_I_point"], node=set["nodes"]]>=0)


    ## INTERSTORAGE ##
    # Set storage level at the beginning of the year equal to the end of the year
    push!(cep.info,"INTERSTOR[carrier,tech, '0', node] = INTERSTOR[carrier,tech, 'end', node] ∀ node, tech_storage, t, k")
    @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"]], cep.model[:INTERSTOR]["el",tech,0,node]== cep.model[:INTERSTOR]["el",tech,set["time_I_point"][end],node])
    # Connect the previous seasonal-storage level and the daily difference of the corresponding simple-storage with the new seasonal-storage level
    push!(cep.info,"INTERSTOR[carrier,tech, i+1, node] = INTERSTOR[carrier,tech, i, node] + INTRASTOR[carrier,tech, 'k[i]', 't[end]', node] - INTRASTOR[carrier,tech, 'k[i]', '0', node] ∀ node, tech_storage_e, i")
    # Limit the total storage (seasonal and simple) to be greater than zero and less than total storage cap
    push!(cep.info,"0 ≤ INTERSTOR[carrier,tech, i, node] + INTRASTOR[carrier,tech, t, k[i], node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_storage_e, i, t")
    push!(cep.info,"0 ≤ INTERSTOR[carrier,tech, i, node] + INTRASTOR[carrier,tech, t, k[i], node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_storage_e, i, t")
    for i in set["time_I_period"]
        @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"]], cep.model[:INTERSTOR]["el",tech,i,node] == cep.model[:INTERSTOR]["el",tech,i-1,node] + (cep.model[:INTRASTOR]["el",tech,set["time_T_period"][end],k_ids[i],node] - cep.model[:INTRASTOR]["el",tech,0,k_ids[i],node])*scale[:INTRASTOR]/scale[:INTERSTOR])
        @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"], t=set["time_T_point"]], 0 <= cep.model[:INTERSTOR]["el",tech,i,node]+cep.model[:INTRASTOR]["el",tech,t,k_ids[i],node]*scale[:INTRASTOR]/scale[:INTERSTOR])
        @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["storage"], t=set["time_T_point"]], cep.model[:INTERSTOR]["el",tech,i,node]+cep.model[:INTRASTOR]["el",tech,t,k_ids[i],node]*scale[:INTRASTOR]/scale[:INTERSTOR] <= sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"])*scale[:CAP]/scale[:INTERSTOR])
    end
    return cep
end

"""
     setup_opt_cep_transmission!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
Setup variable FLOW and TRANS, calculate fixed and variable COSTs, set CAP-trans to zero, limit FLOW with TRANS, calculate GEN-trans for each node
"""
function setup_opt_cep_transmission!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`lines::OptVarible`: lines[tech,line] - OptDataCEPLine
    lines = opt_data.lines
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t
    ## VARIABLE ##
    # Add varibale FLOW
    push!(cep.info,"Variable FLOW[carrier, dir, tech_transmission, t, k, line] ≥ 0 in MW") #Note that variable is scaled only within the model
    @variable(cep.model, FLOW[carrier=set["carrier"][tech], dir=set["dir_transmission"], tech=set["tech"]["transmission"], t=set["time_T_period"], k=set["time_K"], line=set["lines"]] >= 0)
    # Add variable TRANS
    push!(cep.info,"Variable TRANS[tech_transmission,  infrastruct, lines] ≥ 0 in MW") #Note that variable is scaled only within the model
    @variable(cep.model, TRANS[tech=set["tech"]["transmission"], infrastruct=set["infrastruct"], line=set["lines"]] >= 0)

    ## TRANSMISSION ##
    # Calculate Variable Costs
    push!(cep.info,"COST['var',impact,tech] = 0 ∀ impact, tech_transmission")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["transmission"]], cep.model[:COST]["var",impact,tech] == 0)
    # Calculate Fixed Costs
    push!(cep.info,"COST['cap-fix',impact,tech] = Σ_{t,k}(ts_weights ⋅ ts_deltas[t,k])/8760h ⋅ Σ_{node}(TRANS[tech,'new',line] ⋅ length[line]) ⋅ (cap_costs[tech,impact]+fix_costs[tech,impact]) ∀ impact, tech_transmission")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["transmission"]], cep.model[:COST]["cap_fix",impact,tech] == sum(ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"], k=set["time_K"])/8760* sum(cep.model[:TRANS][tech,"new",line]*lines[tech,line].length *(costs[tech,lines[tech,line].node_start,set["year"][1],"cap_fix",impact]) for line=set["lines"])*scale[:TRANS]/scale[:COST])
    # Limit the flow per line to the existing infrastructure
    push!(cep.info,"| FLOW[carrier, dir, tech, t, k, line] | ≤ Σ_{infrastruct}TRANS[tech,infrastruct,line] ∀ line, tech_transmission, t, k")
    @constraint(cep.model, [carrier=set["carrier"][tech], line=set["lines"], dir=set["dir_transmission"], tech=set["tech"]["transmission"], t=set["time_T_period"], k=set["time_K"]], cep.model[:FLOW][carrier,dir, tech, t, k, line] <= sum(cep.model[:TRANS][tech,infrastruct,line] for infrastruct=set["infrastruct"])*scale[:TRANS]/scale[:FLOW])
    # Calculate the sum of the flows for each node
    push!(cep.info,"GEN[carrier,tech, t, k, node] = Σ_{line-end(node)} FLOW['el','uniform',tech, t, k, line] - Σ_{line_pos} FLOW['el','opposite',tech, t, k, line] / (η[tech]⋅length[line]) + Σ_{line-start(node)} Σ_{line_pos} FLOW['el','opposite',tech, t, k, line] - FLOW['el','uniform',tech, t, k, line] / (η[tech]⋅length[line])∀ tech_transmission, t, k")
    for node in set["nodes"]
      @constraint(cep.model, [carrier=set["carrier"][tech], tech=set["tech"]["transmission"], t=set["time_T_period"], k=set["time_K"]], cep.model[:GEN][carrier,tech, t, k, node] == (sum(cep.model[:FLOW][carrier,"uniform",tech, t, k, line_end] - cep.model[:FLOW][carrier,"opposite",tech, t, k, line_end]/lines[tech,line_end].eff for line_end=set["lines"][getfield.(lines[tech,:], :node_end).==node]) + sum(cep.model[:FLOW][carrier,"opposite",tech, t, k, line_start] - cep.model[:FLOW][carrier,"uniform",tech, t, k, line_start]/lines[tech,line_start].eff for line_start=set["lines"][getfield.(lines[tech,:], :node_start).==node]))*scale[:FLOW]/scale[:GEN])
    end
    return cep
end

"""
    setup_opt_cep_energy_balance!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,lost_load_cost::Dict{String,Number}=Dict{String,Number}("electricity"=>Inf))
Add energy-balance which shall be matched by the generation (GEN)
"""
function setup_opt_cep_energy_balance!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int};
                            lost_load_cost::Dict{String,Number}=Dict{String,Number}("electricity"=>Inf))
  ## DATA ##
  set=cep.set
  #ts          Dict( tech-node ): t x k
  ts=ts_data.data
  ## DEMAND ##
  #Test for all carriers if transmission should be modeled: If trans is true, the transmission has to be accomplished using the transmission capacity, If trans is false, a copperplate is assumed for all carriers
  trans=haskey(set["tech"],"transmission")
  #Loop through each carrier
  for carrier in set["carrier"]["all"]
      #Test if for each carrier:
      #if lost_load cost is allowed or not: If lost_load is true, the load of this carrier can also be met by the lost load. If lost_load is false, the load of this carrier has to be met with the generation only
      lost_load=lost_load_cost[carrier]!=Inf
      if trans && lost_load
        # Force the demand and slack to match the generation either with transmission
        push!(cep.info,"Σ_{tech}GEN[carrier,tech,t,k,node] = ts[el_demand-node,t,k]-SLACK[carrier,t,k,node] ∀ node,t,k")
        @constraint(cep.model, [node=set["nodes"], t=set["time_T_period"], k=set["time_K"]], sum(cep.model[:GEN][carrier,tech,t,k,node] for tech=set["tech"][carrier]) + (cep.model[:SLACK][carrier,t,k,node]*scale[:SLACK])/scale[:GEN] ==0)
      elseif !(trans) && lost_load
        # or on copperplate
        push!(cep.info,"Σ_{tech,node}GEN[carrier,tech,t,k,node]= Σ_{node}ts[el_demand-node,t,k]-SLACK[carrier,t,k,node] ∀ t,k")
        @constraint(cep.model, [t=set["time_T_period"], k=set["time_K"]], sum(cep.model[:GEN][carrier,tech,t,k,node] for node=set["nodes"], tech=set["tech"][carrier]) + sum(cep.model[:SLACK][carrier,t,k,node]*scale[:SLACK] for node=set["nodes"])/scale[:GEN] == 0)
      elseif trans && !lost_load
        # Force the demand without slack to match the generation either with transmission
        push!(cep.info,"Σ_{tech}GEN[carrier,tech,t,k,node] = ts[el_demand-node,t,k] ∀ node,t,k")
        @constraint(cep.model, [node=set["nodes"], t=set["time_T_period"], k=set["time_K"]], sum(cep.model[:GEN][carrier,tech,t,k,node] for tech=set["tech"][carrier]) == 0)
      else
        # or on copperplate
        push!(cep.info,"Σ_{tech,node}GEN[carrier,tech,t,k,node]= Σ_{node}ts[el_demand-node,t,k]∀ t,k")
        @constraint(cep.model, [t=set["time_T_period"], k=set["time_K"]], sum(cep.model[:GEN][carrier,tech,t,k,node] for node=set["nodes"], tech=set["tech"][carrier]) == 0)
      end
    end
    return cep
end

"""
     setup_opt_cep_co2_limit!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP;co2_limit::Number=Inf,lost_emission_cost::Dict{String,Number}=Dict{String,Number}("CO2"=>Inf))
Add co2 emission constraint
"""
function setup_opt_cep_limit!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int};
                            limit::Dict{String,Dict}=Dict{String,Dict}("CO2"=>Dict{String,Number}("electricity"=>Inf)),
                            lost_emission_cost::Dict{String,Number}=Dict{String,Number}("CO2"=>Inf))
  ## DATA ##
  set=cep.set
  #ts          Dict( tech-node ): t x k
  ts=ts_data.data
  #ts_weights: k - weight of each period:
  ts_weights=ts_data.weights
  #ts_deltas:  t x k - Δt of each segment x period
  ts_deltas=ts_data.delta_t

  ## EMISSIONS ##
  #Loop through all impacts and carriers in the reorganized limit_dir. The limit_dir is organized as two dictionaries in each other: limit_dir[impact][carrier]='impact/carrier' The first dictionary has the keys of the impacts, the second level dictionary has the keys of the carriers and value of the limit per carrier
  for (impact,carriers) in limit
    println(limit[impact][first(keys(carriers))])
    #The constraint for one impact shall add all impacts per carrier for that particular impact.
    #Is lost emission allowed for this impact category?
    if lost_emission_cost[impact]!=Inf
      # Limit the Emissions with limit[impact] and allow lost emissions
      push!(cep.info,"ΣCOST_{account,tech}[account,'$impact',tech] ≤ LE[impact] + ∑limit[impactpercarrier] Σ_{node,t,k} ts[demand_carrier-node,t,k] ⋅ ts_weights[k] ⋅ ts_deltas[t,k]")
      @constraint(cep.model, sum(cep.model[:COST][account,impact,tech] for account=set["account"], tech=set["tech"]["all"])<= (cep.model[:LE][impact]*scale[:LE] +  sum(sum(limit[impact][carrier]*ts["demand_"*carrier*"-"*node][t,k] for carrier=keys(carriers))*ts_deltas[t,k]*ts_weights[k] for t=set["time_T_period"], k=set["time_K"], node=set["nodes"]))/scale[:COST])
    else
      # Limit the Emissions with limit[impact] and do NOT allow lost emissions
      # Total demand can also be determined with the function get_total_demand() edit both in case of changes of e.g. ts_deltas
      push!(cep.info,"ΣCOST_{account,tech}[account,'$(set["impact"]["mon"])',tech] ≤ limit[impactpercarrier] ⋅ Σ_{node,t,k} ts[el_demand-node,t,k] ⋅ ts_weights[k] ⋅ ts_deltas[t,k]")
      @constraint(cep.model, sum(cep.model[:COST][account,impact,tech] for account=set["account"], tech=set["tech"]["all"])<= sum(sum(limit[impact][carrier]*ts["demand_"*carrier*"-"*node][t,k] for carrier=keys(carriers))*ts_deltas[t,k]*ts_weights[k] for t=set["time_T_period"], k=set["time_K"], node=set["nodes"])/scale[:COST])
    end
  end
  return cep
end

"""
     setup_opt_cep_existing_infrastructure!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
fixing existing infrastructure to CAP[tech, 'ex', node]
"""
function setup_opt_cep_existing_infrastructure!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
  ## DATA ##
  set=cep.set
  #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
  nodes = opt_data.nodes
  #`lines::OptVarible`: lines[tech,line] - OptDataCEPLine
  lines = opt_data.lines

  ## ASSIGN VALUES ##
  # Assign the existing capacity from the nodes table
  push!(cep.info,"CAP[tech, 'ex', node] = existing infrastructure ∀ node, tech")
  @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["node"]], cep.model[:CAP][tech,"ex",node]==nodes[tech,node].power_ex/scale[:CAP])
  if haskey(set["tech"],"transmission")
    push!(cep.info,"TRANS[tech, 'ex', line] = existing infrastructure ∀ tech, line")
    @constraint(cep.model, [line=set["lines"], tech=set["tech"]["line"]], cep.model[:TRANS][tech,"ex",line]==lines[tech,line].power_ex/scale[:TRANS])
  end
  return cep
end

"""
     setup_opt_cep_limit_infrastructure!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
limit infrastructure setup of CAP[tech, sum(infrastuct), node]
NOTE just for CAP not for TRANS implemented
"""
function setup_opt_cep_limit_infrastructure!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
  ## DATA ##
  set=cep.set
  #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
  nodes = opt_data.nodes
  #`lines::OptVarible`: lines[tech,line] - OptDataCEPLine
  lines = opt_data.lines

  ## ASSIGN VALUES ##
  # Limit the capacity for each tech at each node with the limit provided in nodes table in column infrastruct
  push!(cep.info,"∑_{infrastuct} CAP[tech, infrastruct, node] <= limit infrastructure ∀ tech_n, node")
  @constraint(cep.model, [node=set["nodes"], tech=set["tech"]["node"]], sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"]) <= nodes[tech,node].power_lim/scale[:CAP])
  if haskey(set["tech"],"transmission")
    push!(cep.info,"∑_{infrastuct} TRANS[tech, infrastruct, line] <= limit infrastructure ∀ tech_trans, line")
    @constraint(cep.model, [line=set["lines"], tech=set["tech"]["line"]], sum(cep.model[:TRANS][tech,infrastruct,line] for infrastruct=set["infrastruct"]) <= lines[tech,line].power_lim/scale[:TRANS])
  end
  return cep
end

"""
     setup_opt_cep_objective!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP)
Calculate total system costs and set as objective
"""
function setup_opt_cep_objective!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int};
                            lost_load_cost::Dict{String,Number}=Dict{String,Number}("electricity"=>Inf),
                            lost_emission_cost::Dict{String,Number}=Dict{String,Number}("CO2"=>Inf))
  ## DATA ##
  set=cep.set

  ## OBJECTIVE ##
  # Minimize the total €-Costs s.t. the Constraints introduced above
  if lost_load_cost["electricity"]==Inf && lost_emission_cost["CO2"]==Inf
    push!(cep.info,"min Σ_{account,tech}COST[account,'$(set["impact"]["mon"])',tech] st. above")
    @objective(cep.model, Min,  sum(cep.model[:COST][account,first(set["impact"]["mon"]),tech] for account=set["account"], tech=set["tech"]["all"]))
  elseif lost_load_cost["electricity"]!=Inf && lost_emission_cost["CO2"]==Inf
    push!(cep.info,"min Σ_{account,tech}COST[account,'$(set["impact"]["mon"])',tech] + Σ_{node} LL['el'] ⋅ $(lost_load_cost["el"]) st. above")
    @objective(cep.model, Min,  sum(cep.model[:COST][account,set["impact"]["mon"],tech] for account=set["account"], tech=set["tech"]["all"]) + sum(cep.model[:LL]["el",node] for node=set["nodes"])*lost_load_cost["el"][:LL]*scale[:LL]/scale[:COST])
  elseif lost_load_cost["electricity"]==Inf && lost_emission_cost["CO2"]!=Inf
    push!(cep.info,"min Σ_{account,tech}COST[account,'$(set["impact"]["mon"])',tech] +  LE['CO2'] ⋅ $(lost_emission_cost["CO2"]) st. above")
    @objective(cep.model, Min,  sum(cep.model[:COST][account,set["impact"]["mon"],tech] for account=set["account"], tech=set["tech"]["all"]) +  cep.model[:LE]["CO2"]*lost_emission_cost["CO2"]*scale[:LE]/scale[:COST])
  else
    push!(cep.info,"min Σ_{account,tech}COST[account,'$(set["impact"]["mon"])',tech] + Σ_{node} LL['el'] ⋅ $(lost_load_cost["el"]) +  LE['CO2'] ⋅ $(lost_emission_cost["CO2"]) st. above")
    @objective(cep.model, Min,  sum(cep.model[:COST][account,set["impact"]["mon"],tech] for account=set["account"], tech=set["tech"]["all"]) + sum(cep.model[:LL]["el",node] for node=set["nodes"])*lost_load_cost["el"]*scale[:LL]/scale[:COST] + cep.model[:LE]["CO2"]*lost_emission_cost["CO2"]*scale[:LE]/scale[:COST])
  end
  return cep
end

"""
     solve_opt_cep(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,opt_config::Dict{String,Any})
solving the cep model and writing it's results and `co2_limit` into an OptResult-Struct
"""
function solve_opt_cep(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            opt_config::Dict{String,Any})
  optimize!(cep.model)
  status=Symbol(termination_status(cep.model))
  scale=opt_config["scale"]
  objective=objective_value(cep.model)*scale[:COST]
  total_demand=get_total_demand(cep,ts_data)
  return cep
end
#=
  variables=Dict{String,Any}()
  # cv - Cost variable, dv - design variable, which is used to fix variables in a dispatch model, ov - operational variable
  variables["COST"]=OptVariable(cep,:COST,"cv",scale)
  variables["CAP"]=OptVariable(cep,:CAP,"dv",scale)
  variables["GEN"]=OptVariable(cep,:GEN,"ov",scale)
  lost_load=0
  lost_emission=0
  if opt_config["lost_load_cost"]["el"]!=Inf
    variables["SLACK"]=OptVariable(cep,:SLACK,"sv",scale)
    variables["LL"]=OptVariable(cep,:LL,"sv",scale)
    lost_load=sum(variables["LL"].data)
  end
  if opt_config["lost_emission_cost"]["CO2"]!=Inf
    variables["LE"]=OptVariable(cep,:LE,"sv",scale)
    lost_emission=sum(variables["LE"].data)
  end
  if opt_config["storage_in"] && opt_config["storage_out"] && opt_config["storage_e"]
    variables["INTRASTOR"]=OptVariable(cep,:INTRASTOR,"ov",scale)
    if opt_config["seasonalstorage"]
      variables["INTERSTOR"]=OptVariable(cep,:INTERSTOR,"ov",scale)
    end
  end
  if opt_config["transmission"]
    variables["TRANS"]=OptVariable(cep,:TRANS,"dv",scale)
    variables["FLOW"]=OptVariable(cep,:FLOW,"ov",scale)
  end
  get_met_cap_limit(cep, opt_data, variables)
  currency=variables["COST"].axes[2][1]
  if lost_load==0 && lost_emission==0
    opt_config["print_flag"] && @info("Solved Scenario $(opt_config["descriptor"]): "*String(status)*" min COST: $(round(objective,sigdigits=4)) [$currency] ⇨ $(round(objective/total_demand,sigdigits=4)) [$currency per MWh] s.t. Emissions ≤ $(opt_config["co2_limit"]) [kg-CO₂-eq. per MWh]")
  else
    cost=variables["COST"]
    opt_config["print_flag"] && @info("Solved Scenario $(opt_config["descriptor"]): "*String(status)*" min COST: $(round(sum(cost[:,axes(cost,"impact")[1],:]),sigdigits=4)) [$currency] ⇨ $(round(sum(cost[:,axes(cost,"impact")[1],:])/total_demand,sigdigits=4)) [$currency per MWh] with LL: $lost_load [MWh] s.t. Emissions ≤ $(opt_config["co2_limit"]) + $(round(lost_emission/total_demand,sigdigits=4)) (violation) [kg-CO₂-eq. per MWh]")
  end
  opt_info=Dict{String,Any}("total_demand"=>total_demand,"model"=>cep.info,)
  return OptResult(status,objective,variables,cep.set,opt_config,opt_info)
end
=#
