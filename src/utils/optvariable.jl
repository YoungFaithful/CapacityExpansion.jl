#  Copyright 2017, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

# OptVariable is inspired by the AxisArrays package.
# OptVariable can be replaced with AxisArray once integer indices are no
# longer a special case. See discussions at:
# https://github.com/JuliaArrays/AxisArrays.jl/issues/117
# https://github.com/JuliaArrays/AxisArrays.jl/issues/84
function build_lookup(ax)
    d = Dict{eltype(ax),Int}()
    cnt = 1
    for el in ax
        if haskey(d, el)
            error("Repeated index $el. Index sets must have unique elements.")
        end
        d[el] = cnt
        cnt += 1
    end
    d
end

"""
    OptVariable(cep::OptModelCEP, variable::Symbol, type::String)
Constructor for OptVariable taking JuMP Array and type (ov-operational variable or dv-decision variable)
"""
function OptVariable(cep::OptModelCEP,
                     variable::Symbol,
                     type::String,
                     scale::Dict{Symbol,Int};
                     round_sigdigits::Int=8)
  jumparray=value.(cep.model[variable])
  #Get the scaled optvar from model and turn DenseAxisArray and SparseAxisArray into Dense OptVariable
  scaled_optvar=OptVariable(jumparray,type,cep.set)
  #Unscale the data based on the scaling parameters in Dictionary scaleend
  unscaled_data=scaled_optvar.data*scale[variable]
  #Return Optvariable with the unscaled data
  return OptVariable(round.(unscaled_data;sigdigits=round_sigdigits), scaled_optvar.axes... ;axes_names=scaled_optvar.axes_names ,type=scaled_optvar.type)
end

function OptVariable(jumparray::JuMP.Containers.SparseAxisArray,
                    type::String,
                    set::Dict{String,Dict{String,Array}})
    axes_number=length(first(keys(jumparray.data)))
    axes_names=Array{String,1}()
    for axe_number in 1:axes_number
        #Get the unique values in each dimension of the indexing tuple
        v=unique(getfield.(keys(jumparray.data),axe_number))
        push!(axes_names, get_axes_name(set,v))
    end
    #Get the axes for the optVariable
    axs=get_axes(set, axes_names)
    #Create an OptVariable with zeros
    optvar=OptVariable(zeros(length.(axs)...), axs...; axes_names=axes_names, type=type)
    #Fill data from spare jumparray into dense array
    for idx in eachindex(jumparray)
        #Find corresponding index of dense array
        dense_idx=Array{Any,1}()
        for i in 1:length(idx)
            push!(dense_idx,findfirst(optvar.axes[i].==idx[i]))
        end
        #Overwrite the
        optvar.data[dense_idx...] = jumparray[idx]
    end
    return optvar
end

function OptVariable(jumparray::JuMP.Containers.DenseAxisArray,
                    type::String,
                    set::Dict{String,Dict{String,Array}})
    axes_names=Array{String,1}()
    for axe in jumparray.axes
      for (name, val) in set
          for (n,v) in val
            if axe==v
              push!(axes_names, name)
              break
            end
        end
      end
    end
    return OptVariable(jumparray.data, jumparray.axes...; axes_names=axes_names, type=type)
end

"""
    OptVariable(data::Array{T, N}, axes...) where {T, N}

Construct a OptVariable array with the underlying data specified by the `data` array
and the given axes. Exactly `N` axes must be provided, and their lengths must
match `size(data)` in the corresponding dimensions.

# Example
```jldoctest
julia> array = OptVariable([1 2; 3 4], [:a, :b], 2:3)
2-dimensional OptVariable{Int,2,...} with index sets:
    Dimension 1, Symbol[:a, :b]
    Dimension 2, 2:3
And data, a 2×2 Array{Int,2}:
 1  2
 3  4

julia> array[:b, 3]
4
```
"""
function OptVariable(data::Array{T,N}, axs...;axes_names::Array=repeat([""],N), type="") where {T,N}
    @assert length(axs) == N
    return OptVariable(data, axs, build_lookup.(axs), axes_names, type)
end

"""
    OptVariable{T}(undef, axes...) where T

Construct an uninitialized OptVariable with element-type `T` indexed over the
given axes.

# Example
```jldoctest
julia> array = OptVariable{Float}(undef, [:a, :b], 1:2);

julia> fill!(array, 1.0)
2-dimensional OptVariable{Float64,2,...} with index sets:
    Dimension 1, Symbol[:a, :b]
    Dimension 2, 1:2
And data, a 2×2 Array{Float64,2}:
 1.0  1.0
 1.0  1.0

julia> array[:a, 2] = 5.0
5.0

julia> array[:a, 2]
5.0

julia> array
2-dimensional OptVariable{Float64,2,...} with index sets:
    Dimension 1, Symbol[:a, :b]
    Dimension 2, 1:2
And data, a 2×2 Array{Float64,2}:
 1.0  5.0
 1.0  1.0
```
"""
function OptVariable{T}(::UndefInitializer, axs...; axes_names::Array{String,1}=repeat([""],length(axs)), type="") where T
    return construct_undef_array(T, axs; axes_names=axes_names, type=type)
