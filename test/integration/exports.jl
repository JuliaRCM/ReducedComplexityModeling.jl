using ReducedComplexityModeling
using Test

@testset "Every exported name is defined" begin
    @test isempty(filter(
        n -> !isdefined(ReducedComplexityModeling, n), names(ReducedComplexityModeling)))
end

# The raw text of the docstrings of the binding `name` of `mod`, stripped. `Docs.hasdoc` is also
# true for an empty docstring, so the text is what shows that a docstring says something.
function docstring_text(mod::Module, name::Symbol)
    binding = Docs.Binding(mod, name)
    multidoc = get(Docs.meta(binding.mod), binding, nothing)
    isnothing(multidoc) && return ""
    return strip(join((join(string.(doc.text)) for doc in values(multidoc.docs)), "\n"))
end

# `names` returns the exported and the public names, and the name of the module itself.
@testset "Every exported or public name is documented and owned by the package" begin
    @testset "$name" for name in names(ReducedComplexityModeling)
        @test Docs.hasdoc(ReducedComplexityModeling, name)
        @test !isempty(docstring_text(ReducedComplexityModeling, name))
        @test parentmodule(getfield(ReducedComplexityModeling, name)) ===
              ReducedComplexityModeling
    end
end
