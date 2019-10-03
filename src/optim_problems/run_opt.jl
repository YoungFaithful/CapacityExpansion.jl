"""
    run_opt(ts_data::ClustData,opt_data::OptDataCEP,opt_config::Dict{String,Any},optimizer::DataType)
Organizing the actual setup and run of the CEP-Problem. This function shouldn't be called by a user, but from within the other `run_opt`-functions
Required elements are:
- `ts_data`: The time-series data.
- `opt_data`: In this case the OptDataCEP that contains information on costs, nodes, techs and for transmission also on lines.
- `opt_config`: This includes all the settings for the design optimization problem formulation.
- `optimizer`: The used optimizer, which could e.g. be Clp: `using Clp` `optimizer=Clp.Optimizer` or Gurobi: `using Gurobi` `optimizer=Gurobi.Optimizer`.
"""
function run_opt(ts_data::ClustData,
                opt_data::OptDataCEP,
                opt_config::Dict{String,Any},
                optimizer::DataType)
  #Check the consistency of the data provided
  check_opt_data_cep(opt_data)
  #Setup the basic elements
  cep=setup_opt_basic(ts_data, opt_data, opt_config, optimizer, opt_config["optimizer_config"])
  #Setup the basic variables
  setup_opt_basic_variables!(cep, ts_data, opt_data)
  # Setup the demand
  if opt_config["demand"]
    setup_opt_demand!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup the non dispachable electricity generation
  if opt_config["non_dispatchable_generation"]
    setup_opt_non_dispatchable_generation!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup the dispatchable electricity generation
  if opt_config["dispatchable_generation"]
    setup_opt_dispatchable_generation!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup conversion
  if opt_config["conversion"]
    setup_opt_conversion!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup storage
  if opt_config["storage"]
    setup_opt_storage!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup seasonal storage
  if opt_config["seasonalstorage"]
    setup_opt_seasonalstorage!(cep, ts_data, opt_data, opt_config["scale"])
  #Or intra-day storage (same level in first and last time step for each period)
  elseif opt_config["storage"] && !(opt_config["seasonalstorage"])
    setup_opt_simplestorage!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup transmission
  if opt_config["transmission"]
      setup_opt_transmission!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #If lost load cost exist
  if !isempty(opt_config["lost_load_cost"])
    setup_opt_lost_load!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #If lost emission exist
  if !isempty(opt_config["lost_emission_cost"])
    setup_opt_lost_emission!(cep, ts_data, opt_data)
  end
  #If limit of emissions
  if !isempty(opt_config["limit_emission"])
    setup_opt_limit_emission!(cep, ts_data, opt_data, opt_config["scale"]; limit_emission=opt_config["limit_emission"],  lost_emission_cost=opt_config["lost_emission_cost"])
  end
  #If fixed_design_variables are provided, fix the installed capacities to them
  if haskey(opt_config,"fixed_design_variables")
    setup_opt_fix_design_variables!(cep, ts_data, opt_data, opt_config["scale"], opt_config["fixed_design_variables"])
  end
  #Setup constraints that bind the capacities of different capacities with each other
  setup_opt_intertech_cap!(cep, ts_data, opt_data, opt_config["scale"])
  # Add existing infrastructure to
  setup_opt_existing_infrastructure!(cep, ts_data, opt_data, opt_config["scale"])
  # Limit the infrastructure expansion
  setup_opt_limit_infrastructure!(cep, ts_data, opt_data, opt_config["scale"])
  if opt_config["transmission"]
    # Setup the energy balences taking transmission into account
    setup_opt_energy_balance_transmission!(cep, ts_data, opt_data, opt_config["scale"])
  else
    # Setup the energy balences with a copperplate assumption without any transmission restrictions between nodes
    setup_opt_energy_balance_copperplate!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup the objective
  setup_opt_objective!(cep, ts_data, opt_data, opt_config["scale"]; lost_load_cost=opt_config["lost_load_cost"], lost_emission_cost=opt_config["lost_emission_cost"])
  # solve and return the CEP
  return solve_opt_cep(cep, ts_data, opt_data, opt_config)
end