end

function construct_undef_array(::Type{T}, axs::Tuple{Vararg{Any, N}}; axes_names::Array{String,1}, type::String
                               ) where {T, N}
    return OptVariable(Array{T, N}(undef, length.(axs)...), axs...; axes_names=axes_names, type=type)
end

Base.isempty(A::OptVariable) = isempty(A.data)

# TODO: similar

# AbstractArray interface

Base.size(A::OptVariable) = size(A.data)
Base.LinearIndices(A::OptVariable) = error("OptVariable does not support this operation.")
Base.axes(A::OptVariable) = A.axes
Base.axes(A::OptVariable, dims::String) = A.axes[findfirst(A.axes_names.==dims)]
Base.CartesianIndices(a::OptVariable) = CartesianIndices(a.data)

############
# Indexing #
############

Base.isassigned(A::OptVariable{T,N}, idx...) where {T,N} = length(idx) == N && all(t -> haskey(A.lookup[t[1]], t[2]), enumerate(idx))
# For ambiguity
Base.isassigned(A::OptVariable{T,N}, idx::Int...) where {T,N} = length(idx) == N && all(t -> haskey(A.lookup[t[1]], t[2]), enumerate(idx))

Base.eachindex(A::OptVariable) = CartesianIndices(size(A.data))

lookup_index(i, lookup::Dict) = isa(i, Colon) ? Colon() : lookup[i]

# Lisp-y tuple recursion trick to handle indexing in a nice type-
# stable way. The idea here is that `_to_index_tuple(idx, lookup)`
# performs a lookup on the first element of `idx` and `lookup`,
# then recurses using the remaining elements of both tuples.
# The compiler knows the lengths and types of each tuple, so
# all of the types are inferable.
function _to_index_tuple(idx::Tuple, lookup::Tuple)
    tuple(lookup_index(first(idx), first(lookup)),
          _to_index_tuple(Base.tail(idx), Base.tail(lookup))...)
end

# Handle the base case when we have more indices than lookups:
function _to_index_tuple(idx::NTuple{N}, ::NTuple{0}) where {N}
    ntuple(k -> begin
        i = idx[k]
        (i == 1) ? 1 : error("invalid index $i")
    end, Val(N))
end

# Handle the base case when we have fewer indices than lookups:
_to_index_tuple(idx::NTuple{0}, lookup::Tuple) = ()

# Resolve ambiguity with the above two base cases
_to_index_tuple(idx::NTuple{0}, lookup::NTuple{0}) = ()

to_index(A::OptVariable, idx...) = _to_index_tuple(idx, A.lookup)

# Doing `Colon() in idx` is relatively slow because it involves
# a non-unrolled loop through the `idx` tuple which may be of
# varying element type. Another lisp-y recursion trick fixes that
has_colon(idx::Tuple{}) = false
has_colon(idx::Tuple) = isa(first(idx), Colon) || has_colon(Base.tail(idx))

# TODO: better error (or just handle correctly) when user tries to index with a range like a:b
# The only kind of slicing we support is dropping a dimension with colons
function Base.getindex(A::OptVariable, idx...)
    #if has_colon(idx)
    #    OptVariable(A.data[to_index(A,idx...)...], (ax for (i,ax) in enumerate(A.axes) if idx[i] == Colon())...)
    #else
        return A.data[to_index(A,idx...)...]
    #end
end
Base.getindex(A::OptVariable, idx::CartesianIndex) = A.data[idx]

Base.setindex!(A::OptVariable, v, idx...) = A.data[to_index(A,idx...)...] = v
Base.setindex!(A::OptVariable, v, idx::CartesianIndex) = A.data[idx] = v

Base.IndexStyle(::Type{OptVariable{T,N,Ax}}) where {T,N,Ax} = IndexAnyCartesian()

########
# Keys #
########

"""
    OptVariableKey

Structure to hold a OptVariable key when it is viewed as key-value collection.
"""
struct OptVariableKey{T<:Tuple}
    I::T
end
Base.getindex(k::OptVariableKey, args...) = getindex(k.I, args...)

struct OptVariableKeys{T<:Tuple}
    product_iter::Base.Iterators.ProductIterator{T}
end
Base.length(iter::OptVariableKeys) = length(iter.product_iter)
function Base.eltype(iter::OptVariableKeys)
    return OptVariableKey{eltype(iter.product_iter)}
end
function Base.iterate(iter::OptVariableKeys)
    next = iterate(iter.product_iter)
    return next == nothing ? nothing : (OptVariableKey(next[1]), next[2])
