module ReducedComplexityModeling

    using GeometricIntegrators
    using GeometricIntegrators:SolutionODE
    using ReducedBasisMethods
    using GeometricEquations
    using LinearAlgebra
    using GeometricIntegratorsDiffEq:ODESolution,ODEProblem
    using Optim
    using ForwardDiff
    using 

    include("TrainingData/TrainingData.jl")
    include("Models/Models.jl")
    include("TrainingProblem.jl")

    export Array
    export GeometricIntegratorData, GeometricIntegratorEnsembleData
    export Dependent, Independent
    export ReducedBasisModel
    export POD,reduce!,compose
    
    export AutoEncoderModel
end
