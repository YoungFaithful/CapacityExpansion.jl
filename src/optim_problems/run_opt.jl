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
                    optimizer::DataType
                    )
  #Check the consistency of the data provided
  check_opt_data_cep(opt_data)
  #Setup the basic elements
  cep=setup_opt_cep_basic(ts_data, opt_data, opt_config, optimizer, opt_config["optimizer_config"])
  #Setup the basic variables
  setup_opt_cep_basic_variables!(cep, ts_data, opt_data)
  #If lost load costs aren't Inf, setup lost load (LL, SLACK)
  if opt_config["lost_load_cost"]["el"]!=Inf
    setup_opt_cep_lost_load!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #If lost emission costs aren't Inf, setup lost emission (LE)
  if opt_config["lost_emission_cost"]["CO2"]!=Inf
    setup_opt_cep_lost_emission!(cep, ts_data, opt_data)
  end
  #If storage and seasonalstorage, setup seasonal storage (continous)
  if opt_config["storage_in"] && opt_config["storage_out"] && opt_config["storage_e"] && opt_config["seasonalstorage"]
    setup_opt_cep_storage!(cep, ts_data, opt_data, opt_config["scale"])
    setup_opt_cep_seasonalstorage!(cep, ts_data, opt_data, opt_config["scale"])
  #Else if storage, but no seasonalstorage, setup intra-day storage (same level in first and last time step for each period)
  elseif opt_config["storage_in"] && opt_config["storage_out"] && opt_config["storage_e"] && !(opt_config["seasonalstorage"])
    setup_opt_cep_storage!(cep, ts_data, opt_data, opt_config["scale"])
    setup_opt_cep_simplestorage!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #If transmission, setup TRANS and FLOW
  if opt_config["transmission"]
      setup_opt_cep_transmission!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup the electricity generation
  setup_opt_cep_generation_el!(cep, ts_data, opt_data, opt_config["scale"])
  #If co2-limit isn't Inf, limit the total co2 output of the energy system
  if opt_config["co2_limit"]!=Inf
    setup_opt_cep_co2_limit!(cep, ts_data, opt_data, opt_config["scale"]; co2_limit=opt_config["co2_limit"],  lost_emission_cost=opt_config["lost_emission_cost"])
  end
  # Setup the energy balences to match the demand
  setup_opt_cep_demand!(cep, ts_data, opt_data, opt_config["scale"]; lost_load_cost=opt_config["lost_load_cost"])
  #If fixed_design_variables are provided, fix the installed capacities to them
  if "fixed_design_variables" in keys(opt_config)
    setup_opt_cep_fix_design_variables!(cep, ts_data, opt_data, opt_config["scale"], opt_config["fixed_design_variables"])
  end
  #If existing_infrastructure, add existing infrastructure
  if opt_config["existing_infrastructure"]
      setup_opt_cep_existing_infrastructure!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #If limit_infrastructure, limit the infrastructure expansion
  if opt_config["limit_infrastructure"]
      setup_opt_cep_limit_infrastructure!(cep, ts_data, opt_data, opt_config["scale"])
  end
  #Setup the objective
  setup_opt_cep_objective!(cep, ts_data, opt_data, opt_config["scale"]; lost_load_cost=opt_config["lost_load_cost"], lost_emission_cost=opt_config["lost_emission_cost"])
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
- `lost_el_load_cost`: Number indicating the lost load price/MWh (should be greater than 1e6), give a number lower than Inf for SLACK and LL (Lost Load - a variable for unmet demand by the installed capacities). No SLACK and LL can lead to infeasibilities.
- `lost_CO2_emission_cost`: Number indicating the emission price/kg-CO2 (should be greater than 1e6), give Inf for no LE (Lost Emissions - a variable for emissions that will exceed the limit in order to provide the demand with the installed capacities). No LE can lead to a higher SLACK and LL, as the optimization is not allowed to break any emission limit then.
"""
function run_opt(ts_data::ClustData,
                    opt_data::OptDataCEP,
                    opt_config::Dict{String,Any},
                    fixed_design_variables::Dict{String,Any},
                    optimizer::DataType;
                    lost_el_load_cost::Number=Inf,
                    lost_CO2_emission_cost::Number=Inf)
  # Create dictionary for lost_load_cost of the single elements
  lost_load_cost=Dict{String,Number}("el"=>lost_el_load_cost)
  # Create dictionary for lost_emission_cost of the single elements
  lost_emission_cost=Dict{String,Number}("CO2"=>lost_CO2_emission_cost)
  # Add the fixed_design_variables and new setting for slack costs to the existing config
  set_opt_config_cep!(opt_config;fixed_design_variables=fixed_design_variables, lost_load_cost=lost_load_cost, lost_emission_cost=lost_emission_cost)

  return run_opt(ts_data,opt_data,opt_config,optimizer)
end

"""
     run_opt(ts_data::ClustData,opt_data::OptDataCEP,optimizer::DataTyple;co2_limit::Number=Inf,lost_el_load_cost::Number=Inf,lost_CO2_emission_cost::Number=Inf,existing_infrastructure::Bool=false,limit_infrastructure::Bool=false,storage::String="none",transmission::Bool=false,descriptor::String="",print_flag::Bool=true,optimizer_config::Dict{Symbol,Any}=Dict{Symbol,Any}(),round_sigdigits::Int=9)
