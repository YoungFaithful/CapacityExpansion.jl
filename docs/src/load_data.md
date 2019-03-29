# Load Data
The CEP needs two types of data
- Time series data in the type `ClustData`
- Cost, node, (line), and technology data in the type `OptDataCEP`

## ClustData - Time Series Data
### Provided Data
`load_timeseries_data_provided()` loads the data for a given `region` for which data is provided in this package.
The optional input parameters to `load_timeseries_data_provided()` are the number of time steps per period `T` and the `years` to be imported.

```@docs
load_timeseries_data_cep
```
### Your own Data
For details refer to [ClustForOpt](https://github.com/holgerteichgraeber/ClustForOpt.jl)
!!! The keys of `{your-time-series}.data` have to match `"{time_series (as declared in techs.csv)}-{node}"`

```@docs
load_timeseries_data
```
### Aggregation
Time series aggregation can be applied to reduce the temporal dimension while (if done problem specific correctly) keeping output precise.
Aggregation methods are explained in [ClustForOpt](https://github.com/holgerteichgraeber/ClustForOpt.jl)
High encouragement to run a second stage validation step if you use aggregation on your model. [Example for second stage operational validation step](@ref)
### Examples
#### Loading time series data
```@example
using CEP
state="GER_1"
# laod ts-input-data
ts_input_data = load_timeseries_data_provided(state; T=24, years=[2016])
using Plots
plot(ts_input_data.data["solar-germany"], legend=false, linestyle=:dot, xlabel="Time [h]", ylabel="Solar availability factor [%]")
savefig("load_timeseries_data.svg")
```
![Plot](load_timeseries_data.svg)
#### Aggregating time series data
```@example
using ClustForOpt
state="GER_1"
# laod ts-input-data
ts_input_data, = load_timeseries_data("CEP", state; K=365, T=24)
ts_clust_data = run_clust(ts_input_data).best_results
using Plots
plot(ts_clust_data.data["solar-germany"], legend=false, linestyle=:solid, width=3, xlabel="Time [h]", ylabel="Solar availability factor [%]")
savefig("clust.svg")
```
![Plot](clust.svg)

### OptDataCEP
## Provided Data
`load_cep_data_provided` loads the non time-series dependent data for the `CEP` and can take the following regions:
- `GER`: Germany
- `CA`: California
- `TX`: Texas

```@docs
load_cep_data_provided
```
## Your Own Data
Use `load_cep_data` with `data_path` pointing to the folder with your cost, node, (line), and technology data.

```@docs
load_cep_data
load_cep_data_techs
load_cep_data_nodes
load_cep_data_lines
load_cep_data_costs
```
## Examples
### Example loading CEP Data
```@example
using CEP
state="GER_1"
# load ts-input-data
cep_data = load_cep_data_provided(state)
cep_data.costs
```
