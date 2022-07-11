using ReducedComplexityModeling
using Documenter

DocMeta.setdocmeta!(ReducedComplexityModeling, :DocTestSetup, :(using ReducedComplexityModeling); recursive=true)

makedocs(;
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
    repo="github.com/JuliaRCM/ReducedComplexityModeling.jl",
    devbranch="main",
)
