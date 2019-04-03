using Documenter
using Plots
using CEP

makedocs(sitename="CEP.jl",
    authors = "Elias Kuepper, and Holger Teichgraeber",
    pages = [
        "Introduction" => "index.md",
        "Workflow" => "workflow.md",
        "Data Preparation" => ["preparing_clust_data.md", "preparing_opt_cep_data.md", "csv_structure.md", "README_GER_18", "README_GER_1", "README_CA_14", "README_CA_1", "README_TX_1"],
        "Optimization" => ["opt_cep.md","opt_cep_examples.md"],
        ],
    assets = [
        "assets/clust_for_opt_text.svg",
        "assets/opt_cep.svg",
        "assets/workflow.svg"])

deploydocs(repo = "github.com/YoungFaithful/CEP.jl.git", devbranch = "dev")
