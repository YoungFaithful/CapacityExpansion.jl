# This file exemplifies the workflow from data input to optimization result generation
using CEP
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
ts_clust_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=10000,n_clust=5) # default k-means make sure that n_init is high enough otherwise the results could be crap and drive you crazy
## OPTIMIZATION EXAMPLES##
# select optimizer
optimizer=Clp.Optimizer

# Optimize the capacity expansion problem with a co2_limit of 1000
cep = run_opt(ts_clust_data.best_results,cep_data,optimizer;co2_limit=1000)

# Extract the CAP-Variable
cap=cep.variables["CAP"]

# Prepare the data that shall be plotted
dat=sum(cap[:, "new", :], dims=2)
# Prepare the xticks
xticks=(1:length(axes(cap,"tech")),axes(cap,"tech"))

# Plot as a bar-plot
bar(dat,title="Cap", xticks=xticks ,legend=false)
