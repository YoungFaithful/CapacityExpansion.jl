Quick Start Guide
=================

This quick start guide introduces the main concepts of using CapacityExpansion. For more detail on the different functionalities that CapacityExpansion provides, please refer to the subsequent chapters of the documentation or the examples in the [examples](https://github.com/YoungFaithful/CapacityExpansion.jl/tree/master/examples) folder.

Generally, the workflow consists of three steps:
- Data preparation of `ClustData`
- Data preparation of `OptDataCEP`
- Optimization

## Example Workflow
After `CapacityExpansion` and a [Solver](@ref) like e.g. `Clp` are installed, you can use them by saying:
```@repl workflow
using CapacityExpansion
using Clp
optimizer=Clp.Optimizer # defines the optimizer used by CapacityExpansion
```

The first step is to load the time-series input data. The following example loads hourly wind, solar, and demand data for Germany (1 region) for the year `2016`. The hourly input-data is split into periods with 24 elements, which equals days.
```@repl workflow
ts_input_data = load_timeseries_data_provided("GER_1"; T=24, years=[2016])
```
The output `ts_input_data` is a `ClustData` data struct that contains the data and additional information about the data.
```@repl workflow
ts_input_data.data # a dictionary with the data.
ts_input_data.data["wind-germany"] # the wind data (choose solar, `demand_electricity` as other options in this example)
ts_input_data.K # number of periods
```

The second step is to include the optimization data, which is not time-series depending.
```@repl workflow
cep_data = load_cep_data_provided("GER_1")
```
The `cep` is a `OptDataCEP` data struct.
```@repl workflow
cep.region # the region of the input-data
cep.costs # the information of costs as an `OptVariable` with 5 dimensions
```

The third step is to setup the model and run the optimization.
```@repl workflow
result = run_opt(ts_input_data,cep_data,optimizer)
```

The `result` is a `OptResult` data struct and contains the information of the optimization result.
```@repl workflow
result.info["model"] # the equations of the setup model
result.status # the status of the optimization
result.objective # the value of the objective
result.variables["CAP"] # the newly installed and existing capacities of the different technologies along the nodes. Other options are "COST" (the costs) and "GEN" (the generation)
result.sets["tech"]["generation"] # a `"tech"` (dimension) set of all `"generation"` (tech-group) within the model
result.config["generation"] # Detailed model configuration
```
