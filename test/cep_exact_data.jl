using CEP
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
       exact_scenarios["$state-$years-co2"]=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="co2",co2_limit=1000)
       exact_scenarios["$state-$years-slack"]=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="slack",lost_el_load_cost=1e6, lost_CO2_emission_cost=700)
       exact_scenarios["$state-$years-ex"]=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="ex",existing_infrastructure=true)
       exact_scenarios["$state-$years-simple"]=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="simple storage",storage="simple")
       exact_scenarios["$state-$years-seasonal"]=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="seasonal storage",storage="seasonal")
       design_result=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="des&op")
       exact_scenarios["$state-$years-des&op"]=run_opt(ts_full_data.best_results,cep_data,design_result.opt_config,get_cep_design_variables(design_result),optimizer;lost_el_load_cost=1e6,lost_CO2_emission_cost=700)
end
for (state, years) in [["GER_18", [2016]],["CA_14", [2016]]]
       # laod data
       ts_input_data = load_timeseries_data_provided(state; T=24, years=years) #CEP
       cep_data = load_cep_data_provided(state)
       ## CLUSTERING ##
       ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=3)
       ## OPTIMIZATION ##
       optimizer=Clp.Optimizer
       exact_scenarios["$state-$years-trans"]=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="trans",transmission=true)
end

@save normpath(joinpath(dirname(@__FILE__),"cep_exact_data.jld2")) exact_scenarios
