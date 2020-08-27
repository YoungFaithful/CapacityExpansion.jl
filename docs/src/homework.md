# Homework: Modeling Exercise
Copyright 2019, Patricia Levi, Elias Kuepper, and contributors

!!! note
        The corresponding files can be found in the folder [.../CapacityExpansion/teaching/](https://github.com/YoungFaithful/CapacityExpansion.jl/tree/dev/teaching)

MS&E 394 Spring 2019

Advanced Methods in Modeling for Climate and Energy Policy at Stanford University

Modelling Exercise: Capacity Expansion Planning

Due: May 6, 2019, at 10pm

!!! note
    This problem set serves to reinforce concepts from the class regarding capacity expansion modelling for electricity. It provides hands-on experience in understanding and interpreting the outputs of a typical capacity expansion problem and grappling with the inevitable modelling decisions that must be made. It also requires you to work through a command-line interface and understand how to connect to a remote server, valuable skills for working with large models that are hosted beyond your laptop.

## Initial instructions:

- You may work with other students to run the model. However, you are expected to understand everything that is done, write up your own interpretations, and submit your own homework. If you do work together, please note that on your problem set.
- The scripts ``homework\_utils.jl`` and ``homework\_template.jl`` contain the code you will need to run to complete this problem set. The first contains helper plotting functions. The second contains examples of the code you need to run to answer the questions below. You will need to add to the provided code to complete this homework, and you should submit a copy of your code along with your writeup.
- This problem set should be written in such a way that you should not need any specific knowledge of Julia to complete it, although it will probably feel easier if you are comfortable with a scripting language. If you find that the contained instructions are insufficient, please reach out.

### Modeling tool: Julia

Julia is a relatively new programming language that is quickly being adopted for a variety of uses due to its fast run times with large operations. It has a robust set of optimization packages that make it ideal for electricity optimization problems. Elias Kuepper and Holger Teichgraeber have developed a package for Julia that runs a classic capacity expansion model, which we will be using for this problem set.

In order to run julia-code you can use a local julia installation on your computer.

## Part 1: Getting Set Up

1. Install julia via [these instructions](http://docs.junolab.org/latest/man/installation/) on your computer. This problem set is designed to run with a julia version 1.0 or higher. We also recommend installing the [Juno-IDE](https://junolab.org/).
2. Open Atom
3. File/Open Folder... (Ctr+Shift+O) and select your homework directory
4. Open the `homework_template.jl`-file and run it line by line (Shift+Enter). You can interactively have a look at the results, and the plots will be shown within Atom.

### Overview of CapacityExpansion.jl

`CapacityExpansion.jl` is a package that runs a basic capacity expansion model, as described in class. The documentation is available [here](https://youngfaithful.github.io/CapacityExpansion.jl/stable/). We are using it to model Germany using 2015 data. In this problem set, the package's integrated clustering algorithm selects 10 representative days to model the whole year. To begin, we will use it as a greenfield model with no transmission constraints, but it is capable of representing greater detail on these fronts.

This model runs relatively quickly, although in some configurations it may take a few minutes to run. If you find it takes much longer (say, upwards of 10 minutes), chances are you don't need to do what you're doing (or your computer is running very slowly).

The main function you will be interacting with is run\_opt(), which runs the capacity expansion problem. There are two sets of arguments given to this function, separated by a semicolon. The first set are unnamed arguments, and they include the time-series data (ts\_clust\_data.clust\_data), non-time-series data (cep\_data), and the type of optimizer to use. The second set is named (i.e. identified with _argname_= _your argument value_), and this is where we will be adjusting key parameters like the CO2 emissions limit, the transmission constraints, and the type of storage that is available. The ``descriptor`` argument is for identifying the results of that run in plots and charts, so please name it appropriately.

There are two ways to run the code:

1. Copy pasting the code from your code editor directly into the command line.
2. Once you have adjusted the code to your liking, save your edited code, and then call `include("homework\_template.jl")` from Julia. The downside of this approach is that it may be harder to deal with errors. The upside is that you can go make yourself a cup of coffee while the code runs.

Recommended to start with (1) and progress to (2) once you think your script does exactly what you want.

Overview of available plotting scripts

There are three plotting scripts available to help visualize your results. They each create a bar chart and save it, and they display the underlying data for the plot and save that as a CSV. They will save their output in the directory in which you are running Julia. The provided script shows how to use them. They all take, as a first argument, an array of model results created like this:
```julia
results = [modelresult1, modelresult2, modelresult3]
```
As a second argument, they all take an output name that will be used to name the `.png`-file of the plot and the `.csv`-file saved by the function. They all save a `.png`-file of the plot and a `.csv`-file of the plotted data by default.

1. **plotgen()**
  plots the total generation over the whole year from different resources
2. **plotcapacity()**
  plots the total installed capacity by generation type
3. **plotcost()**
  plots the cost of operating the system for the whole year.

General workflow

For each part below, we will follow the following workflow:

1. Adjust technology costs if needed (only in the sensitivities section) by creating a new version of the `cep\_data` variable and providing that to `run\_opt()` when you call it.
2. Run the model several times with different parameter values
3. Combine the results together that we wish to compare
4. Plot them and inspect the results

## Part 2 – Comparing Policies

A policy-maker in Germany wants to set a CO2 emissions rate limit for their electricity sector for 2050, but they are not sure what level to set. They need you to help them understand the impacts of different possible limits. The highest rate they are considering is 500 kg-CO2
e/MWh, and the lowest is 10 kg-CO2e/MWh. They would like to better understand the tradeoffs between a tighter cap and greater costs.

1. Run the model for several different levels of emissions rate limits (the code is set up to do three, but you may do more), and describe how cost, capacity, and generation shift with tighter caps. Include any data or plots needed to make your point

## Part 3 – Testing Assumptions

The model we are running makes several simplifying assumptions. By default, it assumes a greenfield model with no transmission constraints. Before proceeding with our study, we should test a few key assumptions.

1. First test the greenfield assumption, which allows the model to build the electricity system from scratch, without considering the existing generation. Compare the results with and without existing infrastructure by setting
```julia
infrastructure=Dict{String,Array}("existing"=>["all"])
```
instead of the default, where only demand is existing
```julia
infrastructure=Dict{String,Array}("existing"=>["demand"])
```
inside of the model call. You may choose to compare this run with one of the ones done in _part 2_, but be sure to use the same emissions limit.  Describe the effect, and include any data or plots needed to make your point. Argue whether it makes more sense to run a greenfield or a brownfield model, and use that assumption for the rest of your simulations.

1. Next, test the transmission assumption.  The first simulations did not include transmission constraints. Compare the results with and without transmission by setting
```julia
transmission = true #or false
```
inside of the model call (`false` is the default). You may choose to compare this run with one of the ones done in _part 2_, but be sure to use the same emissions limit. Discuss the effect of including transmission constraints and argue whether the gain in realism is worth the cost in increased computational complexity, and include any data or plots needed to make your point. Use the better assumption for the rest of your simulations.

!!! note
    There are no right or wrong choices here. We are looking for a reasonable explanation of your choice, and an understanding of the pros, cons, and potential impact on your results.

## Part 4 – Storage Sensitivities

The policy-maker who has posed this question to you is very interested in R&amp;D for battery technology, and is quite the technological optimist regarding their potential. They are curious how declines in storage costs might affect these results. Keep in mind that the effect may be different at different levels of emissions cap stringency.

1. First, test the effect of including storage in the model by setting
```julia
storage_type = "simple"
conversion = true
```
inside of the model call and keeping this setting for the remainder of this part. This setting makes batteries and hydrogen storage available. Compare the results of this simulation to a previous simulation and comment on the effect, and include any data or plots needed to make your point.

2. Next, test the effect of declines in the cost of battery storage costs – simulate a range of cost declines. Describe how they affect the outcomes of a relatively high CO2 cap and a relatively low CO2 cap, and include any data or plots needed to make your point.

3. Finally, test the effect of declines in the cost of hydrogen storage costs – simulate a range of cost declines. Describe how they affect the outcomes of a relatively high CO2 cap and a relatively low CO2 cap, and include any data or plots needed to make your point.

## Part 5 – Final Analysis

Write a short summary of your recommendations to the policy-maker. Describe your findings as they may be relevant to the policy-maker's given interests, including key differences between the options, describing the impact of essential uncertainties, and noting any key limitations to your study. Conduct any final simulations, if you feel there is some combination of parameters that would be useful to explore.

!!! note
    The question is intended to be broad and open-ended, as this type of broad synthesis is a key part of policy analysis. Use your best judgment to provide insight to this policy-maker, telling them the key features from your results that will inform their upcoming decisions. We are looking for a clear and cogent explanation of a few key results, explained in a way that a non-technical person could understand.
