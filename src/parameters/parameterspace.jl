
import Base: collect, eachindex, getindex, length, ndims, size

"""
ParameterSpace collects all parameters of a system as well as samples in the parameter space.
"""
struct ParameterSpace{PT <: NamedTuple, ST <: Table}
    parameters::PT
    samples::ST

    function ParameterSpace(parameters::PT, samples::ST) where {PT,ST}
        # for s in samples
        #     @assert length(parameters) == length(s)
        # end
        new{PT,ST}(parameters, samples)
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

Base.:(==)(ps1::ParameterSpace, ps2::ParameterSpace) = (
                        ps1.parameters == ps2.parameters
                     && ps1.samples    == ps2.samples)


(ps::ParameterSpace)(i::Union{Int,CartesianIndex}) = NamedTuple{keys(ps.parameters)}(ps.samples[i])


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
    params = NamedTuple{Symbol.(Tuple(keys(pgroup)))}(h5load(Parameter, pgroup, path = key) for key in keys(pgroup))

    ParameterSpace(params, Table(; samples...))
end

function ParameterSpace(fpath::AbstractString, path::AbstractString = "/")
    h5open(fpath, "r") do file
        ParameterSpace(file, path)
    end
end

"""
save ParameterSpace
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
Load ParameterSpace
"""
function h5load(::Type{ParameterSpace}, h5::H5DataStore; path::AbstractString = "/")
    ParameterSpace(h5, path)
end
