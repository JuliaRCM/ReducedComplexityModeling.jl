struct TrainingProblem
    data::TrainingData
    model::AbstractModel
end

"""
    reduce!(prob)

Uses data from high-fidelity simulations/experiments
and reduces them to a latent space representation of the problem.
"""
function reduce!(prob::TrainingProblem)

end

"""
    resolve(prob,integrator)

Performs forward-time to the `problem` using the numerical integrator
of choice specified by `integrator`.
"""
function resolve(prob::TrainingProblem,integrator)

end
