using Documenter
using Cliquer

makedocs(
    sitename = "Cliquer",
    modules = [Cliquer],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = [
        "Home" => "index.md",
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "https://github.com/dstahlke/Cliquer.jl",
    devbranch = "main",
    branch = "gh-pages",
)
