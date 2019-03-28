using Test

@testset "CEP" begin
    using Clp
    using ClustForOpt
    @testset "TX_1" begin #Compare to Merrick Testcase
        # load data
        ts_input_data = load_timeseries_data("CEP", "TX_1"; T=24, years=[2008])
        cep_input_data=load_cep_data("TX_1")
        # run clustering
        ts_clust_res = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=1000,n_clust=365) # default k-means
        # run optimization
        model = run_opt(ts_clust_res.best_results,cep_input_data,Clp.Optimizer)
        # compare to exact result
        exact_res=[70540.26439790576;0.0;8498.278397905757;0.0;80132.88454450261]
        @test exact_res ≈ model.variables["CAP"].data[:,1,1] atol=1
    end
    @testset "Seasonal&Simple" begin #Check if seasonal with 24h and 365days has the same result as simple with 8760h in one period
        # load data
        ts_input_data_8760 = load_timeseries_data("CEP", "GER_1";T=8760,years=[2015])
        ts_input_data_24 = load_timeseries_data("CEP", "GER_1";T=24,years=[2015])
        cep_input_data_GER=load_cep_data("GER_1")
        # run clustering
        ts_clust_res_8760 = run_clust(ts_input_data_8760;method="kmeans",representation="centroid",n_init=1,n_clust=1) # default k-means
        ts_clust_res_24 = run_clust(ts_input_data_24;method="kmeans",representation="centroid",n_init=1,n_clust=365)
        # run optimization and compare if objective is exactly the same
        @test run_opt(ts_clust_res_8760.best_results,cep_input_data_GER,Clp.Optimizer;storage="simple").objective ≈ run_opt(ts_clust_res_24.best_results,cep_input_data_GER,Clp.Optimizer;storage="seasonal").objective atol=1
    end
    @testset "$state" for (state, years) in [["GER_1", [2016]],["CA_1", [2016]]] begin
        # laod data
        ts_input_data = load_timeseries_data("CEP", state; T=24, years=years) #CEP
        cep_data = load_cep_data(state)
        ## CLUSTERING ##
        ts_clust_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=100,n_clust=5)
        ts_full_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=1,n_clust=365)
        ## OPTIMIZATION ##
        optimizer=Clp.Optimizer
        @test run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="co2",co2_limit=1000).status==:OPTIMAL
        @test run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="slack",lost_el_load_cost=1e6, lost_CO2_emission_cost=700).status==:OPTIMAL
        @test run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="ex",existing_infrastructure=true).status==:OPTIMAL
        @test run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="simple storage",storage="simple").status==:OPTIMAL
        @test run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="seasonal storage",storage="seasonal").status==:OPTIMAL
        design_result=run_opt(ts_clust_data.best_results,cep_data,optimizer;descriptor="design&operation")
        @test run_opt(ts_full_data.best_results,cep_data,design_result.opt_config,get_cep_design_variables(design_result),optimizer;lost_el_load_cost=1e6,lost_CO2_emission_cost=700).status==:OPTIMAL
        end
    end
end
