

function _name(h5::H5DataStore)
    name = HDF5.name(h5)
    name = name[findlast(isequal('/'), name)+1:end]
end


function _create_group(h5::H5DataStore, name)
    if haskey(h5, name)
        g = h5[name]
    else
        g = create_group(h5, name)
    end
    return g
end


"""
save parameters
"""
function save_parameters(h5::H5DataStore, params::NamedTuple; path::AbstractString = "/")
    g = _create_group(h5, path)

    for key in keys(params)
        g[string(key)] = params[key]
    end
end

function save_parameters(fpath::AbstractString, params::NamedTuple)
    h5open(fpath, "r+") do file
        save_parameters(file, params; path = "parameters")
    end
end

"""
read parameters
"""
function read_parameters(h5::H5DataStore, path::AbstractString = "/")
    group = h5[path]

    paramkeys = Tuple(Symbol.(keys(group)))
    paramvals = Tuple(read(group[key]) for key in keys(group))

    NamedTuple{paramkeys}(paramvals)
end

function read_parameters(fpath::AbstractString)
    h5open(fpath, "r") do file
        read_parameters(file; path = "parameters")
    end
end


function h5save(fpath::AbstractString, data, args...; mode="w", kwargs...)
    h5open(fpath, mode) do file
        h5save(file, data, args...; kwargs...)
    end
end

function h5load(T::Type, fpath::AbstractString, args...; mode="r", kwargs...)
    h5open(fpath, mode) do file
        h5load(T, file, args...; kwargs...)
    end
end
