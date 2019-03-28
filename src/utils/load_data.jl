"""
    load_timeseriesdata!(dt::Dict{String,Array}, data_path::String; num::Int64=0)
- Adding the information in the `*.csv` file at `data_path` to the data dictionary
The `*.csv` files shall have the following structure and must have the same length:
|Timestamp |[column names...]|
|[iterator]|[values]         |
The first column should be called `Timestamp` if it contains a time iterator
The other columns can specify the single timeseries like specific geolocation.
"""
function load_timeseries_cep(application::String,
                              region::String;
                              T::Int64=24,
                              years::Array{Int64,1}=[2016],
                              att::Array{String,1}=Array{String,1}())
    # Generate the data path based on application and region
    data_path=normpath(joinpath(dirname(@__FILE__),"..","..","data",application,region,"TS"))
    return load_timeseries_data(data_path; T=T, years=years, att=att)
end

function load_cep_data_techs(data_path::String)
    tab=CSV.read(joinpath(data_path,"techs.csv"),allowmissing=:none)
    #Check existance of necessary column
    :tech in names(tab) || throw(@error "No column called `tech` in `techs.csv`")
    #Build empty OptVariable
    techs=OptVariable{OptDataCEPTech}(undef, unique(tab[:tech]); type="fv", axes_names=["tech"])
    # loop through all axes
    for tech in axes(techs,"tech")
        #categ
        categ=tab[(:tech,tech),:categ][1]
        #sector::String
        sector=tab[(:tech,tech),:sector][1]
        #eff::Number
        eff=tab[(:tech,tech),:eff][1]
        #time_series::String
        time_series=tab[(:tech,tech),:time_series][1]
        #lifetime::Number
        lifetime=tab[(:tech,tech),:lifetime][1]
        #financial_lifetime::Number
        financial_lifetime=tab[(:tech,tech),:financial_lifetime][1]
        #discount_rate::Number
        discount_rate=tab[(:tech,tech),:discount_rate][1]
        # The time for the cap-investion to be paid back is the minimum of the max. financial lifetime and the lifetime of the product (If it's just good for 5 years, you'll have to rebuy one after 5 years)
        # annuityfactor = (1+i)^y*i/((1+i)^y-1) , i-discount_rate and y-payoff years
        annuityfactor=round((1+discount_rate)^(min(financial_lifetime,lifetime)) *discount_rate/ ((1+discount_rate) ^(min(financial_lifetime,lifetime))-1); sigdigits=9)
        # Add single data entry
        techs[tech]=OptDataCEPTech(categ,sector,eff,time_series,lifetime,financial_lifetime,discount_rate,annuityfactor)
    end
    return techs
end

function load_cep_data_nodes(data_path::String, techs::OptVariable)
    tab=CSV.read(joinpath(data_path,"nodes.csv"),allowmissing=:none)
    # Check exisistance of columns
    check_column(tab,[:node, :infrastruct])
    #Create empty OptVariable
    nodes=OptVariable{OptDataCEPNode}(undef, axes(techs,"tech"), unique(tab[:node]); type="fv", axes_names=["tech", "node"])
    for tech in axes(nodes,"tech")
        for node in axes(nodes,"node")
            #value
            power_ex=tab[(:node,node)][(:infrastruct,"ex"),Symbol(tech)][1]
            power_lim=tab[(:node,node)][(:infrastruct,"lim"),Symbol(tech)][1]
            #region
            region=tab[(:node,node),:region][1]
            #lat and lon
            latlon=LatLon(tab[(:node,node),:lat][1],tab[(:node,node),:lon][1])
            nodes[tech,node]=OptDataCEPNode(power_ex, power_lim, region, latlon)
        end
    end
    return nodes
end

function load_cep_data_lines(data_path::String, techs::OptVariable)
    if isfile(joinpath(data_path,"lines.csv"))
        tab=CSV.read(joinpath(data_path,"lines.csv"),allowmissing=:none)
        #Check existance of necessary column
        check_column(tab, [:line])

        #Create empty OptVariable
        lines=OptVariable{OptDataCEPLine}(undef, unique(tab[:tech]), unique(tab[:line]); type="fv", axes_names=["tech", "line"])
        for tech in axes(lines,"tech")
            for line in axes(lines,"line")
                #node_start
                node_start=tab[(:tech,tech)][(:line,line),:node_start][1]
                #node_end
                node_end=tab[(:tech,tech)][(:line,line),:node_end][1]
                #reactance
                reactance=tab[(:tech,tech)][(:line,line),:reactance][1]
                #resistance
                resistance=tab[(:tech,tech)][(:line,line),:resistance][1]
                #power
                power_ex=tab[(:tech,tech)][(:line,line),:power_ex][1]
                #power
                power_lim=tab[(:tech,tech)][(:line,line),:power_lim][1]
                #circuits
                circuits=tab[(:tech,tech)][(:line,line),:circuits][1]
                #voltage
                voltage=tab[(:tech,tech)][(:line,line),:voltage][1]
                #length
                length=tab[(:tech,tech)][(:line,line),:length][1]
                #eff calculate the efficiency provided as eff/km in techs
                #η=1-l_{line}⋅(1-η_{tech}) [-]
                eff=1-length*(1-techs[tech].eff)
                lines[tech,line]=OptDataCEPLine(node_start,node_end,reactance,resistance,power_ex,power_lim,circuits,voltage,length,eff)
            end
        end
        return lines
    else
        return lines=OptVariable{OptDataCEPLine}(undef, Array{String,1}(), Array{String,1}(); type="fv", axes_names=["tech", "line"])
    end
end

