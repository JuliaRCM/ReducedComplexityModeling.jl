
import Base: collect, eachindex, getindex, length, ndims, size

"""
ParameterSpace collects all parameters of a system as well as samples in the parameter space.
"""
struct ParameterSpace{PT <: NamedTuple, ST <: Table}
    parameters::PT
    samples::ST

    function ParameterSpace(parameters::PT, samples::ST) where {PT, ST}
        # for s in samples
        #     @assert length(parameters) == length(s)
        # end
        new{PT, ST}(parameters, samples)
    end
end

function ParameterSpace(sampler::ParameterSampler, parameters::Vararg{Parameter})
    ParameterSpace(NamedTuple(parameters...), sample(sampler, parameters...))
end

function ParameterSpace(parameters::Vararg{Parameter})
    ParameterSpace(CartesianParameterSampler(), parameters...)
end

function ParameterSpace(parameters::NamedTuple)
    ParameterSpace(values(parameters)...)
end

function Base.:(==)(ps1::ParameterSpace, ps2::ParameterSpace)
    (
        ps1.parameters == ps2.parameters
        && ps1.samples == ps2.samples)
end

function (ps::ParameterSpace)(i::Union{Int, CartesianIndex})
    NamedTuple{keys(ps.parameters)}(ps.samples[i])
end

Base.collect(ps::ParameterSpace) = collect(ps.samples)
Base.eachindex(ps::ParameterSpace) = eachindex(ps.samples)
Base.length(ps::ParameterSpace) = length(ps.samples)
Base.ndims(ps::ParameterSpace) = length(ps.parameters)
Base.size(ps::ParameterSpace) = (length(ps.samples), length(ps.parameters))
Base.size(ps::ParameterSpace, d) = size(ps)[d]

@inline Base.@propagate_inbounds Base.getindex(ps::ParameterSpace, args...) = getindex(ps.samples, args...)

function ParameterSpace(h5::H5DataStore, path::AbstractString = "/")
    group = h5[path]
    samps = group["samples"]
    sinds = Symbol.(keys(samps))
    svals = (read(samps[key]) for key in keys(samps))
    samples = NamedTuple{Tuple(sinds)}(Tuple(svals))

    pgroup = group["parameters"]
    params = NamedTuple{Symbol.(Tuple(keys(pgroup)))}(h5load(Parameter, pgroup, path = key)
    for key in keys(pgroup))

    ParameterSpace(params, Table(; samples...))
end

function ParameterSpace(fpath::AbstractString, path::AbstractString = "/")
    h5open(fpath, "r") do file
        ParameterSpace(file, path)
    end
end

"""
    h5save(h5::H5DataStore, ps::ParameterSpace; path = "/")
    h5save(h5::H5DataStore, param::Parameter; path = string(param.name))
    h5save(fpath::AbstractString, data, args...; mode = "w", kwargs...)

Write `ps` or `param` to the group `path` of `h5`. A [`ParameterSpace`](@ref) writes one dataset
per parameter to the subgroup `samples`, and each of its parameters to the subgroup `parameters`.
A [`Parameter`](@ref) writes the datasets `minimum`, `maximum` and, if it has samples, `samples`.
With a file path, open the file `fpath` in `mode` and write `data` to it. [`h5load`](@ref) reads
the data back.

```jldoctest
julia> ps = ParameterSpace(Parameter(:μ, 0.0, 1.0, 3), Parameter(:ν, 1.0, 2.0, 2));

julia> file = joinpath(mktempdir(), "parameterspace.h5");

julia> h5save(file, ps);

julia> h5load(ParameterSpace, file) == ps
true
```
"""
function h5save(h5::H5DataStore, ps::ParameterSpace; path::AbstractString = "/")
    cols = columns(ps.samples)
    g = _create_group(h5, path)
    s = _create_group(g, "samples")
    for key in keys(cols)
        s[string(key)] = cols[key]
    end

    p = _create_group(g, "parameters")
    for param in ps.parameters
        h5save(p, param; path = string(param.name))
    end
end

"""
    h5load(ParameterSpace, h5::H5DataStore; path = "/")
    h5load(Parameter, h5::H5DataStore; path = "/")
    h5load(T::Type, fpath::AbstractString, args...; mode = "r", kwargs...)

Read a [`ParameterSpace`](@ref) or a [`Parameter`](@ref) from the group `path` of `h5`, in the
layout that [`h5save`](@ref) writes. A parameter takes the name of its group. With a file path,
open the file `fpath` in `mode` and read a `T` from it.

`h5save` writes a parameter `p` to the group of its name, so read it back with
`path = string(p.name)`:

```jldoctest
julia> p = Parameter(:μ, 0.0, 1.0, 3);

julia> file = joinpath(mktempdir(), "parameter.h5");

julia> h5save(file, p);

julia> h5load(Parameter, file; path = string(p.name)) == p
true
```
"""
function h5load(::Type{ParameterSpace}, h5::H5DataStore; path::AbstractString = "/")
    ParameterSpace(h5, path)
end
