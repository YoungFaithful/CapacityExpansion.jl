using CapacityExpansion
using Clp
exact_scenarios=Dict{String,OptResult}()
for (state, years) in [["GER_1", [2016]],["CA_1", [2016]]]
       # laod data
       ts_input_data = load_timeseries_data_provided(state; T=24, years=years) #CEP
       cep_data = load_cep_data_provided(state)
       ## CLUSTERING ##
       ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=3)
       ts_full_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=30)
       ## OPTIMIZATION ##
       optimizer=Clp.Optimizer
       optimizer_config=Dict{Symbol,Any}(:LogLevel => 0)
       exact_scenarios["$state-$years-co2"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="co2",limit_emission=Dict{String,Number}("CO2/electricity"=>1000),optimizer_config=optimizer_config)
       exact_scenarios["$state-$years-slack"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="slack",lost_load_cost=Dict{String,Number}("electricity"=>1e6), lost_emission_cost=Dict{String,Number}("CO2"=>700),optimizer_config=optimizer_config)
       exact_scenarios["$state-$years-ex"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="ex",infrastructure=Dict{String,Array}("existing"=>["all"]),optimizer_config=optimizer_config)
       exact_scenarios["$state-$years-simple"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="simple storage",storage_type="simple",conversion=true,optimizer_config=optimizer_config)
       exact_scenarios["$state-$years-seasonal"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="seasonal storage",storage_type="seasonal",conversion=true,optimizer_config=optimizer_config)
       design_result=run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="des&op",optimizer_config=optimizer_config)
       exact_scenarios["$state-$years-des&op"] = run_opt(ts_full_data.clust_data,cep_data,design_result.opt_config,get_cep_design_variables(design_result),optimizer;lost_load_cost=Dict{String,Number}("electricity"=>1e6), lost_emission_cost=Dict{String,Number}("CO2"=>700))
end
for (state, years) in [["GER_18", [2016]],["CA_14", [2016]]]
       # laod data
       ts_input_data = load_timeseries_data_provided(state; T=24, years=years) #CEP
       cep_data = load_cep_data_provided(state)
       ## CLUSTERING ##
       ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=3)
       ## OPTIMIZATION ##
       optimizer=Clp.Optimizer
       optimizer_config=Dict{Symbol,Any}(:LogLevel => 0)
       exact_scenarios["$state-$years-trans"]=run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="trans",transmission=true,optimizer_config=optimizer_config)
end

@save normpath(joinpath(dirname(@__FILE__),"cep_exact_data.jld2")) exact_scenarios