end
function Base.iterate(iter::OptVariableKeys, state)
    next = iterate(iter.product_iter, state)
    return next == nothing ? nothing : (OptVariableKey(next[1]), next[2])
end
function Base.keys(a::OptVariable)
    return OptVariableKeys(Base.Iterators.product(a.axes...))
end
Base.getindex(a::OptVariable, k::OptVariableKey) = a[k.I...]

########
# Show #
########

# Adapted printing from Julia's show.jl

# Copyright (c) 2009-2016: Jeff Bezanson, Stefan Karpinski, Viral B. Shah,
# and other contributors:
#
# https://github.com/JuliaLang/julia/contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

function Base.summary(io::IO, A::OptVariable)
    _summary(io, A)
    for (k,ax) in enumerate(A.axes)
        print(io, "    Dimension $k - $(A.axes_names[k]), ")
        show(IOContext(io, :limit=>true), ax)
        println(io)
    end
    print(io, "And data, a ", summary(A.data))
end
_summary(io, A::OptVariable{T,N}) where {T,N} = println(io, "$N-dimensional OptVariable{$T,$N,...} of type $(A.type) with index sets:")

function Base.summary(A::OptVariable)
    io = IOBuffer()
    Base.summary(io, A)
    String(io)
end

if isdefined(Base, :print_array) # 0.7 and later
    Base.print_array(io::IO, X::OptVariable{T,1}) where {T} = Base.print_matrix(io, X.data)
    Base.print_array(io::IO, X::OptVariable{T,2}) where {T} = Base.print_matrix(io, X.data)
end

# n-dimensional arrays
function Base.show_nd(io::IO, a::OptVariable, print_matrix::Function, label_slices::Bool)
    limit::Bool = get(io, :limit, false)
    if isempty(a)
        return
    end
    tailinds = Base.tail(Base.tail(axes(a.data)))
    nd = ndims(a)-2
    for I in CartesianIndices(tailinds)
        idxs = I.I
        if limit
            for i = 1:nd
                ii = idxs[i]
                ind = tailinds[i]
                if length(ind) > 10
                    if ii == ind[4] && all(d->idxs[d]==first(tailinds[d]),1:i-1)
                        for j=i+1:nd
                            szj = size(a.data,j+2)
                            indj = tailinds[j]
                            if szj>10 && first(indj)+2 < idxs[j] <= last(indj)-3
                                @goto skip
                            end
                        end
                        #println(io, idxs)
                        print(io, "...\n\n")
                        @goto skip
                    end
                    if ind[3] < ii <= ind[end-3]
                        @goto skip
                    end
                end
            end
        end
        if label_slices
            print(io, "[:, :, ")
            for i = 1:(nd-1); show(io, a.axes[i+2][idxs[i]]); print(io,", "); end
            show(io, a.axes[end][idxs[end]])
            println(io, "] =")
        end
        slice = view(a.data, axes(a.data,1), axes(a.data,2),
                     idxs...)
        Base.print_matrix(io, slice)
        print(io, idxs == map(last,tailinds) ? "" : "\n\n")
        @label skip
    end
end

function Base.show(io::IO, array::OptVariable)
    summary(io, array)
    isempty(array) && return
    println(io, ":")
    Base.print_array(io, array)
end

###################
# Sparse to Dense #
###################

"""
    get_axes(set::Dict{String,Dict{String,Array}}, axes_names::Array{String,1})


get the axes defined by the `axes_names` from the `set`
"""
function get_axes(set::Dict{String,Dict{String,Array}}, axes_names::Array{String,1})
    axes=Array{Array,1}()
    for axes_name in axes_names
        push!(axes,set[axes_name]["all"])
    end
    return axes
end

"""
    get_axes_name(set::Dict{String,Any},values::Array)

Figure out the set within the dictionary `set`, which has equivalent elements to the provided `values`.
The `set` has to be organized as follows: Each entry `set[set_name]` can either be:
- a set-element itself, which is an Array or UnitRange
- or a dictionary with set-subgroups for this set. The set-subgroup has to have a set element called `set[set_name]["all"]`, which contains an Array or UnitRange containing all values for the set_name
"""
function get_axes_name(set::Dict{String,Dict{String,Array}},values::Array)
    for (k,v) in set
        #Check the group `all` first
        if get_axes_name(v["all"],values)==true
            return k
        end
        #Check the subsets second
        for (kk,vv) in v
            if get_axes_name(vv,values)==true
                return k
            end
        end
    end
    return error("The values $values were not found in set $set")
end

function get_axes_name(set_element::Array,values::Array)
    if sort(set_element)==sort(values)
        return true
    end
end

function get_axes_name(set_element::UnitRange,values::Array)
    if collect(set_element)==sort(values)
        return true
    end
end
