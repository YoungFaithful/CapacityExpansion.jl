---
title: 'CapacityExpansion: A capacity expansion modeling framework in Julia'
tags:
  - Julia
  - energy
  - optimization
  - storage
  - time series
  - teaching
authors:
  - name: Lucas Elias Kuepper
    orcid: 0000-0002-1992-310X
    affiliation: 1
  - name: Holger Teichgraeber
    orcid: 0000-0002-4061-2226
    affiliation: 1
  - name: Adam R. Brandt
    orcid: 0000-0002-2528-1473
    affiliation: 1
affiliations:
 - name: Department of Energy Resources Engineering, Stanford University
   index: 1
date: 4 October 2019
bibliography: paper.bib
---

# Summary

``CapacityExpansion`` is a Julia [@Bezanson:2017] implementation of a scale-independent capacity expansion modeling framework. It provides an extensible, multi-carrier, simple-to-use generation and transmission capacity expansion model that allows users to address a diverse set of research questions in the area of energy systems planning and can be used to plan and validate energy systems at scales ranging from districts to entire global regions.
``CapacityExpansion`` provides simple integration of (clustered) time-series, geographical, cost, and technology input data. The software features a modular model setup and an investment and dispatch optimization that uses the JUMP modeling language [@Dunning:2017]. An interface is provided between the optimization result and further analysis.

# Infrastructure planning in the energy sector

Energy systems convert different energy resources to meet desired demands like electric and thermal energy demands. Political, economical, and technological changes require expansions of the infrastructure of energy systems. Expanding the infrastructure has to balance multiple political, environmental, and economical objectives. Capacity expansion planning can be an important tool during the planning process [@Gacitua:2018].

Capacity expansion planning is used to compute cost-optimal energy system designs under given sets of constraints from the perspective of a central planner. The resulting cost-optimal energy system design can be used to inform policy decisions that incentivize the industry to invest in this design [@Johnston:2013]. Similarly, cost-optimal energy system designs can be used by companies for their investment strategies.

Aspects of the energy system design that capacity expansion planning aims to answer are what the optimal technology mix is in regards of location, time, and installed generation, conversion, storage, and transmission capacities. The design optimization is done while using an integrated dispatch formulation to ensure that supply can equal demand at all nodes and time steps. The model determines the costs, emissions, power generation, energy storage, and power flows based on the installed capacities.

Capacity expansion planning is formulated as a mathematical optimization problem. Like any optimization problem, capacity expansion planning has certain degrees of freedom, consisting of constraints and an objective function that is minimized: Typical degrees of freedom (also called decision variables) are installed capacities, power generation, energy storage, and power flows. Some constraints ensure that the model is physically consistent in itself and following the rules of thermodynamics, e.g. energy balances ensure energy conservation over time. Other constraints restrict the solution space to external conditions like costs, demands, available energy resources as well as other political, environmental, economical, or technological constraints. The objective function to determine cost-optimal investment can be total system cost, the net present value, or another business-oriented cost measure.

Dispatch planning formulations are very similar to capacity expansion formulations. However, the installed capacity is no degree of freedom, but introduced as an external constraint.

# Package features

The model class of ``CapacityExpansion`` is capacity expansion planning and it combines generation and transmission capacity expansion planning. The model is setup as a linear optimization model that models energy systems based on the provided input data. Multiple energy carriers can be modeled, which makes the software suitable for research of sector coupling technologies. Technologies can be defined that belong to dispatchable or non-dispatchable generation, conversion, storage, transmission, or demand. The decision variables of the model are investment and dispatch and the total system costs are minimized.

The following key features are provided by ``CapacityExpansion``. The usage and mathematical formulation is explained in detail within the software's documentation.

- *Modeling language*: The implementation in Julia enables the usage of a high-level programming language, and short times for data handling at the same time. The implementation in Julia also allows the usage of the mathematical optimization language JUMP, which enables the optimization formulation close to mathematical writing [@Dunning:2017]. The integration into the Julia ecosystem further allows to handle the process from data preparation to figure export within one programming language and software.

- *Provided input data*: The input data for single and multi-node representations of electricity systems are provided for California (USA) and Germany (EU). The input data provides hourly time-series input data for multiple years, aggregated geographic information about existing generation and transmission, cost information including the monetary and life cycle assessment costs, and necessary technology data. This input data can be used to address many research questions.

