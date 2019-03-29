using Documenter
using Plots
using CEP

makedocs(sitename="CEP.jl",
    authors = "Elias Kuepper, and Holger Teichgraeber",
    pages = [
        "Introduction" => "index.md",
        "Workflow" => "workflow.md",
        "Load Data" => "load_data.md",
        "Optimization" => "opt_cep.md",
        "Provided Data" => "opt_cep_data.md"
        ],
    assets = [
        "assets/clust_for_opt_text.svg",
        "assets/opt_cep.svg",
        "assets/workflow.svg"])

deploydocs(repo = "github.com/YoungFaithful/CEP.jl.git", devbranch = "dev")
