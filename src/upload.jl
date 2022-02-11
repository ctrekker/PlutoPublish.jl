using JSON3
import HTTP

upload_meta_file = joinpath(export_cache, "upload_metadata.json")
apikey_file = joinpath(export_cache, "apikey.txt")

new_notebook_hashes = Set{Pair{String, Symbol}}()

function notebook_meta!(meta_dict, notebook_hash::String)
    if !haskey(meta_dict, Symbol(notebook_hash))
        meta_dict[Symbol(notebook_hash)] = Dict()
    end

    meta_dict[Symbol(notebook_hash)]
end
function get_apikey(url::String)
    if isfile(apikey_file)
        return read(apikey_file, String)
    else
        resp = HTTP.post("$(url)/keys")
        resp_json = JSON3.read(resp.body)
        apikey = resp_json["apikey"]
        open(apikey_file, "w") do io
            write(io, apikey)
        end

        return apikey
    end
end

function _publish_notebook(notebook::Pluto.Notebook, notebook_hash::String, url::String)
    if !isfile(upload_meta_file)
        open(upload_meta_file, "w") do io
            write(io, JSON3.write(Dict()))
        end
    end

    apikey = get_apikey(url)

    meta = copy(JSON3.read(read(upload_meta_file, String)))
    nbmeta = notebook_meta!(meta, notebook_hash)

    url_id_key = Symbol(url)

    notebook_path, notebook_name = joinpath(export_cache, notebook_hash * ".statefile"), basename(notebook.path)

    fresh_publish() = begin
        try
            push!(new_notebook_hashes, notebook_hash => url_id_key)
            res = publish_notebook(notebook_path, notebook_name; url, apikey)
            if !haskey(nbmeta, :id)
                nbmeta[:id] = Dict()
            end
            nbmeta[:id][url_id_key] = res[1, :id]
        catch e
            @error "Notebook with hash $(notebook_hash) had an error first-time publishing"
            showerror(stderr, e)
            # delete the hash if there was an error publishing it first time
            delete!(new_notebook_hashes, notebook_hash => url_id_key)
        end
    end

    if haskey(nbmeta, :id) && haskey(nbmeta[:id], url_id_key)
        try
            update_notebook(nbmeta[:id][url_id_key], Dict(
                "name" => notebook_name,
                "notebook" => notebook_path
            ); url, apikey)
        catch e
            if e isa HTTP.ExceptionRequest.StatusError
                if e.status == 404
                    # this means the notebook we are trying to patch no longer exists
                    # so we need to do a fresh publish
                    fresh_publish()
                else
                    showerror(stderr, e)
                end
            else
                showerror(stderr, e)
            end
        end
    elseif (notebook_hash => url_id_key) ∉ new_notebook_hashes
        fresh_publish()
    end

    open(upload_meta_file, "w") do io
        write(io, JSON3.write(meta))
    end
end
