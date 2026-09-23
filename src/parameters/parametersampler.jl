"""

"""
abstract type ParameterSampler end

"""

"""
function sample(ps::ParameterSampler, parameters::NamedTuple)
    sample(ps, values(parameters)...)
end

"""

"""
struct CartesianParameterSampler <: ParameterSampler end

function sample(::CartesianParameterSampler, parameters::Vararg{Parameter, N}) where {N}
    # make sure all parameters have a sample vector
    for p in parameters
        @assert hassamples(p)
    end

    # get all parameter index combinations
    inds = CartesianIndices(zeros([length(p) for p in parameters]...))[:]

    # generate sample matrix
    smps = [parameters[i].samples[inds[j][i]] for j in eachindex(inds), i in 1:N]

    sinds = Tuple(p.name for p in parameters)
    svals = Tuple(smps[:, j] for j in axes(smps, 2))

    Table(; NamedTuple{sinds}(svals)...)
end

# map `u ∈ [0,1]` onto the interval `[minimum(p), maximum(p)]` of parameter `p`
_scale(p::Parameter, u) = p.minimum + (p.maximum - p.minimum) * u

# build the sample table from one vector of samples per parameter
function _sample_table(parameters::Tuple{Vararg{Parameter}}, columns::Tuple)
    Table(NamedTuple{Tuple(p.name for p in parameters)}(columns))
end

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

function sample(ps::RandomParameterSampler, parameters::Vararg{Parameter, N}) where {N}
    columns = map(parameters) do p
        u = rand(ps.rng, float(typeof(p.minimum)), ps.n)
        u .= _scale.(Ref(p), u)
    end
    _sample_table(parameters, columns)
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

function sample(ps::QuasiRandomParameterSampler, parameters::Vararg{Parameter, N}) where {N}
    bases = _primes(N)
    columns = map(parameters, ntuple(j -> bases[j], Val(N))) do p, b
        _scale.(Ref(p), _radical_inverse.(float(typeof(p.minimum)), 1:(ps.n), b))
    end
    _sample_table(parameters, columns)
end