Wrapper function for type of optimization problem for the CEP-Problem (NOTE: identifier is the type of `opt_data` - in this case OptDataCEP - so identification as CEP problem).
Required elements are:
- `ts_data`: The time-series data, which could either be the original input data or some aggregated time-series data. The `keys(ts_data.data)` need to match the `[time_series_name]-[node]`
- `opt_data`: The OptDataCEP that contains information on costs, nodes, techs and for transmission also on lines.
- `optimizer`: The used optimizer, which could e.g. be Clp: `using Clp` `optimizer=Clp.Optimizer` or Gurobi: `using Gurobi` `optimizer=Gurobi.Optimizer`.
Options to tweak the model are:
- `co2_limit`: A number limiting the kg.-CO2-eq./MWh (normally in a range from 5-1250 kg-CO2-eq/MWh), give Inf or no kw if unlimited
- `lost_el_load_cost`: Number indicating the lost load price/MWh (should be greater than 1e6), give Inf for no SLACK and LL (Lost Load - a variable for unmet demand by the installed capacities)
- `lost_CO2_emission_cost`: Number indicating the emission price/kg-CO2 (should be greater than 1e6), give Inf for no LE (Lost Emissions - a variable for emissions that will exceed the limit in order to provide the demand with the installed capacities)
- `existing_infrastructure`: true or false to include or exclude existing infrastructure to the model
- `storage`: String "none" for no storage or "simple" to include simple (only intra-day storage) or "seasonal" to include seasonal storage (inter-day)
Optional elements are:
- `descriptor`: String with the name of this paricular model like "kmeans-10-co2-500"
- `print_flag`: Bool to decide if a summary of the Optimization result should be printed.
- `optimizer_config`: Each Symbol and the corresponding value in the Dictionary is passed on to the `with_optimizer` function in addition to the `optimizer`. For Gurobi an example Dictionary could look like `Dict{Symbol,Any}(:Method => 2, :OutputFlag => 0, :Threads => 2)` more information can be found in the optimizer specific documentation.
- `round_sigdigits`: Can be used to round the values of the result to a certain number of `sigdigits`.
"""
function run_opt(ts_data::ClustData,
                 opt_data::OptDataCEP,
                 optimizer::DataType;
                 co2_limit::Number=Inf,
                 lost_el_load_cost::Number=Inf,
                 lost_CO2_emission_cost::Number=Inf,
                 existing_infrastructure::Bool=false,
                 limit_infrastructure::Bool=false,
                 storage::String="none",
                 transmission::Bool=false,
                 scale::Dict{Symbol,Int}=Dict{Symbol,Int}(:COST => 1e9, :CAP => 1e3, :GEN => 1e3, :SLACK => 1e3, :INTRASTOR => 1e3, :INTERSTOR => 1e6, :FLOW => 1e3, :TRANS =>1e3, :LL => 1e6, :LE => 1e9),
                 descriptor::String="",
                 print_flag::Bool=true,
                 optimizer_config::Dict{Symbol,Any}=Dict{Symbol,Any}(),
                 round_sigdigits::Int=9)
   # Activated seasonal or simple storage corresponds with storage
   if storage=="seasonal"
       storage=true
       seasonalstorage=true
   elseif storage=="simple"
       storage=true
       seasonalstorage=false
   elseif storage =="none"
       storage=false
       seasonalstorage=false
  else
      storage=false
      seasonalstorage=false
      @warn("String indicating storage not identified as 'none', 'seasonal' or 'simple' → no storage")
   end
  # Create dictionary for lost_load_cost of the single elements
  lost_load_cost=Dict{String,Number}("el"=>lost_el_load_cost)
  # Create dictionary for lost_emission_cost of the single elements
  lost_emission_cost=Dict{String,Number}("CO2"=>lost_CO2_emission_cost)

  #Setup the opt_config file based on the data input and
  opt_config=set_opt_config_cep(opt_data; descriptor=descriptor, co2_limit=co2_limit, lost_load_cost=lost_load_cost, lost_emission_cost=lost_emission_cost, existing_infrastructure=existing_infrastructure, limit_infrastructure=limit_infrastructure, storage_e=storage, storage_in=storage, storage_out=storage, seasonalstorage=seasonalstorage, transmission=transmission, scale=scale, print_flag=print_flag, optimizer_config=optimizer_config, round_sigdigits=round_sigdigits)
  #Run the optimization problem
  run_opt(ts_data, opt_data, opt_config, optimizer)
end # run_opt
