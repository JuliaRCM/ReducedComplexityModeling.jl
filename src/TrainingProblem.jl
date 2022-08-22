struct TrainingProblem
    data::TrainingData
    model::AbstractModel

    function TrainingProblem(data::TrainingData,model::AbstractModel)

    end 
end

"""
    learn(prob)

Uses data from high-fidelity simulations/experiments
and learns the latent representation of the problem.
"""
function learn(prob::TrainingProblem)

end