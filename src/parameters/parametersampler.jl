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


function sample(::CartesianParameterSampler, parameters::Vararg{Parameter,N}) where {N}
    # make sure all parameters have a sample vector
    for p in parameters
        @assert hassamples(p)
    end

    # get all parameter index combinations
    inds = CartesianIndices(zeros([length(p) for p in parameters]...))[:]

    # generate sample matrix
    smps = [parameters[i].samples[inds[j][i]] for j in eachindex(inds), i in 1:N]

    sinds = Tuple(p.name for p in parameters)
    svals = Tuple(smps[:,j] for j in axes(smps,2))

    Table(; NamedTuple{sinds}(svals)...)
end
