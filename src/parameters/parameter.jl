
import Base: collect, getindex, length, maximum, minimum, size, NamedTuple

AbstractSample{DT} = Union{Nothing, AbstractVector{DT}}

_sort(s::Nothing) = s
_sort(s::AbstractVector) = sort(unique(collect(s)))

"""
    Parameter(name, minimum, maximum)
    Parameter(name, minimum, maximum, samples)
    Parameter(name, minimum, maximum, n::Int)
    Parameter(name, samples::AbstractVector)

A named parameter of a system: the bounds `minimum ≤ maximum` and, optionally, a vector of
samples between them. In every form, `name` is a `Symbol` or a string, which is converted to a
`Symbol`.

The bounds have one type `DT`, and the samples have element type `DT`. The samples are stored
sorted and without duplicates. Without samples, `samples` is `nothing`. With a count `n`, the
samples are the points of `LinRange(minimum, maximum, n)`, without duplicates. A point that
rounds outside the bounds, by a few ULPs, is moved onto the nearest bound. Equal bounds and a
positive count give the one sample `minimum`. This works for bounds of a type that `LinRange` keeps, such as a float or a `Rational`; unequal
integer bounds with a count throw a `MethodError`, because their `LinRange` has a float element
type. With only a vector of samples, the bounds are its smallest and largest entry.

`minimum > maximum`, or a sample outside `[minimum, maximum]`, throws an `AssertionError`.
"""
struct Parameter{DT <: Number, ST <: AbstractSample{DT}}
    name::Symbol
    minimum::DT
    maximum::DT
    samples::ST

    function Parameter(name::Union{Symbol, AbstractString}, minimum::DT, maximum::DT,
            samples::ST) where {DT, ST <: AbstractSample{DT}}
        @assert minimum ≤ maximum
        if typeof(samples) <: AbstractVector
            @assert all([minimum ≤ s for s in samples])
            @assert all([maximum ≥ s for s in samples])
        end
        _samples = _sort(samples)
        new{DT, typeof(_samples)}(Symbol(name), minimum, maximum, _samples)
    end
end

function Parameter(name, minimum::DT, maximum::DT) where {DT}
    Parameter(name, minimum, maximum, nothing)
end
function Parameter(name, minimum::DT, maximum::DT, n::Int) where {DT}
    # `LinRange(0.1, 0.1, 6)` holds `0.10000000000000002`, so equal bounds give their one sample.
    # Distinct bounds can also round a point a few ULPs outside: the clamp puts it back.
    samples = minimum == maximum && n ≥ 0 ? fill(minimum, min(n, 1)) :
              clamp.(LinRange(minimum, maximum, n), minimum, maximum)
    Parameter(name, minimum, maximum, samples)
end
function Parameter(name, samples::AbstractVector)
    Parameter(name, minimum(samples), maximum(samples), samples)
end

function Base.hash(p::Parameter, h::UInt)
    hash(p.name, hash(p.minimum, hash(p.maximum, hash(p.samples, h))))
end

function Base.:(==)(p1::Parameter, p2::Parameter)
    (
        p1.name == p2.name
        && p1.minimum == p2.minimum
        && p1.maximum == p2.maximum
        && p1.samples == p2.samples)
end

function Base.show(io::IO, ::MIME"text/plain", p::Parameter)
    println(io, "Parameter $(p.name) with ")
    println(io, "   minimum = ", p.minimum)
    println(io, "   maximum = ", p.maximum)
    println(io, "   samples = ")
    show(io, p.samples)
end

const ParameterWithSamples = Parameter{DT, ST} where {DT, ST <: AbstractVector}
const ParameterWithoutSamples = Parameter{DT, ST} where {DT, ST <: Nothing}

Base.collect(p::Parameter) = p.samples
Base.maximum(p::Parameter) = p.maximum
Base.minimum(p::Parameter) = p.minimum

Base.length(p::ParameterWithSamples) = length(p.samples)
Base.length(p::ParameterWithoutSamples) = 0

Base.size(p::ParameterWithSamples) = size(p.samples)
Base.size(p::ParameterWithoutSamples) = (0,)

"""
    hassamples(p::Parameter)

Whether the parameter `p` has a non-empty vector of samples.
"""
hassamples(p::ParameterWithSamples) = length(p.samples) > 0
hassamples(p::ParameterWithoutSamples) = false

@inline Base.@propagate_inbounds Base.getindex(p::ParameterWithSamples, i) = p.samples[i]
@inline Base.@propagate_inbounds Base.getindex(p::ParameterWithoutSamples,
    i) = error("Parameter $(p.name) indexed with $(i) but has no samples.")
@inline Base.@propagate_inbounds Base.getindex(p::ParameterWithSamples, ::Colon) = p.samples
@inline Base.@propagate_inbounds Base.getindex(
    p::ParameterWithoutSamples, ::Colon) = error("Parameter $(p.name) has no samples.")

function Base.NamedTuple(parameters::Vararg{Parameter})
    names = Tuple(p.name for p in parameters)
    NamedTuple{names}(parameters)
end

function Parameter(h5::H5DataStore, path::AbstractString = "/")
    g = h5[path]
    name = _name(g)

    minimum = read(g["minimum"])
    maximum = read(g["maximum"])
    samples = haskey(g, "samples") ? read(g["samples"]) : nothing

    Parameter(name, minimum, maximum, samples)
end

function h5save(h5::H5DataStore, param::Parameter; path::AbstractString = string(param.name))
    g = _create_group(h5, path)
    g["minimum"] = param.minimum
    g["maximum"] = param.maximum
    # a parameter without samples stores no `samples` dataset, as HDF5 cannot write `nothing`
    isnothing(param.samples) || (g["samples"] = param.samples)
end

function h5load(::Type{Parameter}, h5::H5DataStore; path::AbstractString = "/")
    Parameter(h5, path)
end
