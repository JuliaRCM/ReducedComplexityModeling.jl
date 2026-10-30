using ReducedComplexityModeling
using Documenter
# add links to GeometricMachineLearning docstrings
using DocumenterInterLinks

using DocumenterCitations

links = InterLinks(
    "GeometricMachineLearning" => (
    "https://juliagni.github.io/GeometricMachineLearning.jl/stable/",
    "https://juliagni.github.io/GeometricMachineLearning.jl/stable/objects.inv",
    joinpath(@__DIR__, "inventories", "GeometricMachineLearning.toml")
),
)

bib = CitationBibliography(joinpath(@__DIR__, "src", "ReducedComplexityModeling.bib"))

# The data loader's docstrings name four types that GeometricMachineLearning owns, so their `@ref`
# falls back to that manual's entry for each.
fallbacks = ExternalFallbacks(
    "AutoEncoder" => "@extref GeometricMachineLearning.AutoEncoder",
    "NeuralNetworkIntegrator" => "@extref GeometricMachineLearning.NeuralNetworkIntegrator",
    "Transformer" => "@extref GeometricMachineLearning.Transformer",
    "TransformerIntegrator" => "@extref GeometricMachineLearning.TransformerIntegrator"
)

DocMeta.setdocmeta!(ReducedComplexityModeling, :DocTestSetup,
    :(using ReducedComplexityModeling); recursive = true)

makedocs(;
    plugins = [bib, links, fallbacks],
    modules = [ReducedComplexityModeling],
    authors = "Michael Kraus",
    repo = "https://github.com/JuliaRCM/ReducedComplexityModeling.jl/blob/{commit}{path}#{line}",
    sitename = "ReducedComplexityModeling.jl",
    checkdocs = :all,
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://JuliaRCM.github.io/ReducedComplexityModeling.jl",
        edit_link = "main",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
    ]
)

deploydocs(;
    repo = "github.com/JuliaRCM/ReducedComplexityModeling.jl",
    devurl = "latest",
    devbranch = "main"
)
