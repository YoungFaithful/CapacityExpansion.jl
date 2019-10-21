# Copyright 2019, Patricia Levi and contributors

###################
# install & load packages
###################
## NB: this setup may take some time to run - on the order of a handful of minutes.
## You only need to run "Pkg.add" functions once, though
## The first time you call 'using' on a package, it will precomile, which will also take a few minutes
using Pkg
Pkg.add(["CapacityExpansion","Clp", "StatsPlots", "DataFrames", "CSV"])

# load packages - you must do this every time you restart julia
using CapacityExpansion, Clp, StatsPlots, DataFrames, CSV

### Add utils functions ###
## IF YOU ARE ABLE TO UPLOAD 'homework_utils.jl' TO FARMSHARE/
## THE DIRECTORY WHERE YOU ARE RUNNING THIS SCRIPT:
include(joinpath(@__DIR__,"homework_utils.jl"))
## OTHERWISE: COPY-PASTE THE CONTENTS OF plot_scripts.jl
## INTO THE COMMAND LINE

###################
### Set up data ###
###################
state="GER_18" # data is also provided for "GER_1", "CA_1", and "CA_14" - https://youngfaithful.github.io/CapacityExpansion.jl/dev/csv_structure/#Provided-Data-1
years=[2015]

# load non-timeseries data
cep_data = load_cep_data_provided(state)

# load timeseries data
ts_input_data = load_timeseries_data_provided(state; #input the states-name
        T=24, #input the number of time-steps per original period -> 24 hours per period
        years=years #input the years of data used
        )

# cluster timeseries data - run aggregation with a hierarchical clustering algorithm
# An aggregation of the temporal data is useful to reduce the computational
# complexity of a capacity expansion problem - further information: https://holgerteichgraeber.github.io/TimeSeriesClustering.jl/stable/
ts_clust_data = run_clust(ts_input_data;
        method="hierarchical", # use a hierarchical clustering method to groupt the periods
        representation="centroid", # represent the cluster with a centroid representation (the mean of the group)
        n_init=1, # choose the best result from a single run (partitional clustering methods instead of the hierarchical clusterin method need multiple initializations)
        n_clust=10 # choose the number of representative periods that represent the full time-series (e.g. we use 10 representative days to represent the original 365 days of a year to reduce the temporal complexity of the model)
        )
##############################
## PART 2: Initial CO2 Runs ##
##############################
# set up an optimizer
# An optimizer is used to solve the linear optimization problem that is constructed
# by CapacityExpansion.jl. https://youngfaithful.github.io/CapacityExpansion.jl/dev/opt_cep/#Solver-1
optimizer=Clp.Optimizer

