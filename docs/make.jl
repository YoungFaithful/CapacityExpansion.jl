using Documenter
using Plots
using CapacityExpansion

makedocs(sitename="CapacityExpansion.jl",
    authors = "Elias Kuepper, and Holger Teichgraeber",
    pages = [
        "Introduction" => "index.md",
        "Workflow" => "workflow.md",
        "Data" => ["preparing_clust_data.md", "preparing_opt_cep_data.md", "csv_structure.md", "README_GER_18.md", "README_GER_1.md", "README_CA_14.md", "README_CA_1.md", "README_TX_1.md"],
        "Optimization" => ["opt_cep.md","opt_cep_examples.md"],
        ],
    format = Documenter.HTML(assets = [
        "assets/clust_for_opt_text.svg",
        "assets/opt_cep.svg",
        "assets/workflow.svg",
        "assets/GER_1.svg",
        "assets/GER_18.svg",
        "assets/CA_1.svg",
        "assets/CA_14.svg",
        "assets/opt_cep_cap_plot",
        "assets/preparing_clust_data_load",
        "assets/preparing_clust_data_agg"])
        )

deploydocs(repo = "github.com/YoungFaithful/CapacityExpansion.jl.git", devbranch="dev")
