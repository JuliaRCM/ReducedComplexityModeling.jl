using ReducedComplexityModeling
using Test

# The raw text of the docstrings of the binding `name` of `mod`, stripped. `Docs.hasdoc` is also
# true for an empty docstring, so the text is what shows that a docstring says something: it names
# the binding, as a signature line does.
function docstring_text(mod::Module, name::Symbol)
    binding = Docs.Binding(mod, name)
    multidoc = get(Docs.meta(binding.mod), binding, nothing)
    isnothing(multidoc) && return ""
    return strip(join((join(string.(doc.text)) for doc in values(multidoc.docs)), "\n"))
end

# `names` returns the exported and the public names, and the name of the module itself. An
# undefined name fails the loop, because `getfield` throws for it.
@testset "Every exported or public name is documented and owned by the package" begin
    @testset "$name" for name in names(ReducedComplexityModeling)
        @test Docs.hasdoc(ReducedComplexityModeling, name)
        @test occursin(string(name), docstring_text(ReducedComplexityModeling, name))
        @test parentmodule(getfield(ReducedComplexityModeling, name)) ===
              ReducedComplexityModeling
    end
end
