using Test
using CapacityExpansion
using Clp

@testset "CEP" begin
    @testset "TX_1" begin #Compare to Merrick Testcase
        # load data
        ts_input_data = load_timeseries_data_provided("TX_1"; T=24, years=[2008])
        cep_data = load_cep_data_provided("TX_1")
        # run optimization
        model = run_opt(ts_input_data,cep_data,Clp.Optimizer)
        # compare to exact result
        exact_res=[70540.26439790576;0.0;0.0;8498.278397905757;80132.88454450261;0.0]
        @test exact_res ≈ model.variables["CAP"].data[:,1,1] atol=1
    end
    scenarios=Dict{String,OptResult}()
    #Test the workflow for single node scenarios for Germany and California
    @testset "workflow $state" for (state, years) in [["GER_1", [2016]],["CA_1", [2016]]] begin
            # laod data
            ts_input_data = load_timeseries_data_provided(state; T=24, years=years) #CEP
            cep_data = load_cep_data_provided(state)
            ## CLUSTERING ##
            ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=3)
            ts_full_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=30)
            ## OPTIMIZATION ##
            optimizer=Clp.Optimizer
            optimizer_config=Dict{Symbol,Any}()
            scenarios["$state-$years-co2"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="co2",limit_emission=Dict{String,Number}("CO2/electricity"=>1000),optimizer_config=optimizer_config)
            scenarios["$state-$years-slack"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="slack",lost_load_cost=Dict{String,Number}("electricity"=>1e6), lost_emission_cost=Dict{String,Number}("CO2"=>700),optimizer_config=optimizer_config)
            scenarios["$state-$years-ex"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="ex",infrastructure=Dict{String,Array}("existing"=>["all"]),optimizer_config=optimizer_config)
            scenarios["$state-$years-simple"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="simple storage",storage_type="simple",conversion=true,optimizer_config=optimizer_config)
            scenarios["$state-$years-seasonal"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="seasonal storage",storage_type="seasonal",conversion=true,optimizer_config=optimizer_config)
            design_result=run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="des&op",optimizer_config=optimizer_config)
            scenarios["$state-$years-des&op"] = run_opt(ts_full_data.clust_data,cep_data,design_result.config,get_cep_design_variables(design_result),optimizer;lost_load_cost=Dict{String,Number}("electricity"=>1e6), lost_emission_cost=Dict{String,Number}("CO2"=>700))
        end
    end
    #Test transmission for a multi-node scenario
    @testset "workflow $state" for (state, years) in [["CA_14", [2016]]] begin
           # laod data
           ts_input_data = load_timeseries_data_provided(state; T=24, years=years) #CEP
           cep_data = load_cep_data_provided(state)
           ## CLUSTERING ##
           ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=3)
           ## OPTIMIZATION ##
           optimizer=Clp.Optimizer
           scenarios["$state-$years-trans"] = run_opt(ts_clust_data.clust_data,cep_data,optimizer;descriptor="trans",transmission=true,optimizer_config=Dict{Symbol,Any}())
       end
   end
   #Test exact values for each of the previously calculated scenarios by comparison with exact scenarios
   @load normpath(joinpath(dirname(@__FILE__),"cep_exact_data.jld2")) exact_scenarios
   @testset "exact $k" for (k,v) in scenarios begin
            #Test for each variable within this scenario
            @testset "variable $kv" for (kv,vv) in v.variables begin
                    @test sum((round.(round.(exact_scenarios[k].variables[kv].data; digits=3); sigdigits=3).== round.(round.(vv.data;digits=3); sigdigits=3)).== false) == 0
                end
            end
        end
    end
end