# tweak the CO2 level
co2_low = run_opt(ts_clust_data.clust_data,cep_data,optimizer;
    descriptor = "co2_low", limit_emission=Dict{String,Number}("CO2/electricity"=>#=your choice=#))

co2_mid = run_opt(ts_clust_data.clust_data,cep_data,optimizer;
    descriptor = "co2_mid",limit_emission=Dict{String,Number}("CO2/electricity"=>#=your choice=#))

co2_high = run_opt(ts_clust_data.clust_data,cep_data,optimizer;
    descriptor = "co2_high",limit_emission=Dict{String,Number}("CO2/electricity"=>#=your choice=#))

results = [co2_low,co2_mid,co2_high]

# plot & inspect the results
plotcapacity(results,"baseruncapacity")
plotgen(results,"baserungeneration")
plotcost(results,"baseruncost")
# these functions also save a CSV of the displayed data, with the same name
# as the plot image
###################################
## PART 3: testing assumptions   ##
###################################
co2_limit_mid=co2_mid.config["limit_emission"]["CO2"]["electricity"]
##----------------
## Testing greenfield/brownfield
brownfield = run_opt(ts_clust_data.clust_data,cep_data,optimizer;
    descriptor = "brownf",
    limit_emission=Dict{String,Number}("CO2/electricity"=>co2_limit_mid),
    infrastructure=Dict{String,Array}("existing"=>["all"]))

# plot & inspect the results
results = [co2_mid, brownfield]
plotcapacity(results,"brownfieldcapacity")
plotgen(results,"brownfieldgeneration")
plotcost(results,"brownfieldcost")

##----------------
## Testing transmission constraints
trans_constrain = run_opt(ts_clust_data.clust_data,cep_data,optimizer;
    descriptor = "trans_constrain",
    limit_emission=Dict{String,Number}("CO2/electricity"=>co2_limit_mid),
    transmission = true
    )

# plot & inspect the results
results = [co2_mid, trans_constrain]
plotcapacity(results,"trans_constraincapacity")
plotgen(results,"trans_constraingeneration")
plotcost(results,"trans_constraincost")

###################################
## PART 4: storage sensitivities ##
###################################

##----------------
## how do the results change with storage?

simplestor = run_opt(ts_clust_data.clust_data,cep_data,optimizer;
    descriptor = "seasonal_stor",
    limit_emission=Dict{String,Number}("CO2/electricity"=>co2_limit_mid),
    storage_type="simple",
    conversion=true
    )
# In order to store hydrogen it needs to be converted from electriciy to hydrogen: need to activate conversion and select a storage_type
results = [co2_mid,seasonalstor]

# plot & inspect the results
plotcapacity(results,"storage_capacity")
plotgen(results,"storage_generation")
plotcost(results,"storage_cost")


##----------------
## change the 'simple' battery costs ##

# see current battery cost:
first(cep_data.costs["bat_e",:,:,"cap_fix","EUR"])

# make new cep_data with new battery costs
batt_cost_change = #your choice - fraction of previous cost#
cep_data2 = deepcopy(cep_data)
cep_data2.costs["bat_e",:,:,"cap_fix","EUR"] = cep_data.costs["bat_e",:,:,"cap_fix","EUR"].*batt_cost_change;
#= copy paste the above 3 lines, changing the name of "cep_data"
to create different datasets with different battery cost assumptions =#

# run model with your new cep_data versions
batt1 = run_opt(ts_clust_data.clust_data,#=new cep data=#,optimizer;
    descriptor = #=your choice =#,
    storage = "simple",
    conversion = true,
    limit_emission=Dict{String,Number}("CO2/electricity"=>co2_limit_mid))
batt2 = #...

# gather all results and plot
results =[simplestor,batt1, batt2 #=other batt versions =#]
plotcapacity(results,"battery_capacity")
plotgen(results,"battery_generation")
plotcost(results,"battery_cost")


##----------------
## change the seasonal storage costs
## by changing hydrogen costs

# see current hydrogen cost:
first(cep_data.costs["h2_in",:,:,"cap_fix","EUR"])

# make new cep_data with new hydrogen costs
h2_cost_change = #your choice#
cep_data2 = deepcopy(cep_data)
cep_data2.costs["h2_in",:,:,"cap_fix","EUR"] = cep_data.costs["h2_in",:,:,"cap_fix","EUR"].*h2_cost_change;
#= copy paste the above 3 lines, changing the name of "cep_data"
to create different datasets with different battery cost assumptions =#

run model with your new cep_data versions
hy1 = run_opt(ts_clust_data.clust_data,#=new cep data =#,optimizer;
    descriptor =#=your choice =#, co2_limit=#=your choice =#)
hy2 = #...

# gather all results and plot
results =[hy1, hy2 #=other hydrogen sensitivities =#]

plotcapacity(results,"hydrogen_capacity")
plotgen(results,"hydrogen_generation")
plotcost(results,"hydrogen_cost")

###################################
## PART 5: final analysis        ##
###################################
#=
if you want to run additional scenarios to inform your
understanding, do so here, following the workflow of
(1) modify costs
(2) run model
(3) combine model results that youd like to compare
(4) call plotting functions
You should be able to repurpose code from above to do so.
=#

#General alternative formulation for multiple calculations:
results = Array{OptResult,1}() #Setting up a new results Array that will be filled with results
for co2_limit in collect(100:100:500) #Loop through different configurations (e.g. a co2_limit)
    push!(results, run_opt(ts_clust_data.clust_data,cep_data,optimizer;
        descriptor = string(co2_limit),
        limit_emission=Dict{String,Number}("CO2/electricity"=>co2_limit))) # Push the new result from run_opt(your configuration) to the results-Array
end
