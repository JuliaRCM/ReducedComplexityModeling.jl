include("../test/Problems.jl")
using ReducedComplexityModeling:POD,reduce!,compose


begin 
    # Lorenz problem with POD

    # Reduced Basis Model Pipeline
    #------------------------------------------------------------------------------
    
    # 1. Get data 
    prob,sol = lorenz_problem() 
    data = GeometricIntegratorData(sol)
    
    # 2. Define a model with an appropriate algorithm.
    ## TODO : Extend the algorithm struct to carry its parameters.
    k=3
    alg = POD()
    model = ReducedBasisModel(alg,data.snapshot)
    
    # This falls into the learn function.
    reduce!(model,k,alg)
    red_prob = compose(prob,model)
    red_sol = integrate(red_prob, ExplicitEuler())
    psol = project(red_sol,model)
    
    #------------------------------------------------------------------------------


    # Visualization and Shennanigans
    using Plots
    atemp = 1:k
    display(plot(red_sol.q,vars=(1,2),title="Reduced Basis")) 
    display(plot(psol[1,:],psol[2,:],psol[3,:],title="Remade"))
    display(plot(sol.q,vars=(1,2,3),title="Original"))
end 


# Heat Equation. Solver first. Then use the Reduced basis.