"""
     run_opt(ts_data::ClustData,opt_data::OptDataCEP,opt_config::Dict{String,Any},fixed_design_variables::Dict{String,Any},optimizer::DataTyple;lost_el_load_cost::Number=Inf,lost_CO2_emission_cost::Number)
This problem runs the operational optimization problem only, with fixed design variables.
provide the fixed design variables and the `opt_config` of the previous step (design run or another opterational run)
Required elements are:
- `ts_data`: The time-series data, which should be be the original time-series data for this operational run. The `keys(ts_data.data)` need to match the `[time_series_name]-[node]`
- `opt_data`: In this case the OptDataCEP that contains information on costs, nodes, techs and for transmission also on lines. - Should be the same as in the design run.
- `opt_config`: This includes all the previous settings for the design optimization problem formulation and ensures that the configuration is the same.
- `fixed_design_variables`: All the design variables that are determined by the previous design run.
- `optimizer`: The used optimizer, which could e.g. be Clp: `using Clp` `optimizer=Clp.Optimizer` or Gurobi: `using Gurobi` `optimizer=Gurobi.Optimizer`.
What you can change in the `opt_config`:
- `lost_load_cost`: Dictionary with numbers indicating the lost load price per carrier (e.g. `electricity` in price/MWh should be greater than 1e6), give Inf for no SLACK and LL (Lost Load - a variable for unmet demand by the installed capacities)
- `lost_emission_cost`: Dictionary with numbers indicating the emission price/kg-emission (should be greater than 1e6), give Inf for no LE (Lost Emissions - a variable for emissions that will exceed the limit in order to provide the demand with the installed capacities)
"""
function run_opt(ts_data::ClustData,
                opt_data::OptDataCEP,
                opt_config::Dict{String,Any},
                fixed_design_variables::Dict{String,Any},
                optimizer::DataType;
                lost_load_cost::Dict{String,Number}=Dict{String,Number}(),
                lost_emission_cost::Dict{String,Number}=Dict{String,Number}())
  # Add the fixed_design_variables and new setting for slack costs to the existing config
  set_opt_config_cep!(opt_config;fixed_design_variables=fixed_design_variables, lost_load_cost=lost_load_cost, lost_emission_cost=lost_emission_cost)

  return run_opt(ts_data,opt_data,opt_config,optimizer)
end

"""
    run_opt(ts_data::ClustData,
           opt_data::OptDataCEP,
           optimizer::DataType;
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
           optimizer_config::Dict{Symbol,Any}=Dict{Symbol,Any}(),
           round_sigdigits::Int=9)
Wrapper function for type of optimization problem for the CEP-Problem (NOTE: identifier is the type of `opt_data` - in this case OptDataCEP - so identification as CEP problem).
Required elements are:
- `ts_data`: The time-series data, which could either be the original input data or some aggregated time-series data. The `keys(ts_data.data)` need to match the `[time_series_name]-[node]`
- `opt_data`: The OptDataCEP that contains information on costs, nodes, techs and for transmission also on lines.
- `optimizer`: The used optimizer, which could e.g. be Clp: `using Clp` `optimizer=Clp.Optimizer` or Gurobi: `using Gurobi` `optimizer=Gurobi.Optimizer`.
Options to tweak the model are:
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
function run_opt(ts_data::ClustData,
                 opt_data::OptDataCEP,
                 optimizer::DataType;
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
                 optimizer_config::Dict{Symbol,Any}=Dict{Symbol,Any}(),
                 round_sigdigits::Int=9)
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
  #Setup the opt_config file based on the data input and
  opt_config=set_opt_config_cep(opt_data; descriptor=descriptor, limit_emission=limit_emission, lost_load_cost=lost_load_cost, lost_emission_cost=lost_emission_cost, infrastructure=infrastructure, demand=demand, non_dispatchable_generation=non_dispatchable_generation, dispatchable_generation=dispatchable_generation, storage=storage, conversion=conversion, seasonalstorage=seasonalstorage, transmission=transmission, scale=scale, print_flag=print_flag, optimizer_config=optimizer_config, round_sigdigits=round_sigdigits)
  #Run the optimization problem
  run_opt(ts_data, opt_data, opt_config, optimizer)
end # run_opt
