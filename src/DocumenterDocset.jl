module DocumenterDocset

using Documenter: Documenter, Documents
using Documenter.Utilities: Selectors
using Octo: Octo, Raw
using Octo.Adapters.SQLite: SQLite
using Gumbo
using Cascadia

export Docset

abstract type DocsetFormat <: Documenter.Writers.FormatSelector end
Selectors.order(::Type{DocsetFormat}) = 1.0
Selectors.matcher(::Type{DocsetFormat}, fmt, _) = isa(fmt, Docset)
Selectors.runner(::Type{DocsetFormat}, fmt, doc) = render(doc, fmt)

# TODO TOC support
struct Docset <: Documenter.Writer
    bundle_id::String
    bundle_name::String
    platform_family::String

    # dash
    icon::Union{String,Nothing} # DOC path to icon
    icon_retina::Union{String,Nothing} # DOC path to icon (retina screen)
    index::Union{String,Nothing} # DOC path to index
    fallback_url::Union{String,Nothing} # DOC fallback URL to online documentation
    playground::Union{String,Nothing} # DOC URL to interactive playground
    allow_js::Bool
    fts::Bool # DOC full-text search enabled
    fts_forbidden::Bool # DOC enforce full-text search ban

    html_writer::Documenter.Writers.HTMLWriter.HTML

    function Docset(bundle_id, bundle_name, platform_family;
        icon=nothing,
        icon_retina=nothing,
        index=nothing,
        fallback_url=nothing,
        playground=nothing,
        allow_js=false,
        fts=false,
        fts_forbidden=false,
        html_options...)
        new(bundle_id, bundle_name, platform_family, icon, icon_retina, index, fallback_url, playground, allow_js, fts, fts_forbidden, Documenter.Writers.HTMLWriter.HTML(html_options...))
    end
end

infoplist(D::Docset) = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleIdentifier</key>
<string>$(D.bundle_id)</string>
<key>CFBundleName</key>
<string>$(D.bundle_name)</string>
<key>DocSetPlatformFamily</key>
<string>$(D.platform_family)</string>
<key>isDashDocset</key>
<true/>
$(if !isnothing(D.index)
"""<key>dashIndexFilePath</key>
<string>$(D.index)</string>"""
else ""
end)
$(if !isnothing(D.fallback_url)
"""<key>DashDocSetFallbackURL</key>
<string>$(D.fallback_url)</string>"""
else ""
end)
$(if !isnothing(D.playground)
"""<key>DashDocSetPlayURL</key>
<string>$(D.playground)</key>"""
else ""
end)
$(if D.allow_js
"""<key>isJavaScriptEnabled</key>
<true/>"""
else ""
end)
$(if D.fts
"""<key>DashDocSetDefaultFTSEnabled</key>
<true/>"""
else ""
end)
$(if D.fts_forbidden
"""<key>DashDocSetFTSNotSupported</key>
<true/>"""
else ""
end)
</dict>
</plist>
"""

forkfields(obj, fields, keys, kwargs) = [field ∈ keys ? kwargs[field] : getfield(obj, field) for field in fields]

@generated function fork(x; kwargs...)
    T = x
    keys = kwargs.types[1].parameters[1]
    fields = fieldnames(T)

    quote
        $T(forkfields(x, $fields, $keys, kwargs)...)
    end
end

function render(doc::Documents.Document, settings::Docset)
    docset_path = joinpath(doc.user.build, "$(settings.bundle_name).docset")
    mkpath(joinpath(docset_path, "Contents", "Resources", "Documents"))

    # generate Info.plist file
    @info "DocumenterDocset: generating `Info.plist`."
    open(joinpath(docset_path, "Contents", "Info.plist"), "w") do fh
        text = infoplist(settings)
        write(fh, text)
    end

    # render HTML pages
    @info "DocumenterDocset: rendering HTML pages."
    html_path = joinpath(doc.user.build, docset_path, "Contents", "Resources", "Documents")
    doc_html = fork(doc, user=fork(doc.user, build=html_path))
    Documenter.Writers.HTMLWriter.render(doc_html, settings.html_writer)

    # create SQLite index
    @info "DocumenterDocset: populating SQLite index."
    Octo.Repo.connect(adapter=SQLite, dbfile=joinpath(docset_path, "Contents", "Resources", "docSet.dsidx"))

    Octo.Repo.execute(Raw("CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)"))
    Octo.Repo.execute(Raw("CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)"))

    # populate index
    for (root, dirs, files) in walkdir(html_path)
        filter!(x -> endswith(".html", x), files)
        rel_path = chopprefix(root, html_path)

        for file in files
            html_file_path = joinpath(rel_path, file)
            html = parsehtml(read(path, String))

            for elem in eachmatch(sel".docstring", html.root)
                binding = Cascadia.matchFirst(sel".docstring-binding", elem)
                name = binding.attributes["id"]

                href = binding.attributes["href"]
                path = join(html_file_path, "$href")

                type = text(Cascadia.matchFirst(sel".docstring-category", elem))

                Octo.Repo.execute(Raw("INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ($name, $type, $path)"))
            end
        end
    end

    Octo.Repo.disconnect()
end

end