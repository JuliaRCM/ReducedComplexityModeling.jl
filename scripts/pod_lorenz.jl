# Proper orthogonal decomposition of the Lorenz system: the full solution, the solution of the
# reduced problem and its projection back to the full space.
#
#     julia --project=scripts -e 'using Pkg; Pkg.instantiate()'
#     julia --project=scripts scripts/pod_lorenz.jl [--results-dir DIR]
#
# `DIR` defaults to `results`. The script writes `pod_lorenz_original.png`,
# `pod_lorenz_reduced.png` and `pod_lorenz_remade.png` there.

using CairoMakie
using GeometricIntegrators
using GeometricProblems.LorenzAttractor
using ReducedComplexityModeling
using ReducedComplexityModeling: POD, reduce!, compose

function results_dir(args)
    i = findfirst(==("--results-dir"), args)
    i === nothing || i < lastindex(args) ||
        throw(ArgumentError("--results-dir needs a directory"))
    dir = i === nothing ? "results" : args[i + 1]
    mkpath(dir)
end

dir = results_dir(ARGS)

# The same setup as test/integration/pod_lorenz.jl: a short time span, because on (0, 100) the
# Lorenz system is chaotic and grows the round-off of the reduced integration to O(1).
prob = LorenzAttractor.odeproblem([1.0, 0.0, 0.0]; timespan = (0.0, 1.0))
sol = integrate(prob, ExplicitEuler())
data = GeometricIntegratorData(sol)

# two of the three modes: the reduced problem has two components, and the figure shows both
k = 2
alg = POD()
model = ReducedBasisModel(alg, data.snapshot)
reduce!(model, k, alg)
red_sol = integrate(compose(prob, model), ExplicitEuler())
psol = project(red_sol, model)

save(joinpath(dir, "pod_lorenz_original.png"), LorenzAttractor.plot_phase_portrait(sol))

fig = Figure(size = (600, 600))
ax = Axis(fig[1, 1]; title = "Reduced basis", xlabel = "u₁", ylabel = "u₂")
lines!(ax, [u[1] for u in red_sol.q], [u[2] for u in red_sol.q])
save(joinpath(dir, "pod_lorenz_reduced.png"), fig)

fig = Figure(size = (600, 600))
ax = Axis3(fig[1, 1]; title = "Remade", xlabel = "x", ylabel = "y", zlabel = "z")
lines!(ax, psol[1, :], psol[2, :], psol[3, :])
save(joinpath(dir, "pod_lorenz_remade.png"), fig)