- *The generalized import of input data*: Modeling other energy systems is possible by adjusting the input data. The package extracts all information needed to model a specific energy system based on a few standardized input files. The time-series, geographic, and cost data can be edited as tables and integrated using the `.csv`-file format. The technology input data can be edited like a tree structure and integrated using the `.yml`-file format.

- *Integration of ``TimeSeriesClustering``*: Time-series data like the demand, available solar factors, and available wind factors are used as an input to model the temporal variance of the energy system. Aggregating the time-series input data is commonly done to reduce the computational complexity of the optimization. ``CapacityExpansion`` is well integrated with the Julia package ``TimeSeriesClustering`` [@Teichgraeber:2019]. This integration allows using the typical time-series aggregation methods [@Teichgraeber:2018], integrated testing of the temporal resolution, and an integrated feedback loops between the optimization result and time-series aggregation.

- *Seasonal storage*: A recent seasonal storage formulation from Kotzur is implemented to allow time-series aggregation and modeling of seasonal storage at the same time [@Kotzur:2018].

- *Modular model setup*: The model setup is flexible and based on a modular setup. Depending on the configuration different technology groups can be activated or deactivated, a green or brown field study performed, emissions limits can be enforced, different storage models can be used, and an integrated investment and dispatch or pure dispatch optimization can be run.

# ``CapacityExpansion`` within the broader ecosystem
``CapacityExpansion`` is the first officially published package to provide capacity expansion planning in Julia.

Multiple other software tools exist that support energy system planning both in Julia and other programming languages. We provide an overview of the broader ecosystem for orientation.

The [``Joulia``](https://github.com/JuliaEnergy/Joulia.jl/) package in Julia provides a modeling framework for electricity systems that optimizes dispatch [@Weibezahn:2019]. The generation, storage, and transmission capacities have to be provided as exogenous parameters.

The [``anyMOD``](https://github.com/leonardgoeke/anyMOD.jl/) package in Julia provides a modeling framework for energy system models with a focus on multi-period capacity expansion. Each energy carrier can be modeled on separate geospacial and temporal sets.

The [``InfrastructureModels``](https://github.com/lanl-ansi/InfrastructureModels.jl) package in Julia is a combination of multiple steady-state network optimization models to model electricity, gas, and water networks.

The [``Calliope``](https://github.com/calliope-project/calliope) package in Python provides a framework to develop energy system models [@Pfenninger:2018]. An experimental back end for JUMP exists with the package [``CalliopeJUMP``](https://github.com/calliope-project/CalliopeJuMP.jl). However, the ``CalliopeJUMP`` back end is called from within the ``Calliope`` framework in Python.

The [``URBS``](https://github.com/tum-ens/urbs) package in Python provides a framework for capacity expansion planning that uses a single `.xlsx`-file including the input data in form of tables and that contains information for the model configuration.

The [``Switch``](http://switch-model.org/) package in Python provides a framework for capacity expansion planning of electricity systems. The switch framework allows modular optimization model setup and the integration of custom modules.

The [``PyPSA``](https://github.com/PyPSA/PyPSA) package in Python provides a framework for capacity expansion planning and power flow modeling with a focus on the representation of the electricity network. The [``EnergyModels``](https://github.com/PyPSA/EnergyModels.jl) package is an unpublished Julia implementation for capacity expansion planning of the PyPSA community with the focus on electricity network modeling.

The model [``DIETER``](http://www.diw.de/dieter) package provides a framework for capacity expansion planning using the proprietary GAMS software for optimization and `.xlsx`-files for data import and export.

In combination ``TimeSeriesClustering`` and ``CapacityExpansion`` are the only packages written in Julia to intertwine aggregation methods of the input data and capacity expansion planning. E.g. time-series aggregation is gaining importance designing future energy systems with high shares of non-dispatchable generation.

# Applications
``CapacityExpansion`` can be applied to plan and validate a variety of energy systems. The focus on time-series aggregation, storage modeling, and integration of multiple energy carriers makes it especially valuable for the planning and validation of future energy systems with higher shares of non-dispatchable generation and sector coupling technologies. The scale of the modeled energy system can range from districts to entire global regions and is only restricted by the computational complexity of the model.

``CapacityExpansion`` has been used in academic research. It was used to analyze and improve the impact of time series aggregation methods on low emission energy systems [@Kuepper:2019].

Furthermore, ``CapacityExpansion`` has been used as an educational tool. It is used for modeling exercises in the Stanford University course "Advanced Methods in Modeling for Climate and Energy Policy". The teaching material is also provided open-source in the package.

# References
