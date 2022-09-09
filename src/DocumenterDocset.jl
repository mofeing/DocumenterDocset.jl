module DocumenterDocset

using Documenter: Documenter, Documents
using Documenter.Utilities: Selectors

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

    html_writer::Documenter.Writers.HTML

    function Docset(bundle_id, bundle_name, platform_family;
        index=nothing,
        icon=nothing,
        icon_retina=nothing,
        fallback_url=nothing,
        playground=nothing,
        allow_js=false,
        fts=false,
        fts_forbidden=false,
        html_options...)
        new(bundle_id, bundle_name, platform_family, icon, icon_retina, fallback_url, playground, allow_js, fts, fts_forbidden, HTML(html_options...))
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
end)
$(if !isnothing(D.fallback_url)
"""<key>DashDocSetFallbackURL</key>
<string>$(D.fallback_url)</string>"""
end)
$(if !isnothing(D.playground)
"""<key>DashDocSetPlayURL</key>
<string>$(D.playground)</key>"""
end)
$(if D.allow_js
"""<key>isJavaScriptEnabled</key>
<true/>"""
end)
$(if D.fts
"""<key>DashDocSetDefaultFTSEnabled</key>
<true/>"""
end)
$(if D.fts_forbidden
"""<key>DashDocSetFTSNotSupported</key>
<true/>"""
end)
</dict>
</plist>
"""
