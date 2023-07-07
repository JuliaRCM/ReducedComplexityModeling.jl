using GeometricIntegrators

function lorenz_problem()
    function lorenz(du,t,u,p)
        du[1] = 10.0(u[2]-u[1])
        du[2] = u[1]*(28.0-u[3]) - u[2]
        du[3] = u[1]*u[2] - (8/3)*u[3]
    end 
    u0 = [1.0, 0.0, 0.0]
    tstep = 0.01
    tspan = (0.0, 100.0)
    prob = ODEProblem(lorenz, tspan, tstep, u0)
    sol = integrate(prob, ExplicitEuler())
    prob, sol
end 

# Implicitly assume that all PDEs are solved in 2 dimensions.
function heat_equation()

end 

function elastic_wave_equations()

end
