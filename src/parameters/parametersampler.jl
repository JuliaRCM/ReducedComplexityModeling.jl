"""

"""
abstract type ParameterSampler end

"""
    sample(sampler, parameters::NamedTuple)
    sample(sampler, parameters::Parameter...)

Draws samples of `parameters` with `sampler` and returns them as a `Table` with one column per
parameter. The column names are the keys of `parameters`, which must equal the parameter names.
They are part of the type of a `NamedTuple`, so the first form infers a concrete `Table`. The
second form builds the `NamedTuple` from the parameter names at run time and does not infer.

A sampler implements `_columns(sampler, parameters::Tuple)`, which returns one sample vector per
parameter.
"""
function sample(ps::ParameterSampler, parameters::NamedTuple)
    @assert keys(parameters) == map(p -> p.name, values(parameters))
    Table(NamedTuple{keys(parameters)}(_columns(ps, values(parameters))))
end

function sample(ps::ParameterSampler, parameters::Vararg{Parameter})
    sample(ps, NamedTuple(parameters...))
end

"""

"""
struct CartesianParameterSampler <: ParameterSampler end

function _columns(::CartesianParameterSampler, parameters::NTuple{N, Parameter}) where {N}
    # make sure all parameters have a sample vector
    for p in parameters
        @assert hassamples(p)
    end

    # all parameter index combinations
    inds = vec(CartesianIndices(map(length, parameters)))

    map((p, i) -> [p.samples[I[i]] for I in inds], parameters, ntuple(identity, Val(N)))
end

# map `u ∈ [0,1]` onto the interval `[minimum(p), maximum(p)]` of parameter `p`
_scale(p::Parameter, u) = p.minimum + (p.maximum - p.minimum) * u

"""
    RandomParameterSampler(n, rng = Random.default_rng())

Draws `n` points uniformly at random from the box spanned by the `minimum` and `maximum` of
each parameter. The samples stored in a `Parameter` are ignored. The samples of a parameter
with element type `DT` have type `float(DT)`, so an integer parameter gets `Float64` samples.

The draws come from `rng`, parameter by parameter in the order the parameters are passed, so a
sampler built with a seeded generator, e.g. `RandomParameterSampler(n, Random.Xoshiro(42))`,
reproduces the same samples exactly. The generator advances with each call to `sample`.
"""
struct RandomParameterSampler{RNG <: Random.AbstractRNG} <: ParameterSampler
    n::Int
    rng::RNG

    function RandomParameterSampler(
            n::Integer, rng::RNG = Random.default_rng()) where {RNG <: Random.AbstractRNG}
        @assert n > 0
        new{RNG}(n, rng)
    end
end

function _columns(ps::RandomParameterSampler, parameters::Tuple{Vararg{Parameter}})
    map(parameters) do p
        u = rand(ps.rng, float(typeof(p.minimum)), ps.n)
        u .= _scale.(Ref(p), u)
    end
end

# the first `n` prime numbers
function _primes(n::Int)
    primes = Int[]
    k = 1
    while length(primes) < n
        k += 1
        all(p -> k % p ≠ 0, primes) && push!(primes, k)
    end
    return primes
end

# radical inverse of `i` in base `b`: the base-`b` digits of `i` mirrored about the radix point
function _radical_inverse(::Type{T}, i::Int, b::Int) where {T}
    r = zero(T)
    f = one(T) / b
    while i > 0
        r += f * (i % b)
        i ÷= b
        f /= b
    end
    return r
end

"""
    QuasiRandomParameterSampler(n)

Draws the first `n` points of the Halton sequence, scaled to the box spanned by the `minimum`
and `maximum` of each parameter. The `j`-th parameter uses the `j`-th prime as its base, and
the sequence starts at index one, so the corner `minimum` is not a sample. The samples stored
in a `Parameter` are ignored. The samples of a parameter with element type `DT` have type
`float(DT)`, so an integer parameter gets `Float64` samples.

The points are deterministic and fill the box more evenly than random draws. The Halton
sequence degrades for many parameters, as the bases grow and neighbouring dimensions correlate.
"""
struct QuasiRandomParameterSampler <: ParameterSampler
    n::Int

    function QuasiRandomParameterSampler(n::Integer)
        @assert n > 0
        new(n)
    end
end

function _columns(
        ps::QuasiRandomParameterSampler, parameters::NTuple{N, Parameter}) where {N}
    bases = _primes(N)
    map(parameters, ntuple(j -> bases[j], Val(N))) do p, b
        _scale.(Ref(p), _radical_inverse.(float(typeof(p.minimum)), 1:(ps.n), b))
    end
end
