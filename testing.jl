include(joinpath("src","CapacityExpansion_development.jl"))
using Clp
## LOAD DATA ##
state="GER_1" # or "GER_18" or "CA_1" or "TX_1"
years=[2016] #2016 works for GER_1 and CA_1, GER_1 can also be used with 2006 to 2016 and, GER_18 is 2015 TX_1 is 2008
# laod ts-data
ts_input_data = load_timeseries_data_provided(state;T=24, years=years) #CEP
# load cep-data
cep_data = load_cep_data_provided(state)
## CLUSTERING ##
# run aggregation with kmeans
ts_clust_data = run_clust(ts_input_data;method="hierarchical",representation="centroid",n_init=1,n_clust=5) # default k-means make sure that n_init is high enough otherwise the results could be crap and drive you crazy

## OPTIMIZATION EXAMPLES##
# select optimizer
optimizer=Clp.Optimizer

# tweak the CO2 level
cep = run_opt(ts_clust_data.clust_data,cep_data,optimizer;limit=Dict{String,Number}("CO2/electricity"=>50)) #generally values between 1250 and 10 are interesting

jumparray=value.(cep.model[:GEN])
jumparray2=value.(cep.model[:COST])
typeof(jumparray.data)
typeof(jumparray.data)==Dict
set=cep.set
isdefined(jumparray2, :axes)
axes_number=length(first(keys(jumparray.data)))
for 1:axes_number
v=unique(getfield.(keys(jumparray.data),4))

get_axe(set,v)

"""
    get_axe(set::Dict{String,Any},values::Array)

Figure out the set within the dictionary `set`, which has equivalent elements to the provided `values`.
The `set` has to be organized as follows: Each entry `set[set_name]` can either be:
- a set-element itself, which is an Array or UnitRange
- or a dictionary with set-subgroups for this set. The set-subgroup has to have a set element called `set[set_name]["all"]`, which contains an Array or UnitRange containing all values for the set_name
"""
function get_axe(set::Dict{String,Any},values::Array)
    for (k,v) in set
        if get_axe(v,values)==true
            return k
        end
    end
end

function get_axe(set_group::Dict{String,Array},values::Array)
    return get_axe(set_group["all"],values)
end

function get_axe(set_element::Array,values::Array)
    if sort(set_element)==sort(values)
        return true
    end
end

function get_axe(set_element::UnitRange,values::Array)
    if collect(set_element)==sort(values)
        return true
    end
end

OptVariable(jumparray,"ter")
