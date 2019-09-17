# Functions to setup the CapacityExpansion optimization model
"""
    setup_opt_basic(ts_data::ClustData,opt_data::CEPData,config::Dict{String,Any},optimizer::DataType,optimizer_config::Dict{Symbol,Any})
setting up the basic core elements for a CEP-model
- a JuMP Model is setup and the optimizer is configured. The optimizer itself is passed on as a `optimizer`. It's configuration with `optimizer_config` - Each Symbol and the corresponding value in the Dictionary is passed on to the `with_optimizer` function in addition to the optimizer. For Gurobi an example Dictionary could look like `Dict{Symbol,Any}(:Method => 2, :OutputFlag => 0, :Threads => 2)`
- the sets are setup
"""
function setup_opt_basic(ts_data::ClustData,
                            opt_data::OptDataCEP,
                            config::Dict{String,Any},
                            optimizer::DataType,
                            optimizer_config::Dict{Symbol,Any})
   ## MODEL CEP ##
   # Initialize model
   model =  JuMP.Model(with_optimizer(optimizer;optimizer_config...))
   # Initialize info
   info=[config["descriptor"]]
   # Setup set
   set=setup_opt_set(ts_data, opt_data, config)
   # Setup Model CEP
   return OptModelCEP(model,info,set)
 end


"""
    setup_opt_basic_variables!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
Adding basic variables COST, CAP and GEN based on set
"""
function setup_opt_basic_variables!(cep::OptModelCEP,
                                  ts_data::ClustData,
                                  opt_data::OptDataCEP)
  ## DATA ##
  set=cep.set

  ## VARIABLES ##
  # Cost
  push!(cep.info,"Variable COST[account, impact, tech] in $(set["impact"]["all"].*" "...)") #Note that variable COST is scaled only within the model with the value scale[:COST]: Real-COST [`EUR` or `USD`] = scale[:COST] ⋅ COST (numeric variable within model)
  @variable(cep.model, COST[account=set["account"]["all"],impact=set["impact"]["all"],tech=set["tech"]["all"]])
  # Capacity
  push!(cep.info,"Variable CAP[tech_n, infrastruct, nodes] ≥ 0 in MW") #Note that variable CAP is scaled only within the model with the value scale[:CAP]: Real-CAP ['MW'] = scale[:CAP] ⋅ CAP (numeric variable within model)
  @variable(cep.model, CAP[tech=set["tech"]["node"],infrastruct=set["infrastruct"]["all"] ,node=set["nodes"]["all"]]>=0)
  # Generation #
  push!(cep.info,"Variable GEN[tech_power, carrier, t, k, node] in MW") #Note that variable is scaled only within the model
  @variable(cep.model, GEN[tech=set["tech"]["all"], carrier=set["carrier"][tech], t=set["time_T_period"]["all"], k=set["time_K"]["all"], node=set["nodes"]["all"]])
  #end
  return cep
end

"""
     setup_opt_lost_load!(cep::OptModelCEP, ts_data::ClustData, opt_data::OptDataCEP) set::Dict)
Adding variable SLACK, LL (LostLoad - if demand cannot be met with installed capacity -> Lost Load can be "purchased" to meet demand)
"""
function setup_opt_lost_load!(cep::OptModelCEP,
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
  @variable(cep.model, SLACK[carrier=set["carrier"]["lost_load"], t=set["time_T_period"]["all"], k=set["time_K"]["all"], node=set["nodes"]["all"]] >=0)
  # Lost Load variable #
  push!(cep.info,"Variable LL[carrier, node] ≥ 0 in MWh") #Note that variable is scaled only within the model
  @variable(cep.model, LL[carrier=set["carrier"]["lost_load"], node=set["nodes"]["all"]] >=0)
  # Calculation of Lost Load
  ### Scaling: Scaling is applied to all variables based on the parameters provided in the Dictionary scale. Each variable is multiplied with the scaling parameter 'scale[:VARNAME]' for numerical speedup of the code. We typically devide the equations with the scaling parameter of the left side variable: In this example we divided the entire equation with the scaling parameter of :SLACK which is 'scale[:SLACK]'
  push!(cep.info,"LL[carrier, node] = Σ SLACK[carrier, t, k, node] ⋅ ts_weights[k] ⋅ Δt[t,k] ∀ carrier, node")
  @constraint(cep.model, [carrier=set["carrier"]["lost_load"], node=set["nodes"]["all"]], cep.model[:LL][carrier, node]==sum(cep.model[:SLACK][carrier, t, k, node]*ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"]["all"], k=set["time_K"]["all"])*scale[:SLACK]/scale[:LL])
  return cep
end

"""
     setup_opt_lost_emission!(cep::OptModelCEP, ts_data::ClustData, opt_data::OptDataCEP)
Adding variable LE (LostEmission - if demand cannot be met without breaking Emission-constraint -> Lost Emission can be "purchased" to meet demand with "dirty" production)
"""
function setup_opt_lost_emission!(cep::OptModelCEP,
                              ts_data::ClustData,
                              opt_data::OptDataCEP)
  ## DATA ##
  set=cep.set

  ## LOST EMISSION ##
  # Lost Emission variable #
  push!(cep.info,"Variable LE[impact_{lost_emission}] ≥ 0 in kg")
  @variable(cep.model, LE[impact=set["impact"]["lost_emission"]] >=0)
  return cep
end

"""
     setup_opt_fix_design_variables!(cep::OptModelCEP,ts_data::ClustData, opt_data::OptDataCEP,scale::Dict{Symbol,Int},fixed_design_variables::Dict{String,Any})
Fixing variables CAP based on first stage vars
"""
function setup_opt_fix_design_variables!(cep::OptModelCEP,
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
    @constraint(cep.model, [line=set["lines"]["all"], tech=set["tech"]["line"]], cep.model[:TRANS][tech,"new",line]==trans[tech, "new", line]/scale[:TRANS])
  end
  # Node based
  push!(cep.info,"CAP[tech, 'new', node] = existing infrastructure ∀ tech_n, node")
  @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["node"]], cep.model[:CAP][tech,"new",node]==cap[tech, "new", node]/scale[:CAP])
  return cep
end

"""
     setup_opt_cost_var!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,tech_group::String;dir_main_carrier::Symbol=:input,sign_generation::Number=1)
add variable and fixed Costs for the technology defined by `tech_group`
"""
function setup_opt_cost_var!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int},
                            tech_group::String;
                            dir_main_carrier::Symbol=:input,
                            sign_generation::Number=1)
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    ## COST ##
    # Calculate Variable Costs
    push!(cep.info,"COST['var',impact,tech] = ($sign_generation) ⋅ Σ_{t,k,node}GEN[carrier_$dir_main_carrier,t,k,node]⋅ ts_weights[k] ⋅ ts_deltas[t,k]⋅ var_costs[tech,impact] ∀ impact, tech_$tech_group")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"][tech_group]], cep.model[:COST]["var",impact,tech]==sign_generation*sum(cep.model[:GEN][tech,getfield(techs[tech],dir_main_carrier)["carrier"],t,k,node]*ts_weights[k]*ts_deltas[t,k]*costs[tech,node,set["year"]["all"][1],"var",impact] for node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"])*scale[:GEN]/scale[:COST])
    return cep
  end

