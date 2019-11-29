# This file exemplifies the workflow from data input to optimization result generation
using CapacityExpansion
using Clp
using Plots

## LOAD DATA ##
state="GER_18" # or "GER_18" or "CA_1" or "TX_1"
# laod ts-data
ts_input_data = load_timeseries_data_provided(state; T=24) #CEP
# load cep-data
opt_data = load_cep_data_provided(state)

## CLUSTERING ##
# run aggregation with kmeans
ts_clust_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=100,n_clust=5) # Increase n_init to 10000 for a "real" run
clust_data = ts_clust_data.clust_data
## OPTIMIZATION EXAMPLES##
# Setup configuration with a co2_limit of 1000
opt_config = OptConfig(clust_data, opt_data, Clp.Optimizer; limit_emission=Dict{String,Number}("CO2/electricity"=>1000))

# Optimize the capacity expansion problem
cep = run_opt(clust_data, opt_data, opt_config)

# Extract the CAP-Variable
cap=cep.variables["CAP"]

# Prepare the data that shall be plotted
dat=sum(cap[:, "new", :], dims=2)
# Prepare the xticks
xticks=(1:length(axes(cap,"tech")),axes(cap,"tech"))

# Plot as a bar-plot
bar(dat,title="Cap", xticks=xticks ,legend=false)
