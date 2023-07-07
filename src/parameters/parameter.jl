
import Base: collect, getindex, length, maximum, minimum, size, NamedTuple


AbstractSample{DT} = Union{Nothing, AbstractVector{DT}}

_sort(s::Nothing) = s
_sort(s::AbstractVector) = sort(unique(collect(s)))


"""

"""
struct Parameter{DT <: Number, ST <: AbstractSample{DT}}
    name::Symbol
    minimum::DT
    maximum::DT
    samples::ST

    function Parameter(name::Symbol, minimum::DT, maximum::DT, samples::ST) where {DT, ST <: AbstractSample{DT}}
        @assert minimum ≤ maximum
        if typeof(samples) <: AbstractVector
            @assert all([minimum ≤ s for s in samples])
            @assert all([maximum ≥ s for s in samples])
        end
        _samples = _sort(samples)
        new{DT, typeof(_samples)}(name, minimum, maximum, _samples)
    end
end

Parameter(name::AbstractString, minimum, maximum, samples) = Parameter(Symbol(name), minimum, maximum, samples)
Parameter(name, minimum::DT, maximum::DT) where {DT} = Parameter(name, minimum, maximum, nothing)
Parameter(name, minimum::DT, maximum::DT, n::Int) where {DT} = Parameter(name, minimum, maximum, LinRange(minimum, maximum, n))
Parameter(name, samples::AbstractVector) = Parameter(name, minimum(samples), maximum(samples), samples)

Base.hash(p::Parameter, h::UInt) = hash(p.name, hash(p.minimum, hash(p.maximum, hash(p.samples, h))))

Base.:(==)(p1::Parameter, p2::Parameter) = (
                                p1.name    == p2.name
                             && p1.minimum == p2.minimum
                             && p1.maximum == p2.maximum
                             && p1.samples == p2.samples)

function show(io::IO, p::Parameter)
    println(io, "Parameter $(p.name) with ")
    println(io, "   minimum = ", p.minimum)
    println(io, "   maximum = ", p.maximum)
    println(io, "   samples = ")
    show(io, p.samples)
end

const ParameterWithSamples = Parameter{DT,ST} where {DT, ST <: AbstractVector}
const ParameterWithoutSamples = Parameter{DT,ST} where {DT, ST <: Nothing}

Base.collect(p::Parameter) = p.samples
Base.maximum(p::Parameter) = p.maximum
Base.minimum(p::Parameter) = p.minimum

Base.length(p::ParameterWithSamples) = length(p.samples)
Base.length(p::ParameterWithoutSamples) = 0

Base.size(p::ParameterWithSamples) = size(p.samples)
Base.size(p::ParameterWithoutSamples) = (0,)

hassamples(p::ParameterWithSamples) = length(p.samples) > 0
hassamples(p::ParameterWithoutSamples) = false

@inline Base.@propagate_inbounds Base.getindex(p::ParameterWithSamples, i) = p.samples[i]
@inline Base.@propagate_inbounds Base.getindex(p::ParameterWithoutSamples, i) = error("Parameter $(p.name) indexed with $(i) but has no samples.")
@inline Base.@propagate_inbounds Base.getindex(p::ParameterWithSamples, ::Colon) = p.samples
@inline Base.@propagate_inbounds Base.getindex(p::ParameterWithoutSamples, ::Colon) = error("Parameter $(p.name) has no samples.")

function Base.NamedTuple(parameters::Vararg{Parameter{DT}}) where {DT}
    names = Tuple(p.name for p in parameters)
    NamedTuple{names}(parameters)
end

function Parameter(h5::H5DataStore, path::AbstractString = "/")
    g = h5[path]
    name = _name(g)

    minimum = read(g["minimum"])
    maximum = read(g["maximum"])
    samples = read(g["samples"])

    Parameter(name, minimum, maximum, samples)
end

function h5save(h5::H5DataStore, param::Parameter; path::AbstractString = string(param.name))
    g = _create_group(h5, path)
    g["minimum"] = param.minimum
    g["maximum"] = param.maximum
    g["samples"] = param.samples
end

function h5load(::Type{Parameter}, h5::H5DataStore; path::AbstractString = "/")
    Parameter(h5, path)
end
