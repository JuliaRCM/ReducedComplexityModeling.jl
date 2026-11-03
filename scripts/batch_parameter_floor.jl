# The minibatches that `Batch` cuts from a tensor, and the mean of a per-sample quantity over one
# minibatch against the same mean over a uniform partition of the pairs (time, parameter).
#
#     julia --startup-file=no --project=. scripts/batch_parameter_floor.jl
#
# The per-sample quantity stands for one component of a per-sample gradient, and its mean over the
# epoch for that component of the full gradient. Every `@assert` compares the loader with a count
# or a closed form that does not read the loader, so the script fails where the code changes.

using ReducedComplexityModeling
using ReducedComplexityModeling: number_of_batches
import Random

mean(x) = sum(x) / length(x)
parameters(minibatch) = unique(last.(minibatch))

# For `b ≤ n` a minibatch holds at most one boundary between two parameters, and the boundary at
# position `k n` lies inside a minibatch where `b` does not divide `k n`.
mixed_batches(n, P, b) = count(k -> k * n % b != 0, 1:(P - 1))

function tensor_loader(n, P; autoencoder = false)
    DataLoader(rand(1, n + !autoencoder, P); autoencoder, suppress_info = true)
end

Random.seed!(123)
batches = Batch(2, 1, 1)(tensor_loader(5, 3))
println("6 time steps, 3 parameters, Batch(2, 1, 1): ", length(batches), " batches")
println("distinct parameters per batch: ", length.(parameters.(batches)))
println("batches: ", batches)

println("\nn start positions, P parameters, batch size b, over 200 seeds")
for (n, P, b) in ((5, 3, 2), (10, 7, 4), (20, 5, 20), (10, 7, 10), (30, 4, 3))
    dl = tensor_loader(n, P)
    batch = Batch(b, 1, 1)
    counts = map(1:200) do seed
        Random.seed!(seed)
        batches = batch(dl)
        indices = reduce(vcat, batches)
        @assert length(batches) == cld(n * P, b) == number_of_batches(dl, batch)
        @assert sort(indices) == sort(vec(collect(Iterators.product(1:n, 1:P))))
        count(minibatch -> length(parameters(minibatch)) > 1, batches)
    end
    @assert all(==(mixed_batches(n, P, b)), counts)
    @assert b > n || mixed_batches(n, P, b) ≤ P - 1
    println("n = $n, P = $P, b = $b: ", cld(n * P, b), " batches, ",
        mixed_batches(n, P, b), " with more than one parameter")
end

Random.seed!(1)
println("\nparameters per batch, in order, n = 10, P = 4, b = 3: ",
    sort.(parameters.(Batch(3, 1, 1)(tensor_loader(10, 4)))))

println("\nwhich loader has an axis of length one")
for (name, dl, batch) in (
    ("matrix, autoencoder = true",
    DataLoader(rand(4, 9); autoencoder = true, suppress_info = true), Batch(4)),
    ("one trajectory", tensor_loader(9, 1), Batch(4, 1, 1)),
    ("tensor, autoencoder = true", tensor_loader(5, 3; autoencoder = true), Batch(2)))
    Random.seed!(1)
    println(name, ": (time steps, parameters) = ", (dl.input_time_steps, dl.n_params),
        ", distinct parameters per batch ", length.(parameters.(batch(dl))))
end
@assert tensor_loader(5, 3; autoencoder = true).n_params == 3

# The mean square difference between the mean of a minibatch and the mean of the epoch. Sampling
# `b` of `N` values without replacement gives `S² / b * (1 - b / N)`, with `S²` the sample variance
# of the `N` values. A minibatch of the loader samples from one parameter, for `b` a divisor of `n`,
# so its value is that formula over `n`, averaged over the parameters, plus the between-parameter
# term `between`, which `b` does not reach.
Random.seed!(2024)
n, P = 100, 10
values = randn(P)' .+ randn(n, P)
epoch_mean = mean(values)
parameter_means = vec(sum(values; dims = 1)) ./ n
between = mean(abs2.(parameter_means .- epoch_mean))
sample_variance(x) = sum(abs2, x .- mean(x)) / (length(x) - 1)
within = mean(sample_variance(view(values, :, p)) for p in 1:P)

println("\nmean square difference from the epoch mean, n = $n, P = $P, 400 epochs")
println("between-parameter term: ", round(between; digits = 4))
for b in (5, 10, 20, 50, 100)
    dl = tensor_loader(n, P)
    batch = Batch(b, 1, 1)
    measured = mean(map(1:400) do seed
        Random.seed!(seed)
        mean(abs2(mean(values[i, p] for (i, p) in minibatch) - epoch_mean)
        for minibatch in batch(dl))
    end)
    loader = between + within / b * (1 - b / n)
    uniform = sample_variance(values) / b * (1 - b / (n * P))
    @assert isapprox(measured, loader; rtol = 0.02)
    println("b = $b: loader measured ", round(measured; digits = 4), ", closed form ",
        round(loader; digits = 4), ", uniform partition closed form ", round(uniform; digits = 4))
end
