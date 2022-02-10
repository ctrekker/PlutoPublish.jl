module PlutoPublish

import Pluto, SHA

export publisher


export_cache = joinpath(homedir(), ".julia", "pluto_publish")
if isdir(export_cache)
    # this is a temporary _cache_ directory, so remove all the files that were there
    for to_delete ∈ filter(x -> endswith(x, ".statefile"), readdir(export_cache))
        rm(joinpath(export_cache, to_delete))
    end
else
    mkdir(export_cache)
end


include("client.jl")
include("upload.jl")


function _save_statefile(notebook::Pluto.Notebook, statefile_data::Vector{UInt8}, publisher_url::String)
    # TODO: implement this in WYSIWYR instead when that finally gets released
    static_notebook_hash = bytes2hex(SHA.sha256(notebook.path))
    save_path = joinpath(export_cache, static_notebook_hash * ".statefile")

    decoded_statefile = Pluto.unpack(statefile_data)
    publish_configs = map(
        filter(collect(decoded_statefile["cell_inputs"])) do input_cell
            contains(input_cell.second["code"], "PUBLISH")
        end
    ) do input_cell
        Meta.parse(input_cell.second["code"])
    end
    if length(publish_configs) > 1
        @warn "More than one publishing configuration was included in $(basename(notebook.path)). The first will be used"
    end
    if length(publish_configs) > 0
        publish_configs = first(publish_configs)

        @assert typeof(publish_configs) == Expr "PUBLISH must be assigned to either `true` or `false`"

        # PLUTO_LIVE_PUBLISH_CONFIG = (; args...)   <-- optional ;
        publishing_enabled = if first(publish_configs.args) == :PUBLISH  # without ;
            publish_configs.args[2]  # unsafe, but its client-side from the client
        elseif publish_configs.head == :toplevel && first(first(publish_configs.args).args) == :PUBLISH  # with ;
            publish_configs.args[1].args[2]
        else
            nothing
        end

        @assert typeof(publishing_enabled) == Bool "PUBLISH must be assigned to either `true` or `false`"

        if publishing_enabled
            # actually publish the notebook
            open(save_path, "w") do io
                write(io, statefile_data)
            end
        
            _publish_notebook(notebook, static_notebook_hash, publisher_url)
        end
    end

    # if we don't have publishing configs then don't publish it
end

_uri(se::Pluto.ServerStartEvent) = parse(HTTP.URI, se.address)
_base_url(se::Pluto.ServerStartEvent) = begin
    uri = _uri(se)
    "$(uri.scheme)://$(uri.host):$(uri.port)"
end
_secret(se::Pluto.ServerStartEvent) = get(HTTP.queryparams(_uri(se)), "secret", "")
_statefile_url(notebook::Pluto.Notebook, start_event::Pluto.ServerStartEvent) = "$(_base_url(start_event))/statefile?id=$(notebook.notebook_id)&secret=$(_secret(start_event))"


# cache the server start event once it's sent
server_start_event = nothing

# configured usage
publisher(destination::String = "https://plutopublish.com") = function(event::Pluto.PlutoEvent)
    global server_start_event
    if typeof(event) == Pluto.FileEditEvent
        try
            response = HTTP.get(_statefile_url(event.notebook, server_start_event))
            _save_statefile(event.notebook, response.body, destination)
        catch
            @warn "Failed to fetch notebook statefile"
            for (exc, bt) in current_exceptions()
                showerror(stdout, exc, bt)
                println(stdout)
            end
        end
    elseif typeof(event) == Pluto.ServerStartEvent
        @info event
        server_start_event = event
    end
end

end # module
