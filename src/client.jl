import JSON3, HTTP
import UUIDs: UUID
import DataFrames: DataFrame
export list_notebooks, get_notebook_html, get_notebook_state, get_notebook_code, publish_notebook, update_notebook, delete_notebook

UUIDish = Union{UUID, AbstractString}

function endpoint(path::AbstractString; url="https://plutopublish.com")
    return "$(url)$(path)"
end

function query_string(properties::Dict)
    parts = []
    
    for (prop_key, prop_val) ∈ properties
        push!(parts, HTTP.escapeuri(prop_key) * "=" * HTTP.escapeuri(prop_val))
    end

    "?" * join(parts, "&")
end

function list_notebooks(; kw...)
    req = HTTP.get(endpoint("/notebooks"; kw...))
    JSON3.read(req.body) |> DataFrame
end
function get_notebook_html(id::UUIDish; kw...)
    req = HTTP.get(endpoint("/notebooks/$(id)/html"; kw...))
    String(req.body)
end
function get_notebook_state(id::UUIDish; kw...)
    req = HTTP.get(endpoint("/notebooks/$(id)/state"; kw...))
    req.body
end
function get_notebook_code(id::UUIDish; kw...)
    req = HTTP.get(endpoint("/notebooks/$(id)/code"; kw...))
    String(req.body)
end
function publish_notebook(notebook_path::AbstractString, notebook_name::AbstractString; apikey=nothing, kw...)
    open(notebook_path) do notebook_io
        body_data = Dict(
            "notebook" => HTTP.Multipart(notebook_name, notebook_io, "application/x-pluto-statefile")
        )

        body = HTTP.Form(body_data)
        headers = []
        if !isnothing(apikey)
            push!(headers, "X-Api-Key" => apikey)
        end
        
        req = HTTP.post(endpoint("/notebooks" * (isnothing(notebook_name) ? "" : "?name=$(HTTP.escapeuri(notebook_name))"); kw...), headers, body)
        JSON3.read(req.body) |> DataFrame
    end
end
function update_notebook(id::UUIDish, patch_data::Dict; apikey=nothing, kw...)
    notebook_file = if haskey(patch_data, "notebook")
        nbfile = patch_data["notebook"]
        delete!(patch_data, "notebook")
        nbfile
    else
        nothing
    end

    notebook_body = if !isnothing(notebook_file)
        open(notebook_file, "r") do io
            read(io)
        end
    else
        nothing
    end

    headers = []
    if !isnothing(apikey)
        push!(headers, "X-Api-Key" => apikey)
    end
    
    req = HTTP.patch(endpoint("/notebooks/$(id)" * query_string(patch_data); kw...), headers, isnothing(notebook_body) ? UInt8[] : notebook_body)
    JSON3.read(req.body) |> DataFrame
end
function delete_notebook(id::UUIDish; apikey=nothing, kw...)
    headers = []
    if !isnothing(apikey)
        push!(headers, "X-Api-Key" => apikey)
    end

    req = HTTP.delete(endpoint("/notebooks/$(id)"; kw...), headers)
    req.status
end
