"""
    TrainingProblem(data, residual, parameters)

A training problem: the data, the residual to minimise over the parameters, and the samples the
fit starts from.

`data` is a [`TrainingData`](@ref), `parameters` a `ParameterSpace`, and `residual` a callable

    residual(data::TrainingData, θ::NamedTuple) -> AbstractVector

that returns the residual vector of the model with parameters `θ`. The parameters come last, as
in the vector fields of a `GeometricEquations` problem. `θ` has the keys and the order of
`parameters.parameters`; its element type is generic, so the residual sees `ForwardDiff.Dual`
entries while [`train`](@ref) differentiates it.
"""
struct TrainingProblem{TD <: TrainingData, RT, PT <: ParameterSpace}
    data::TD
    residual::RT
    parameters::PT
end

"""
    train(problem::TrainingProblem, method::Optim.FirstOrderOptimizer)

Fit the parameters of `problem.data` by minimising `sum(abs2, problem.residual(data, θ))` over
`problem.parameters`, with the first-order `Optim` method `method`, e.g. `LBFGS()`.

The samples of the parameter space are **starting points, not bounds**: the fit starts from the
sample whose loss is finite and smallest and may leave the box the samples span, so `train`
returns the fitted parameters of the model and not a search over the box.

The result is a `NamedTuple` with the keys of `problem.parameters.parameters` and the element
type of the samples. Convergence is `Optim`'s flag: an `ErrorException` is thrown when `Optim`
reports that it did not converge, and a start at a stationary point ends the fit there. An
exception raised by `residual` propagates to the caller.
"""
function train(problem::TrainingProblem, method::Optim.FirstOrderOptimizer)
    residual = problem.residual
    data = problem.data
    parameters = problem.parameters

    T = float(promote_type(map(eltype, values(columns(parameters.samples)))...))

    loss(θ::NamedTuple) = sum(abs2, residual(data, θ))

    index = nothing
    ℓmin = zero(T)
    for i in eachindex(parameters)
        ℓ = loss(parameters(i))
        if isfinite(ℓ) && (index === nothing || ℓ < ℓmin)
            ℓmin = ℓ
            index = i
        end
    end
    index === nothing && throw(ArgumentError(
        "no sample of the parameter space gives a finite loss, so `train` has no starting point"))

    result_type = NamedTuple{keys(parameters.parameters)}
    N = length(parameters.parameters)
    x₀ = collect(T, values(parameters(index)))

    merit(x) = loss(result_type(ntuple(i -> x[i], Val(N))))
    gradient!(G, x) = ForwardDiff.gradient!(G, merit, x)

    result = Optim.optimize(merit, gradient!, x₀, method,
        Optim.Options(g_abstol = zero(T), x_reltol = eps(T)))
    Optim.converged(result) || error("`train` did not converge: $result")

    return result_type(ntuple(i -> Optim.minimizer(result)[i], Val(N)))
end

"""
    train!(model, problem::TrainingProblem, method)

Train `model` in place on `problem` and return the loss history.

The in-place companion of [`train`](@ref): where `train` builds a model from the data and returns
the fitted parameters, `train!` updates a model the caller already holds and returns the loss at
each step of the fit, so that a caller can watch the fit. `ReducedComplexityModeling` defines no
method of it; a package that owns a model provides one.
"""
function train! end
