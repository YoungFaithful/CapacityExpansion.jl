# Elias Kuepper, Holger Teichgraeber, 2019

 ######################
 # CaoacityExpansion
 # Capacity Expansion Probelem formulation
 #
 #####################
module CapacityExpansion
  using Reexport
  using CSV
  using YAML
  using DataFrames
  @reexport using StatsBase
  @reexport using TimeSeriesClustering
  @reexport using JLD2
  @reexport using FileIO
  using JuMP

  export  OptConfig,
          OptDataCEP,
          OptDataCEPTech,
          OptDataCEPNode,
          OptDataCEPLine,
          OptVariable,
          OptResult,
          Scenario,
          run_opt,
          load_cep_data,
          load_cep_data_provided,
          load_timeseries_data_provided,
          get_cep_variables,
          get_cep_slack_variables,
          get_cep_design_variables

  include(joinpath("utils","datastructs.jl"))
  include(joinpath("utils","optvariable.jl"))
  include(joinpath("utils","utils.jl"))
  include(joinpath("utils","load_data.jl"))
  include(joinpath("optim_problems","run_opt.jl"))
  include(joinpath("optim_problems","set.jl"))
  include(joinpath("optim_problems","opt.jl"))
end # module CapacityExpansion
