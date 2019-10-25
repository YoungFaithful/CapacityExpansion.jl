using CapacityExpansion
using Clp
using Plots
optimizer=Clp.Optimizer
state="GER_1"
ts_input_data = load_timeseries_data_provided(state; T=24, years=[2016])

plot(ts_input_data.data["solar-germany"], legend=false, linestyle=:dot, xlabel="Time [h]", ylabel="Solar availability factor [%]")
savefig(joinpath(dirname(@__FILE__),"preparing_clust_data_load.svg"))


ts_clust_data = run_clust(ts_input_data;method="kmeans",representation="centroid",n_init=50,n_clust=5).clust_data
plot(ts_clust_data.data["solar-germany"], legend=false, linestyle=:solid, width=3, xlabel="Time [h]", ylabel="Solar availability factor [%]")
savefig(joinpath(dirname(@__FILE__),"preparing_clust_data_agg.svg"))

cep_data = load_cep_data_provided(state)

co2_result = run_opt(ts_clust_data,cep_data,optimizer;descriptor="co2",co2_limit=500) #hide


# use the get variable set in order to get the labels: indicate the variable as "CAP" and the set-number as 1 to receive those set values
variable=co2_result.variables["CAP"]
labels=axes(variable,"tech")

data=variable[:,:,"germany"]
# use the data provided for a simple bar-plot without a legend
bar(data,title="Cap", xticks=(1:length(labels),labels),legend=false, ylabel="Capacity [MW]", xlabel="technologies", color="orange")
savefig(joinpath(dirname(@__FILE__),"opt_cep_cap_plot.svg"))
