# This file exemplifies the workflow from data input to optimization result generation
using CapacityExpansion
using CapacityExpansionData
using Clp
using Plots

## LOAD DATA ##
state="GER_18" # or "GER_18" or "CA_1" or "TX_1"
# laod ts-data
ts_input_data = load_timeseries_data_provided(state; T=24) #CEP
# load cep-data
cep_data = load_cep_data_provided(state)

## CLUSTERING ##
# run aggregation with kmeans
ts_clust_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=100,n_clust=5) # Increase n_init to 10000 for a "real" run
## OPTIMIZATION EXAMPLES##
# select optimizer
optimizer=Clp.Optimizer

# Optimize the capacity expansion problem with a co2_limit of 1000
cep = run_opt(ts_clust_data.clust_data,cep_data,optimizer;limit_emission=Dict{String,Number}("CO2/electricity"=>1000))

# Extract the CAP-Variable
cap=cep.variables["CAP"]

# Prepare the data that shall be plotted
dat=sum(cap[:, "new", :], dims=2)
# Prepare the xticks
xticks=(1:length(axes(cap,"tech")),axes(cap,"tech"))

# Plot as a bar-plot
bar(dat,title="Cap", xticks=xticks ,legend=false)
