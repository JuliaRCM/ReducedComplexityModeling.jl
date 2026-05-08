using ReducedComplexityModeling
using Documenter
# add links to GeometricMachineLearning docstrings
using DocumenterInterLinks
using GeometricMachineLearning

using DocumenterCitations

links = InterLinks(
    "GeometricMachineLearning" => (
        "https://juliagni.github.io/GeometricMachineLearning.jl/stable",
        "https://juliagni.github.io/GeometricMachineLearning.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "GeometricMachineLearning.toml")
    ),
)

bib = CitationBibliography(joinpath(@__DIR__, "src", "ReducedComplexityModeling.bib"))

DocMeta.setdocmeta!(ReducedComplexityModeling, :DocTestSetup, :(using ReducedComplexityModeling); recursive=true)

makedocs(;
    plugins=[bib, links],
    modules=[ReducedComplexityModeling],
    authors="Michael Kraus",
    repo="https://github.com/JuliaRCM/ReducedComplexityModeling.jl/blob/{commit}{path}#{line}",
    sitename="ReducedComplexityModeling.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaRCM.github.io/ReducedComplexityModeling.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo   = "github.com/JuliaRCM/ReducedComplexityModeling.jl",
    devurl = "latest",
    devbranch = "main",
)
