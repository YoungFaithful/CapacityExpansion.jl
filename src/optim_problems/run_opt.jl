"""
    run_opt(ts_data::ClustData,opt_data::OptDataCEP,opt_config::Dict{String,Any};optimizer::DataType)
organizing the actual setup and run of the CEP-Problem
"""
function run_opt(ts_data::ClustData,
                    opt_data::OptDataCEP,
                    opt_config::Dict{String,Any},
                    optimizer::DataType
                    )
  #Check the consistency of the data provided
  check_opt_data_cep(opt_data)
  cep=setup_opt_cep_basic(ts_data, opt_data, opt_config, optimizer, opt_config["optimizer_config"])
  setup_opt_cep_basic_variables!(cep, ts_data, opt_data)
  if opt_config["lost_load_cost"]["el"]!=Inf
    setup_opt_cep_lost_load!(cep, ts_data, opt_data)
  end
  if opt_config["lost_emission_cost"]["CO2"]!=Inf
    setup_opt_cep_lost_emission!(cep, ts_data, opt_data)
  end
  if opt_config["storage_in"] && opt_config["storage_out"] && opt_config["storage_e"] && opt_config["seasonalstorage"]
    setup_opt_cep_storage!(cep, ts_data, opt_data)
    setup_opt_cep_seasonalstorage!(cep, ts_data, opt_data)
  elseif opt_config["storage_in"] && opt_config["storage_out"] && opt_config["storage_e"] && !(opt_config["seasonalstorage"])
    setup_opt_cep_storage!(cep, ts_data, opt_data)
    setup_opt_cep_simplestorage!(cep, ts_data, opt_data)
  end
  if opt_config["transmission"]
      setup_opt_cep_transmission!(cep, ts_data, opt_data)
  end
  setup_opt_cep_generation_el!(cep, ts_data, opt_data)
  if opt_config["co2_limit"]!=Inf
    setup_opt_cep_co2_limit!(cep, ts_data, opt_data; co2_limit=opt_config["co2_limit"],  lost_emission_cost=opt_config["lost_emission_cost"])
  end
  setup_opt_cep_demand!(cep, ts_data, opt_data; lost_load_cost=opt_config["lost_load_cost"])
  if "fixed_design_variables" in keys(opt_config)
    setup_opt_cep_fix_design_variables!(cep, ts_data, opt_data; fixed_design_variables=opt_config["fixed_design_variables"])
  end
  if opt_config["existing_infrastructure"]
      setup_opt_cep_existing_infrastructure!(cep, ts_data, opt_data)
  end
  if opt_config["limit_infrastructure"]
      setup_opt_cep_limit_infrastructure!(cep, ts_data, opt_data)
  end
  setup_opt_cep_objective!(cep, ts_data, opt_data; lost_load_cost=opt_config["lost_load_cost"], lost_emission_cost=opt_config["lost_emission_cost"])
  return solve_opt_cep(cep, ts_data, opt_data, opt_config)
end

"""
     run_opt(ts_data::ClustData,opt_data::OptDataCEP,opt_config::Dict{String,Any},fixed_design_variables::Dict{String,OptVariable},optimizer::DataTyple;lost_el_load_cost::Number=Inf,lost_CO2_emission_cost::Number)
Wrapper function for type of optimization problem for the CEP-Problem (NOTE: identifier is the type of `opt_data` - in this case OptDataCEP - so identification as CEP problem)
This problem runs the operational optimization problem only, with fixed design variables.
provide the fixed design variables and the `opt_config` of the previous step (design run or another opterational run)
what you can add to the opt_config:
- `lost_el_load_cost`: Number indicating the lost load price/MWh (should be greater than 1e6),   give Inf for none
- `lost_CO2_emission_cost`: Number indicating the emission price/kg-CO2 (should be greater than 1e6), give Inf for none
- give Inf for both lost_cost for no slack
"""
function run_opt(ts_data::ClustData,
                    opt_data::OptDataCEP,
                    opt_config::Dict{String,Any},
                    fixed_design_variables::Dict{String,OptVariable},
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
     run_opt(ts_data::ClustData,opt_data::OptDataCEP,optimizer::DataTyple;descriptor::String="",co2_limit::Number=Inf,lost_el_load_cost::Number=Inf,lost_CO2_emission_cost::Number=Inf,existing_infrastructure::Bool=false,limit_infrastructure::Bool=false,storage::String="none",transmission::Bool=false,print_flag::Bool=true,print_level::Int64=0)
Wrapper function for type of optimization problem for the CEP-Problem (NOTE: identifier is the type of `opt_data` - in this case OptDataCEP - so identification as CEP problem)
options to tweak the model are:
- `descritor`: String with the name of this paricular model like "kmeans-10-co2-500"
- `co2_limit`: A number limiting the kg.-CO2-eq./MWh (normally in a range from 5-1250 kg-CO2-eq/MWh), give Inf or no kw if unlimited
- `lost_el_load_cost`: Number indicating the lost load price/MWh (should be greater than 1e6),   give Inf for none
- `lost_CO2_emission_cost`:
  - Number indicating the emission price/kg-CO2 (should be greater than 1e6), give Inf for none
  - give Inf for both lost_cost for no slack
- `existing_infrastructure`: true or false to include or exclude existing infrastructure to the model
- `storage`: String "none" for no storage or "simple" to include simple (only intra-day storage) or "seasonal" to include seasonal storage (inter-day)
"""
function run_opt(ts_data::ClustData,
                 opt_data::OptDataCEP,
                 optimizer::DataType;
                 descriptor::String="",
                 co2_limit::Number=Inf,
                 lost_el_load_cost::Number=Inf,
                 lost_CO2_emission_cost::Number=Inf,
                 existing_infrastructure::Bool=false,
                 limit_infrastructure::Bool=false,
                 storage::String="none",
                 transmission::Bool=false,
                 print_flag::Bool=true,
                 optimizer_config::Dict{Symbol,Any}=Dict{Symbol,Any}(),
                 round_digits::Int64=9)
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
  opt_config=set_opt_config_cep(opt_data; descriptor=descriptor, co2_limit=co2_limit, lost_load_cost=lost_load_cost, lost_emission_cost=lost_emission_cost, existing_infrastructure=existing_infrastructure, limit_infrastructure=limit_infrastructure, storage_e=storage, storage_in=storage, storage_out=storage, seasonalstorage=seasonalstorage, transmission=transmission, print_flag=print_flag, optimizer_config=optimizer_config, round_digits=round_digits)
  #Run the optimization problem
  run_opt(ts_data, opt_data, opt_config, optimizer)
end # run_opt