"""
     setup_opt_cost_cap!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,tech_group::String)
add variable and fixed Costs for the technology defined by `tech_group`
"""
function setup_opt_cost_cap!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int},
                            tech_group::String)
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    # Calculate Fixed Costs
    push!(cep.info,"COST['cap_fix',impact,tech] = Σ_{t,k}(ts_weights ⋅ ts_deltas[t,k])/8760h ⋅ Σ_{node}CAP[tech,'new',node] ⋅ cap_costs[tech,impact] ∀ impact, tech_$tech_group")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"][tech_group]], cep.model[:COST]["cap_fix",impact,tech]==sum(ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"]["all"], k=set["time_K"]["all"])/8760* sum(cep.model[:CAP][tech,"new",node]*costs[tech,node,set["year"]["all"][1],"cap_fix",impact] for node=set["nodes"]["all"])*scale[:CAP]/scale[:COST])
    return cep
end

"""
     setup_opt_cost_trans!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,tech_group::String)
add variable and fixed Costs for the technology defined by `tech_group`
"""
function setup_opt_cost_trans!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int},
                            tech_group::String)
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

    # Calculate Fixed Costs
    push!(cep.info,"COST['cap-fix',impact,tech] = Σ_{t,k}(ts_weights ⋅ ts_deltas[t,k])/8760h ⋅ Σ_{node}(TRANS[tech,'new',line] ⋅ length[line]) ⋅ (cap_costs[tech,impact]+fix_costs[tech,impact]) ∀ impact, tech_$tech_group")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"][tech_group]], cep.model[:COST]["cap_fix",impact,tech] == sum(ts_weights[k]*ts_deltas[t,k] for t=set["time_T_period"]["all"], k=set["time_K"]["all"])/8760* sum(cep.model[:TRANS][tech,"new",line]*lines[tech,line].length *(costs[tech,lines[tech,line].node_start,set["year"]["all"][1],"cap_fix",impact]) for line=set["lines"]["all"])*scale[:TRANS]/scale[:COST])
    return cep
end

