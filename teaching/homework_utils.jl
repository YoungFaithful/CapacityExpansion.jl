# Copyright 2019, Patricia Levi, Elias Kueppper, and contributors

## dependencies
using StatsPlots, DataFrames, CSV

"""
    groupedbar(var::OptVariable{T,N};
                    title::String="",
                    export_name="",
                    kwargs...) where {T,N}
Convert the provided OptVariable into a groupedbar-plot and export it
"""
import StatsPlots.groupedbar
function groupedbar(var::OptVariable{T,N};
                    title::String="",
                    export_name="",
                    kwargs...) where {T,N}
    if N==2
        outplot = groupedbar(var.axes[1], var.data; labels=var.axes[2], title = title, kwargs...)
    end
    if export_name!=""
        savefig(outplot, export_name*".png")
    end
    return outplot
end

"""
        dataframe(var::OptVariable{T,N};
                    export_name="") where {T,N}
Convert the provided OptVariable into a `DataFrame` and export it
"""
function dataframe(var::OptVariable{T,N};
                    export_name="") where {T,N}
    if N==2
        table=DataFrame(var.data)
        names!(table,Symbol.(var.axes[2]))
        table[Symbol(var.axes_names[1])]=var.axes[1]
    end
    showall(table)
    if export_name!=""
        CSV.write(export_name*".csv",table)
    end
end

"""
        plotcapacity(results::Array{OptResult,1},
                    outputname::String;
                    kwargs...)
Plot the capacity of the `results`-Array and form a table
"""
function plotcapacity(results::Array{OptResult,1},
                    outputname::String;
                    kwargs...)
    desc=Array{String,1}()
    techs=Array{String,1}()
    for result in results
        push!(desc, result.config["descriptor"])
        unique!(union!(techs, result.sets["tech"]["all"]))
    end

    cap=OptVariable{Number}(undef, techs, desc; axes_names=["tech", "results"])
    cap.=0
    for result in results
        for tech in result.sets["tech"]["node"]
            cap[tech, result.config["descriptor"]]=sum(result.variables["CAP"][tech,:,:])
        end
        if haskey(result.sets["tech"], "line")
            lines=load_cep_data_provided(result.config["region"]).lines
            for tech in result.sets["tech"]["line"]
                c=0
                for line in axes(lines, "line")
                    c+=sum(result.variables["TRANS"][tech,:,line])*lines[tech,line].length
                end
                cap[tech, result.config["descriptor"]]=c./1e3
            end
        end
    end
    dataframe(cap; export_name=outputname*"capdata")
    return groupedbar(cap; title="Installed Capacities", export_name=outputname*"capdata", yaxis="Capacities [MW] and Transmission [GW*km]", kwargs...)
end

"""
        plotcost(results::Array{OptResult,1},
                    outputname::String;
                    kwargs...)
Plot the costs of the `results`-Array and form a table
"""
function plotcost(results::Array{OptResult,1},
                outputname::String;
                kwargs...)
    desc=Array{String,1}()
    for result in results
        push!(desc, result.config["descriptor"])
    end

    cost=OptVariable{Number}(undef, desc, ["var", "cap_fix"]; axes_names=["results", "cost_type"])
    for result in results
        for cost_type in axes(cost, "cost_type")
            cost[result.config["descriptor"], cost_type]=sum(result.variables["COST"][cost_type,first(result.sets["impact"]["mon"]),:])
        end
    end
    dataframe(cost; export_name=outputname*"costdata")
    return groupedbar(cost; title="Costs", export_name=outputname*"costdata", bar_position=:stack, yaxis="Cost [$(first(first(results).sets["impact"]["mon"]))]", kwargs...)
end

"""
        plotgen(results::Array{OptResult,1},
                    outputname::String;
                    kwargs...)
Plot the gen of the `results`-Array and form a table
"""
function plotgen(results::Array{OptResult,1},
                outputname::String;
                kwargs...)
    desc=Array{String,1}()
    techs=Array{String,1}()
    for result in results
        push!(desc, result.config["descriptor"])
        unique!(union!(techs, result.sets["tech"]["power"]))
    end

    gen=OptVariable{Number}(undef, techs, desc; axes_names=["results", "tech"])
    gen.=0
    for result in results
        for tech in result.sets["tech"]["power"]
            g=0
            for k in result.sets["time_K"]["all"]
                for t in result.sets["time_T_period"]["all"]
                    g+=sum(result.variables["GEN"][tech,"electricity",t,k,:])*result.config["time_series"]["delta_t"][t,k]*result.config["time_series"]["delta_t"][k]
                end
            end
            gen[tech, result.config["descriptor"]]=g
        end
    end
    dataframe(gen; export_name=outputname*"gendata")
    return groupedbar(gen; title="Total Generation, Demand, Loss", export_name=outputname*"gendata", yaxis="Energy [MWh]", kwargs...)
end