"""
    get_region_data(nodes::OptVariable,tab::DataFrame,tech::String,node::String,account::String)
Return the name of the region `region` or `"all"` that data is provided for in the `tab`
"""
function get_location_data(nodes::OptVariable,tab::DataFrame,tech::String,node::String,account::String)
    #determine region for this technology and node based on infromation in nodes
    region=nodes[tech,node].region
    #determine regions provided for this tech and this account in the data
    locations_data=unique(tab[(:tech,tech)][(:account,account),:location])
    #check if either specific `node`, `region` or a value for `all` regions is given
    if node in locations_data
        return node
    elseif region in locations_data
        return region
    elseif "all" in locations_data
        return "all"
    else
        return @error "region $region not provided in $(repr(tab))"
    end
end

function load_cep_data_costs(data_path::String, techs::OptVariable, nodes::OptVariable)
    tab=CSV.read(joinpath(data_path,"costs.csv"),allowmissing=:none)
    check_column(tab,[:tech, :location, :year, :account])
    impacts=String.(names(tab)[findfirst(names(tab).==:account)+1:end])
    #Create empty OptVariable
    costs=OptVariable{Number}(undef, axes(techs,"tech"), axes(nodes,"node"), unique(tab[:year]), ["cap_fix", "var"], impacts; type="fv", axes_names=["tech", "node", "year", "account", "impact"])
    for tech in axes(costs,"tech")
        for node in axes(costs,"node")
            for year in axes(costs,"year")
                for impact in axes(costs, "impact")
                    #Addition of capacity costs and fix maintanance cost - For numerical benefit in solving
                    account="cap_fix"
                        cap_location=get_location_data(nodes,tab,tech,node,"cap")
                        total_cap_cost=tab[(:tech,tech)][(:location,cap_location)][(:account,"cap")][(:year,year),Symbol(impact)][1]
                        #First impact shall always be currency - Currency of capacity cost is annulized with annuityfactor
                        if impact==axes(costs,"impact")[1]
                            annulized_cap_cost=round(total_cap_cost*techs[tech].annuityfactor;sigdigits=9)
                        else #Emissions of capacity cost are annulized with total lifetime
                            annulized_cap_cost=round(total_cap_cost/techs[tech].lifetime;sigdigits=9)
                        end
                        fix_location=get_location_data(nodes,tab,tech,node,"fix")
                        fix_cost=tab[(:tech,tech)][(:location,fix_location)][(:account,"fix")][(:year,year),Symbol(impact)][1]
                        costs[tech,node,year,account,impact]=annulized_cap_cost+fix_cost
                    #Variable cost is seperate
                    account="var"
                        var_location=get_location_data(nodes,tab,tech,node,account)
                        var_cost=tab[(:tech,tech)][(:location,fix_location)][(:account,account)][(:year,year),Symbol(impact)][1]
                        costs[tech,node,year,account,impact]=var_cost
                end
            end
        end
    end
    return costs
end

"""
    load_cep_data(region::String)
Loading from .csv files in a the folder ../ClustForOpt/data/CEP/{region}/
Follow instructions for the CSV-Files:
-`region::String`: name of state or region data belongs to
-`costs::OptVariable`: costs[tech,node,year,account,impact] - annulized costs [USD in USD/MW_el, CO2 in kg-CO₂-eq./MW_el]`
-`techs::OptVariable`: techs[tech] - OptDataCEPTech -
-`nodes::OptVariable`: nodes[tech,node] - OptDataCEPNode
-`lines::OptVarible`: lines[tech,line] - OptDataCEPLine
for regions:
- `"GER_1"`: Germany 1 node
- `"GER_18"`: Germany 18 nodes
- `"CA_1"`: California 1 node
- `"CA_14"`: California 14 nodes
- `"TX_1"`: Texas 1 node
"""
function load_cep_data(region::String)
  data_path=normpath(joinpath(dirname(@__FILE__),"..","..","data","CEP",region))
  techs=load_cep_data_techs(data_path)
  nodes=load_cep_data_nodes(data_path, techs)
  lines=load_cep_data_lines(data_path, techs)
  costs=load_cep_data_costs(data_path, techs, nodes)
  return OptDataCEP(region,costs,techs,nodes,lines)
end #load_pricedata

#= Interpolation
"""
    get_number_interpolation(numbers_data::Array{Number,1}, number::Number)
find the neighboring values to do an interpolation of `number` in `numbers_data`
if `number` has no higher or lower neighbor, return the closest neighbor twice
"""
function get_number_interpolation(numbers_data::Array, number::Number)
    #Find numbers being greater and lower than the current numb
    numbers_g=numbers_data[numbers_data.>=number]
    numbers_l=numbers_data[numbers_data.<=number]
    #Create numbers for interpolation
    number_int=Tuple()
    number_int[1]= isempty(numbers_l) ? minimum(numbers_g) : maximum(numbers_l)
    number_int[2]= isempty(numbers_g) ? maximum(numbers_l) : minimum(numbers_g)
    return number_int
end

function get_interpolation(tab::DataFrame,col_val_ind::Tuple{Symbol,Number},colon_ind::Symbol)
    col_int=col_val_ind[1]
    val_int=col_val_ind[2]
    neighbors_int=get_number_interpolation(tab[col_int],val_int)
    if neighbors_int[1]==neighbors_int[2]
        return tab[(col_int,neighbors_int[1]),colon_ind][1]
    else
        #interpolation
        res_1=tab[(col_int,neighbors_int[1]),colon_ind]
        res_2=tab[(col_int,neighbors_int[2]),colon_ind]
        return res_1+(res_2-res_1)*(val_int-neighbors_int[1])/(neighbors_int[2]-neighbors_int[1])
    end
end
=#