"""
     setup_opt_demand!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,scale::Dict{Symbol,Int})
add variable and fixed Costs and limit generation to installed capacity (and limiting time_series, if dependency in techs defined) for fossil and renewable power plants
"""
function setup_opt_demand!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs
    #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
    nodes = opt_data.nodes
    #ts          Dict( tech-node ): t x k
    ts=ts_data.data
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    ## DEMAND COST ##
    #Variable Costs
    setup_opt_cost_var!(cep,ts_data,opt_data,scale,"demand")
    #Fixed Costs based on installed capacity
    setup_opt_cost_cap!(cep,ts_data,opt_data,scale,"demand")

    ## DEMAND GENERATION ##
    # Fix the demand
    push!(cep.info,"GEN[tech, carrier t, k, node] = (-1) ⋅ Σ_{infrastruct} CAP[tech,infrastruct,node] * ts[tech-node,t,k] ∀ node, tech_demand, t, k")
    @constraint(cep.model, [tech=set["tech"]["demand"], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], cep.model[:GEN][tech,techs[tech].input["carrier"],t,k,node] == (-1) * sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"]["all"])*ts[techs[tech].output["timeseries"]*"-"*node][t,k]*scale[:CAP]/scale[:GEN])
    return cep
end

"""
     setup_opt_dispatchable_generation!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,scale::Dict{Symbol,Int})
add variable and fixed Costs and limit generation to installed capacity (and limiting time_series, if dependency in techs defined) for fossil and renewable power plants
"""
function setup_opt_dispatchable_generation!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs
    #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
    nodes = opt_data.nodes
    #ts          Dict( tech-node ): t x k
    ts=ts_data.data
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    ## DISPACHABLE COST ##
    #Variable Costs
    setup_opt_cost_var!(cep,ts_data,opt_data,scale,"dispatchable_generation";dir_main_carrier=:output)
    #Fixed Costs based on installed capacity
    setup_opt_cost_cap!(cep,ts_data,opt_data,scale,"dispatchable_generation")

    ## DISPATCHABLE GENERATION ##
    # Limit the generation of dispathables to the infrastructing capacity of dispachable power plants
    push!(cep.info,"0 ≤ GEN[tech, carrier t, k, node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_dispatchable_generation, t, k")
    # Limit the generation of dispathables to the infrastructing capacity of dispachable power plants
    @constraint(cep.model, [tech=set["tech"]["dispatchable_generation"], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], 0 <=cep.model[:GEN][tech, techs[tech].output["carrier"], t, k, node])
    @constraint(cep.model, [tech=set["tech"]["dispatchable_generation"], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]],     cep.model[:GEN][tech, techs[tech].output["carrier"], t, k, node] <=sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"]["all"])*scale[:CAP]/scale[:GEN])
    return cep
end

"""
     setup_opt_non_dispatchable_generation!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,scale::Dict{Symbol,Int})
add variable and fixed Costs and limit generation to installed capacity (and limiting time_series, if dependency in techs defined) for fossil and renewable power plants
"""
function setup_opt_non_dispatchable_generation!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs
    #`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
    nodes = opt_data.nodes
    #ts          Dict( tech-node ): t x k
    ts=ts_data.data

    ## GENERATION COST ##
    #Variable Costs
    setup_opt_cost_var!(cep,ts_data,opt_data,scale,"non_dispatchable_generation";dir_main_carrier=:output)
    #Fixed Costs based on installed capacity
    setup_opt_cost_cap!(cep,ts_data,opt_data,scale,"non_dispatchable_generation")

    ## GENERATION ELECTRICITY ##
    # Limit the generation of dispathables to the infrastructing capacity of non-dispachable power plants
    push!(cep.info,"0 ≤ GEN[tech, carrier t, k, node] ≤ Σ_{infrastruct}CAP[tech,infrastruct,node]*ts[tech-node,t,k] ∀ node, tech_generation{non_dispatchable}, t, k")
    # Limit the generation of non-dispathable generation to the infrastructing capacity of non-dispachable power plants
    @constraint(cep.model, [tech=set["tech"]["non_dispatchable_generation"], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], 0 <=cep.model[:GEN][tech, techs[tech].output["carrier"], t, k, node])
    @constraint(cep.model, [tech=set["tech"]["non_dispatchable_generation"], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]],  cep.model[:GEN][tech, techs[tech].output["carrier"], t,k,node] <= sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"]["all"])*ts[techs[tech].input["timeseries"]*"-"*node][t,k]*scale[:CAP]/scale[:GEN])
    return cep
end

"""
     setup_opt_conversion!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,scale::Dict{Symbol,Int})

A conversion technology converts the input carrier to an output carrier with a certain efficiency. The costs and capacities are scaled with the input carriers unit
"""
function setup_opt_conversion!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    ## CONVERSION COST ##
    #Variable Costs
    setup_opt_cost_var!(cep,ts_data,opt_data,scale,"conversion";sign_generation=(-1))
    #Fixed Costs based on installed capacity
    setup_opt_cost_cap!(cep,ts_data,opt_data,scale,"conversion")

    ##CONVERSION GEN ##
    #Calculate the input generation
    push!(cep.info,"0 ≥ GEN[carrier_input, tech, t, k, node] ≥ (-1) ⋅ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_conversion, t, k")
    @constraint(cep.model, [tech=set["tech"]["conversion"], carrier=[techs[tech].input["carrier"]], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], 0 >= cep.model[:GEN][tech,carrier,t,k,node])
    @constraint(cep.model, [tech=set["tech"]["conversion"], carrier=[techs[tech].input["carrier"]], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], cep.model[:GEN][tech,carrier,t,k,node]>= (-1)*sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"]["all"])*scale[:CAP]/scale[:GEN])
    #Calculate the output generation
    push!(cep.info,"GEN[carrier_output,tech, t, k, node] = (-1) ⋅ η[carrier_output, tech] ⋅ GEN[carrier_input, tech, t, k, node] ∀ node, tech_storage_in, t, k")
    @constraint(cep.model, [tech=set["tech"]["conversion"], carrier_in=[techs[tech].input["carrier"]], carrier_out=[techs[tech].output["carrier"]], node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], cep.model[:GEN][tech,carrier_out,t,k,node] == (-1) * techs[tech].constraints["efficiency"] * cep.model[:GEN][tech,carrier_in,t,k,node])
    #TODO add multiple outputs and inputs
    return cep
end

"""
    setup_opt_intertech_cap!(cep::OptModelCEP,
                                      ts_data::ClustData,
                                      opt_data::OptDataCEP,
                                      scale::Dict{Symbol,Int})
Setup constraints for capacities of technologies between different technologies
"""
function setup_opt_intertech_cap!(cep::OptModelCEP,
                                      ts_data::ClustData,
                                      opt_data::OptDataCEP,
                                      scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs

    #Check for specific constraint that bounds the installed capacity of one technology to another
    for tech in set["tech"]["all"]
      if haskey(techs[tech].constraints,"cap_eq")
          push!(cep.info,"CAP[$tech, 'new', node] = CAP[$(techs[tech].constraints["cap_eq"]), 'new', node] ∀ node, tech_{EUR-Cap-Cost out/in==0}")
          @constraint(cep.model, [node=set["nodes"]["all"]], cep.model[:CAP][tech,"new",node] == cep.model[:CAP][techs[tech].constraints["cap_eq"],"new",node])
      end
    end
    return cep
end

"""
     setup_opt_storage!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
add variables INTRASTORGEN and INTRASTOR, variable and fixed Costs, limit generation to installed power-capacity, connect simple-storage levels (within period) with generation
basis for either simplestorage or seasonalstorage
"""
function setup_opt_storage!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
    costs = opt_data.costs
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs
    #ts_weights: k - weight of each period:
    ts_weights=ts_data.weights
    #ts_deltas:  t x k - Δt of each segment x period
    ts_deltas=ts_data.delta_t

    ## VARIABLE ##
    # Storage has additional element 0 for storage at hour 0 of day
    push!(cep.info,"Variable INTRASTOR[tech_storage, carrier, t, k, node] ≥ 0 in MWh") #Note that variable is scaled only within the model
    @variable(cep.model, INTRASTOR[tech=set["tech"]["storage"], carrier=set["carrier"][tech],  t=set["time_T_point"]["all"], k=set["time_K"]["all"], node=set["nodes"]["all"]] >=0)

    ## STORAGE COST ##
    #Variable Costs
    # Calculate Variable Costs
    push!(cep.info,"COST['var',impact,tech] = 0 ∀ impact, tech_storage")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["storage"]], cep.model[:COST]["var",impact,tech]==0)
    #Fixed Costs based on installed capacity
    setup_opt_cost_cap!(cep,ts_data,opt_data,scale,"storage")

    ## STORAGE LEVEL ##
    # Connect the previous storage level and the integral of the flows with the new storage level
    push!(cep.info,"INTRASTOR[carrier,tech, t, k, node] = INTRASTOR[carrier,tech, t-1, k, node] η[tech]^(ts_deltas[t,k]/732h) + ts_deltas[t,k] ⋅ (-1) ⋅ (GEN[tech, carrier t, k, node] ∀ carrier(tech), node, tech_storage, t, k")
    @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"], t in set["time_T_period"]["all"], k=set["time_K"]["all"]], cep.model[:INTRASTOR][tech, techs[tech].input["carrier"],t,k,node]==cep.model[:INTRASTOR][tech, techs[tech].input["carrier"],t-1,k,node]*(techs[tech].constraints["efficiency"])^(ts_deltas[t,k]/732) - ts_deltas[t,k] * (cep.model[:GEN][tech, techs[tech].input["carrier"], t,k,node])*scale[:GEN]/scale[:INTRASTOR])

    return cep
end

"""
     setup_opt_simplestorage!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
Adding only intra-day storage:
Looping constraint for each period (same start and end level for all periods) and limit storage to installed energy-capacity
"""
function setup_opt_simplestorage!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs

    ## INTRASTORAGE ##
    # Limit the storage of the energy part of the battery to its installed power
    push!(cep.info,"INTRASTOR[carrier,tech, t, k, node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_storage, t, k")
    @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], cep.model[:INTRASTOR][tech, techs[tech].input["carrier"], t,k,node]<=sum(cep.model[:CAP][tech, infrastruct, node] for infrastruct=set["infrastruct"]["all"])*scale[:CAP]/scale[:INTRASTOR])
    # Set storage level at beginning and end of day equal
    push!(cep.info,"INTRASTOR[carrier,tech, '0', k, node] = INTRASTOR[carrier,tech, 't[end]', k, node] ∀ node, tech_storage, k")
    @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"], k=set["time_K"]["all"]], cep.model[:INTRASTOR][tech, techs[tech].input["carrier"], 0, k, node]== cep.model[:INTRASTOR][tech,techs[tech].input["carrier"],set["time_T_point"]["all"][end],k,node])
    # Set the storage level at the beginning of each representative day to the same
    push!(cep.info,"INTRASTOR[carrier,tech, '0', k, node] = INTRASTOR[carrier,tech, '0', k, node] ∀ node, tech_storage, k")
    @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"], k=set["time_K"]["all"]], cep.model[:INTRASTOR][tech, techs[tech].input["carrier"], 0, k, node]== cep.model[:INTRASTOR][tech, techs[tech].input["carrier"], 0, 1, node])
    return cep
