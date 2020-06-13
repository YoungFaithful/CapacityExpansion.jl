using Documenter
using Plots
using CapacityExpansion

makedocs(
    sitename = "CapacityExpansion.jl",
    authors = "Elias Kuepper, and Holger Teichgraeber",
    pages = [
        "Introduction" => "index.md",
        "Quickstart" => "quickstart.md",
        "Workflow" => "workflow.md",
        "Data" => [
            "preparing_clust_data.md",
            "preparing_opt_cep_data.md",
            "csv_structure.md",
            "README_GER_18.md",
            "README_GER_1.md",
            "README_CA_14.md",
            "README_CA_1.md",
            "README_TX_1.md",
        ],
        "Optimization" => ["opt_cep.md", "results_opt.md", "opt_cep_examples.md"],
        "Teaching" => ["teaching.md", "homework.md"],
    ],
    format = Documenter.HTML(
        assets = [
            asset("assets/cep_text.svg", class = :ico, islocal = true),
            asset("assets/opt_cep.svg", class = :ico, islocal = true),
            asset("assets/workflow.svg", class = :ico, islocal = true),
            asset("assets/GER_1.svg", class = :ico, islocal = true),
            asset("assets/GER_18.svg", class = :ico, islocal = true),
            asset("assets/CA_1.svg", class = :ico, islocal = true),
            asset("assets/CA_14.svg", class = :ico, islocal = true),
            asset("assets/opt_cep_cap_plot.svg", class = :ico, islocal = true),
            asset("assets/preparing_clust_data_load.svg", class = :ico, islocal = true),
            asset("assets/preparing_clust_data_agg.svg", class = :ico, islocal = true),
        ],
    ),
)

deploydocs(repo = "github.com/YoungFaithful/CapacityExpansion.jl.git", devbranch = "dev")
