using HelpGPT
using Documenter

DocMeta.setdocmeta!(HelpGPT, :DocTestSetup, :(using HelpGPT); recursive=true)

makedocs(;
    modules=[HelpGPT],
    authors="FedeClaudi <federicoclaudi@protonmail.com> and contributors",
    repo="https://github.com/FedeClaudi/HelpGPT.jl/blob/{commit}{path}#{line}",
    sitename="HelpGPT.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://FedeClaudi.github.io/HelpGPT.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/FedeClaudi/HelpGPT.jl",
    devbranch="main",
)
