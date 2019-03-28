# Elias Kuepper, Holger Teichgraeber, 2019

 ######################
 # CEP
 # Capacity Expansion Probelem formulation
 #
 #####################
module CEP
  using Reexport
  using StatsKit
  using ClustForOpt
  @reexport using JLD2
  using FileIO
  using JuMP

   export OptDataCEP,
          OptDataCEPTech,
          OptDataCEPNode,
          OptDataCEPLine,
          OptVariable,
          OptResult,
          Scenario,
          run_opt,
          load_cep_data,
          load_timeseries_cep,
          get_cep_variable_value,
          get_cep_variable_set,
          get_cep_slack_variables,
          get_cep_design_variables,
          get_total_demand

  include(joinpath("utils","datastructs.jl"))
  include(joinpath("utils","optvariable.jl"))
  include(joinpath("utils","utils.jl"))
  include(joinpath("utils","load_data.jl"))
  include(joinpath("optim_problems","run_opt.jl"))
  include(joinpath("optim_problems","opt_cep.jl"))
end # module CEP