end

"""
     setup_opt_seasonalstorage!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
Adding inter-day storage:
add variable INTERSTOR, calculate seasonal-storage-level and limit total storage to installed energy-capacity
"""
function setup_opt_seasonalstorage!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
    ## DATA ##
    set=cep.set
    #`techs::OptVariable`: techs[tech][tech_group] - OptDataCEPTech
    techs = opt_data.techs
    #K identification numbers
    k_ids=ts_data.k_ids

    ## VARIABLE ##
    # Storage
    push!(cep.info,"Variable INTERSTOR[carrier, tech, i, node] ≥ 0 in MWh") #Note that variable is scaled only within the model
    @variable(cep.model, INTERSTOR[tech=set["tech"]["storage"], carrier=set["carrier"][tech], i=set["time_I_point"]["all"], node=set["nodes"]["all"]]>=0)


    ## INTERSTORAGE ##
    # Set storage level at the beginning of the year equal to the end of the year
    push!(cep.info,"INTERSTOR[carrier,tech, '0', node] = INTERSTOR[carrier,tech, 'end', node] ∀ node, tech_storage, t, k")
    @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"]], cep.model[:INTERSTOR][tech,techs[tech].input["carrier"],0,node]== cep.model[:INTERSTOR][tech, techs[tech].input["carrier"], set["time_I_point"]["all"][end],node])
    # Connect the previous seasonal-storage level and the daily difference of the corresponding simple-storage with the new seasonal-storage level
    push!(cep.info,"INTERSTOR[carrier,tech, i+1, node] = INTERSTOR[carrier,tech, i, node] + INTRASTOR[carrier,tech, 'k[i]', 't[end]', node] - INTRASTOR[carrier,tech, 'k[i]', '0', node] ∀ node, tech_storage, i")
    # Limit the total storage (seasonal and simple) to be greater than zero and less than total storage cap
    push!(cep.info,"0 ≤ INTERSTOR[carrier,tech, i, node] + INTRASTOR[carrier,tech, t, k[i], node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_storage, i, t")
    push!(cep.info,"0 ≤ INTERSTOR[carrier,tech, i, node] + INTRASTOR[carrier,tech, t, k[i], node] ≤ Σ_{infrastruct} CAP[tech,infrastruct,node] ∀ node, tech_storage, i, t")
    for i in set["time_I_period"]["all"]
        @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"]], cep.model[:INTERSTOR][tech,techs[tech].input["carrier"],i,node] == cep.model[:INTERSTOR][tech,techs[tech].input["carrier"],i-1,node] + (cep.model[:INTRASTOR][tech,techs[tech].input["carrier"],set["time_T_period"]["all"][end],k_ids[i],node] - cep.model[:INTRASTOR][tech,techs[tech].input["carrier"],0,k_ids[i],node])*scale[:INTRASTOR]/scale[:INTERSTOR])
        @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"], t=set["time_T_point"]["all"]], 0 <= cep.model[:INTERSTOR][tech,techs[tech].input["carrier"],i,node]+cep.model[:INTRASTOR][tech,techs[tech].input["carrier"],t,k_ids[i],node]*scale[:INTRASTOR]/scale[:INTERSTOR])
        @constraint(cep.model, [node=set["nodes"]["all"], tech=set["tech"]["storage"], t=set["time_T_point"]["all"]], cep.model[:INTERSTOR][tech,techs[tech].input["carrier"],i,node]+cep.model[:INTRASTOR][tech,techs[tech].input["carrier"],t,k_ids[i],node]*scale[:INTRASTOR]/scale[:INTERSTOR] <= sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"]["all"])*scale[:CAP]/scale[:INTERSTOR])
    end
    return cep
end

"""
     setup_opt_transmission!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
Setup variable FLOW and TRANS, calculate fixed and variable COSTs, set CAP-trans to zero, limit FLOW with TRANS, calculate GEN-trans for each node
"""
function setup_opt_transmission!(cep::OptModelCEP,
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
    push!(cep.info,"Variable FLOW[tech_transmission, carrier, dir, t, k, line] ≥ 0 in MW") #Note that variable is scaled only within the model
    @variable(cep.model, FLOW[tech=set["tech"]["transmission"], carrier=set["carrier"][tech], dir=set["dir_transmission"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"], line=set["lines"]["all"]] >= 0)
    # Add variable TRANS
    push!(cep.info,"Variable TRANS[tech_transmission,  infrastruct, lines] ≥ 0 in MW") #Note that variable is scaled only within the model
    @variable(cep.model, TRANS[tech=set["tech"]["transmission"], infrastruct=set["infrastruct"]["all"], line=set["lines"]["all"]] >= 0)

    ## TRANSMISSION COST ##
    #Variable Costs
    push!(cep.info,"COST['var',impact,tech] = 0 ∀ impact, tech_storage")
    @constraint(cep.model, [impact=set["impact"]["all"], tech=set["tech"]["transmission"]], cep.model[:COST]["var",impact,tech]==0)
    #Fixed Costs based on installed transmission
    setup_opt_cost_trans!(cep,ts_data,opt_data,scale,"transmission")

    ## TRANSMISSION TRANS ##
    # Limit the flow per line to the existing infrastructure
    push!(cep.info,"| FLOW[carrier, dir, tech, t, k, line] | ≤ Σ_{infrastruct}TRANS[tech,infrastruct,line] ∀ line, tech_transmission, t, k")
    @constraint(cep.model, [tech=set["tech"]["transmission"], carrier=set["carrier"][tech], line=set["lines"]["all"], dir=set["dir_transmission"]["all"],  t=set["time_T_period"]["all"], k=set["time_K"]["all"]], cep.model[:FLOW][tech, carrier,dir, t, k, line] <= sum(cep.model[:TRANS][tech,infrastruct,line] for infrastruct=set["infrastruct"]["all"])*scale[:TRANS]/scale[:FLOW])
    # Calculate the sum of the flows for each node
    push!(cep.info,"GEN[tech, carrier t, k, node] = Σ_{line-end(node)} FLOW[tech, carrier, 'uniform', t, k, line] - Σ_{line_pos} FLOW[tech, carrier, 'opposite', t, k, line] / (η[tech]⋅length[line]) + Σ_{line-start(node)} Σ_{line_pos} FLOW[tech, carrier, 'opposite', t, k, line] - FLOW[tech, carrier, 'uniform', t, k, line] / (η[tech]⋅length[line])∀ tech_transmission, t, k")
    for node in set["nodes"]["all"]
      @constraint(cep.model, [tech=set["tech"]["transmission"], carrier=set["carrier"][tech], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], cep.model[:GEN][tech, carrier, t, k, node] == (sum(cep.model[:FLOW][tech, carrier,"uniform", t, k, line_end] - cep.model[:FLOW][tech, carrier,"opposite", t, k, line_end]/lines[tech,line_end].eff for line_end=set["lines"]["all"][getfield.(lines[tech,:], :node_end).==node]) + sum(cep.model[:FLOW][tech, carrier,"opposite", t, k, line_start] - cep.model[:FLOW][tech, carrier,"uniform", t, k, line_start]/lines[tech,line_start].eff for line_start=set["lines"]["all"][getfield.(lines[tech,:], :node_start).==node]))*scale[:FLOW]/scale[:GEN])
    end
    return cep
end

"""
    setup_opt_energy_balance_transmission!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,scale::Dict{Symbol,Int})
Add energy-balance which shall be matched by the generation (GEN) taking the transmission into account
"""
function setup_opt_energy_balance_transmission!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
  ## DATA ##
  set=cep.set

  ## ENERGY BALANCE ##
  # Force the demand and slack to match the generation either with transmission
  push!(cep.info,"Σ_{tech}GEN[tech, carriert,k,node] + SLACK[carrier,t,k,node] = 0 ∀ node,t,k")
  @constraint(cep.model, [carrier=intersect(set["carrier"]["all"],set["carrier"]["lost_load"]),node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], sum(cep.model[:GEN][tech,carrier,t,k,node] for tech=set["tech"][carrier]) + (cep.model[:SLACK][carrier,t,k,node]*scale[:SLACK])/scale[:GEN] ==0)
  # Force the demand without slack to match the generation either with transmission
  push!(cep.info,"Σ_{tech}GEN[tech, carriert,k,node] = 0 ∀ node,t,k")
  @constraint(cep.model, [carrier = setdiff(set["carrier"]["all"], set["carrier"]["lost_load"]), node=set["nodes"]["all"], t=set["time_T_period"]["all"], k=set["time_K"]["all"]], sum(cep.model[:GEN][tech,carrier,t,k,node] for tech=set["tech"][carrier]) == 0)
  return cep
end

"""
    setup_opt_energy_balance_copperplate!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,scale::Dict{Symbol,Int})
Add energy-balance using a copperplate assumption that the generation just has to be matched across all nodes without taking transmission into account
"""
function setup_opt_energy_balance_copperplate!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int})
  ## DATA ##
  set=cep.set

  ## ENERGY BALANCE ##
  push!(cep.info,"Σ_{tech,node}GEN[tech, carriert,k,node] + SLACK[carrier,t,k,node] = 0 ∀ t,k")
  @constraint(cep.model, [carrier=intersect(set["carrier"]["all"],set["carrier"]["lost_load"]),t=set["time_T_period"]["all"], k=set["time_K"]["all"]], sum(cep.model[:GEN][tech,carrier,t,k,node] for node=set["nodes"]["all"], tech=set["tech"][carrier]) + sum(cep.model[:SLACK][carrier,t,k,node]*scale[:SLACK] for node=set["nodes"]["all"])/scale[:GEN] == 0)
  # or on copperplate
  push!(cep.info,"Σ_{tech,node}GEN[tech, carriert,k,node] = 0 ∀ t,k")
  @constraint(cep.model, [carrier=setdiff(set["carrier"]["all"],set["carrier"]["lost_load"]),t=set["time_T_period"]["all"], k=set["time_K"]["all"]], sum(cep.model[:GEN][tech,carrier,t,k,node] for node=set["nodes"]["all"], tech=set["tech"][carrier]) == 0)
  return cep
end

"""
    setup_opt_limit_emission!(cep::OptModelCEP, ts_data::ClustData, opt_data::OptDataCEP, scale::Dict{Symbol,Int}; limit::Dict{String,Dict} = Dict{String,Dict}("CO2"=>Dict{String,Number}("electricity"=>Inf)), lost_emission_cost::Dict{String,Number} = Dict{String,Number}("CO2"=>Inf))
Add emission limits constraints
"""
function setup_opt_limit_emission!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int};
                            limit_emission::Dict{String,Dict}=Dict{String,Dict}(),
                            lost_emission_cost::Dict{String,Number}=Dict{String,Number}())
  ## DATA ##
  set=cep.set
  #ts          Dict( tech-node ): t x k
  ts=ts_data.data
  #ts_weights: k - weight of each period:
  ts_weights=ts_data.weights
  #ts_deltas:  t x k - Δt of each segment x period
  ts_deltas=ts_data.delta_t

  ## EMISSIONS ##
  # Limit the Emissions with limit[impact] and allow lost emissions for all impacts that are both within the tech-group `limit` and `lost_emission`
  push!(cep.info,"ΣCOST_{account,tech}[account,impact_limit&lost_emission,tech] ≤ LE[impact] + ∑limit_emission[impactpercarrier] Σ_{node,t,k} ts[demand_carrier-node,t,k] ⋅ ts_weights[k] ⋅ ts_deltas[t,k]")
  @constraint(cep.model, [impact=intersect(set["impact"]["limit"],set["impact"]["lost_emission"])], sum(cep.model[:COST][account,impact,tech] for account=set["account"]["all"], tech=set["tech"]["all"])<= (cep.model[:LE][impact]*scale[:LE] +  sum(sum(limit_emission[impact][carrier]*ts["demand_"*carrier*"-"*node][t,k] for carrier=keys(limit_emission[impact]))*ts_deltas[t,k]*ts_weights[k] for t=set["time_T_period"]["all"], k=set["time_K"]["all"], node=set["nodes"]["all"]))/scale[:COST])
  # Limit the Emissions with limit[impact] and do NOT allow lost emissions for all impacts that are only within the tech-group `limit` and not `lost_emission`
  # Total demand can also be determined with the function get_total_demand() edit both in case of changes of e.g. ts_deltas
  push!(cep.info,"ΣCOST_{account,tech}[account,impact_limit|lost_emission,tech] ≤ limit_emission[impactpercarrier] ⋅ Σ_{node,t,k} ts[demand_carrier-node,t,k] ⋅ ts_weights[k] ⋅ ts_deltas[t,k]")
  @constraint(cep.model, [impact=setdiff(set["impact"]["limit"],set["impact"]["lost_emission"])], sum(cep.model[:COST][account,impact,tech] for account=set["account"]["all"], tech=set["tech"]["all"])<= sum(sum(limit_emission[impact][carrier]*ts["demand_"*carrier*"-"*node][t,k] for carrier=keys(limit_emission[impact]))*ts_deltas[t,k]*ts_weights[k] for t=set["time_T_period"]["all"], k=set["time_K"]["all"], node=set["nodes"]["all"])/scale[:COST])
  return cep
end

"""
     setup_opt_existing_infrastructure!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
fixing existing infrastructure to CAP[tech, 'ex', node] and  TRANS[tech, 'ex', line] to the value defined in `nodes.csv` for all tech within the set set["tech"]["exist_inf"] as defined in the dictionary config['infrastructure']['existing']
"""
function setup_opt_existing_infrastructure!(cep::OptModelCEP,
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
  push!(cep.info,"CAP[tech, 'ex', node] = existing infrastructure ∀ node, tech ∈ tech_group_ex")
  push!(cep.info,"CAP[tech, 'ex', node] = 0  ∀ node, tech ∉ tech_group_ex")
  @constraint(cep.model, [node=set["nodes"]["all"], tech=intersect(set["tech"]["node"],set["tech"]["exist_inf"])], cep.model[:CAP][tech,"ex",node]==nodes[tech,node].power_ex/scale[:CAP])
  @constraint(cep.model, [node=set["nodes"]["all"], tech=setdiff(set["tech"]["node"],set["tech"]["exist_inf"])], cep.model[:CAP][tech,"ex",node]==0)
  if haskey(set["tech"],"transmission")
    push!(cep.info,"TRANS[tech, 'ex', line] = existing infrastructure ∀ tech ∈ tech_group_ex, line")
    push!(cep.info,"TRANS[tech, 'ex', line] = 0 ∀ tech ∉ tech_group_ex, line")
    @constraint(cep.model, [line=set["lines"]["all"], tech=intersect(set["tech"]["line"],set["tech"]["exist_inf"])], cep.model[:TRANS][tech,"ex",line]==lines[tech,line].power_ex/scale[:TRANS])
    @constraint(cep.model, [line=set["lines"]["all"], tech=setdiff(set["tech"]["line"],set["tech"]["exist_inf"])], cep.model[:TRANS][tech,"ex",line]==0)
  end
  return cep
end
"""
     setup_opt_limit_infrastructure!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
limit infrastructure setup of CAP[tech, sum(infrastuct), node] and  TRANS[tech, infrastruct, line] to be smaller than the limit defined in `nodes.csv` for all tech within the set set["tech"]["limit"] as defined in the dictionary config['infrastructure']['limit']
"""
function setup_opt_limit_infrastructure!(cep::OptModelCEP,
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
  @constraint(cep.model, [node=set["nodes"]["all"], tech=intersect(set["tech"]["node"],set["tech"]["limit"])], sum(cep.model[:CAP][tech,infrastruct,node] for infrastruct=set["infrastruct"]["all"]) <= nodes[tech,node].power_lim/scale[:CAP])
  if haskey(set["tech"],"transmission")
    push!(cep.info,"∑_{infrastuct} TRANS[tech, infrastruct, line] <= limit infrastructure ∀ tech_trans, line")
    @constraint(cep.model, [line=set["lines"]["all"], tech=intersect(set["tech"]["line"],set["tech"]["limit"])], sum(cep.model[:TRANS][tech,infrastruct,line] for infrastruct=set["infrastruct"]["all"]) <= lines[tech,line].power_lim/scale[:TRANS])
  end
  return cep
end

"""
     setup_opt_objective!(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP, scale::Dict{Symbol,Int})
Calculate total system costs and set as objective
"""
function setup_opt_objective!(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            scale::Dict{Symbol,Int};
                            lost_load_cost::Dict{String,Number}=Dict{String,Number}(),
                            lost_emission_cost::Dict{String,Number}=Dict{String,Number}())
  ## DATA ##
  set=cep.set

  ## OBJECTIVE ##
  # Minimize the total €-Costs s.t. the Constraints introduced above
  push!(cep.info,"min Σ_{account,tech}COST[account,'$(first(set["impact"]["mon"]))',tech] + Σ_{node,carrier_ll} LL[carrier,node] ⋅ lost_load_cost[carrier]) +  Σ_{impact_le} LE[impact] ⋅ lost_emission_cost[impact] st. above")
  @objective(cep.model, Min,  sum(cep.model[:COST][account,first(set["impact"]["mon"]),tech] for account=set["account"]["all"], tech=set["tech"]["all"]) + sum(cep.model[:LL][carrier,node]*lost_load_cost[carrier] for node=set["nodes"]["all"], carrier=set["carrier"]["lost_load"])*scale[:LL]/scale[:COST] + sum(cep.model[:LE][impact]*lost_emission_cost[impact] for impact=set["impact"]["lost_emission"])*scale[:LE]/scale[:COST])
  return cep
end

"""
     solve_opt_cep(cep::OptModelCEP,ts_data::ClustData,opt_data::OptDataCEP,config::Dict{String,Any})
solving the cep model and writing it's results and `limit` into an OptResult-Struct
"""
function solve_opt_cep(cep::OptModelCEP,
                            ts_data::ClustData,
                            opt_data::OptDataCEP,
                            config::Dict{String,Any})
  optimize!(cep.model)
  status=Symbol(termination_status(cep.model))
  scale=config["scale"]
  objective=objective_value(cep.model)*scale[:COST]
  total_demand=get_total_demand(cep,ts_data)
  variables=Dict{String,Any}()
  # cv - Cost variable, dv - design variable, which is used to fix variables in a dispatch model, ov - operational variable
  variables["COST"]=OptVariable(cep,:COST,"cv",scale)
  variables["CAP"]=OptVariable(cep,:CAP,"dv",scale)
  variables["GEN"]=OptVariable(cep,:GEN,"ov",scale)
  lost_load=0
  lost_emission=0
  if !isempty(config["lost_load_cost"])
    variables["SLACK"]=OptVariable(cep,:SLACK,"sv",scale)
    variables["LL"]=OptVariable(cep,:LL,"sv",scale)
    lost_load=sum(variables["LL"].data)
  end
  if !isempty(config["lost_emission_cost"])
    variables["LE"]=OptVariable(cep,:LE,"sv",scale)
    lost_emission=sum(variables["LE"].data)
  end
  if config["storage"]
    variables["INTRASTOR"]=OptVariable(cep,:INTRASTOR,"ov",scale)
    if config["seasonalstorage"]
      variables["INTERSTOR"]=OptVariable(cep,:INTERSTOR,"ov",scale)
    end
  end
  if config["transmission"]
    variables["TRANS"]=OptVariable(cep,:TRANS,"dv",scale)
    variables["FLOW"]=OptVariable(cep,:FLOW,"ov",scale)
  end
  get_met_cap_limit(cep, opt_data, variables)
  currency=variables["COST"].axes[2][1]
  if lost_load==0 && lost_emission==0
    config["print_flag"] && @info("Solved Scenario $(config["descriptor"]): "*String(status)*" min COST: $(round(objective,sigdigits=4)) [$currency] ⇨ $(round(objective/total_demand,sigdigits=4)) [$currency per MWh] s.t. $(text_limit_emission(config["limit_emission"]))")
  else
    cost=variables["COST"]
    config["print_flag"] && @info("Solved Scenario $(config["descriptor"]): "*String(status)*" min COST: $(round(sum(cost[:,axes(cost,"impact")[1],:]),sigdigits=4)) [$currency] ⇨ $(round(sum(cost[:,axes(cost,"impact")[1],:])/total_demand,sigdigits=4)) [$currency per MWh] with LL: $lost_load [MWh] s.t. $(text_limit_emission(config["limit_emission"])) + $(round(lost_emission/total_demand,sigdigits=4)) (violation) [kg-CO₂-eq. per MWh]")
  end
  info=Dict{String,Any}("total_demand"=>total_demand,"model"=>cep.info,)
  return OptResult(status,objective,variables,cep.set,config,info)
end
