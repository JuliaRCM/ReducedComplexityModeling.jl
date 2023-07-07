module ReducedComplexityModeling

    using ForwardDiff
    using GeometricEquations
    using GeometricSolutions
    using LinearAlgebra
    using Optim

    include("TrainingData/TrainingData.jl")
    include("Models/Models.jl")
    include("TrainingProblem.jl")

    export Array
    export GeometricIntegratorData, GeometricIntegratorEnsembleData
    export Dependent, Independent
    export ReducedBasisModel
    export POD,reduce!,project,compose
    
    export AutoEncoderModel
end
