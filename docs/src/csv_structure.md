# Provided Data & Personal Data Setup
## Units
- Timestep (input data) - h
- Power - MW
- Energy - MWh
- length - km

## Provided Data
The package provides data for:

| name   | nodes                                                | lines | years     | tech                                                                         |
|--------|------------------------------------------------------|-------|-----------|------------------------------------------------------------------------------|
| [GER-1](@ref)  | 1 – germany as single node                           | none  | 2006-2016 | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| [GER-18](@ref) | 18 – dena-zones within germany                       | 49    | 2006-2016 | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| [CA-1](@ref)   | 1 - california as single node                        | none  | 2014-2017 | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| [CA-14](@ref)  | 14 – multiple nodes within CA (no installed capacities currently)| 23    | 2014-2017 | Pv, wind, coal, oil, gas, bat-e, bat-in, bat-out, h2-e, h2-in, h2-out, trans |
| [TX-1](@ref)   | 1 – single node within Texas                         | none  | 2008      | Pv, wind, coal, nuc, gas, bat-e, bat-in, bat-out                             |

## Personal Data Setup
### Folder Structure
- costs.csv
- nodes.csv
- techs.yml
- lines.csv - optional
- TS - subfolder containing time-series-data
- > [timeseries name].csv

### Time Series data
| `Timestamp`| `year` | [nodes...] |
|----------|------|------|
| [some iterator]| relative value of installed capacity for renewables or absolute values for demand or so |
|...| ...|

### costs.csv

| `tech`  |  `year` | `account` |[currency] | [LCA-Impact categories...] |
|-------|-------|---------|-----------|------------|
|[tech]| year of this price | `cap` or `fix` or `var` |Cost per unit Power(MW) or Energy (MWh) | Emissions per unit Power(MW) or Energy (MWh)...|
|...    | ... | ... | ... | ... |

### nodes.csv

|`node`|`region`|`infrastruct`|`lon` | `lat`|[`techs`...] |
|-------|--------|------------|------|------|-------------|
|[node...]|region of this node| `ex` - existing or `lim` - limiting capacity| Latitude in °| Longitude in °| installed capacity of each tech at this node in MW or MWh|
|...| ...| ...|...| ...|

### techs.csv
!!! note
    The currently supported `categ` are
    - `generation`: For generation technologies that are either dispatchable (`none` in column `time_series`) or non-dispatchable (`time_series_name` in column `time_series`)
    - `transmission`: For transmission technologies that have no capacity (`CAP`) per `node`, but capacities (`TRANS`)  per `line`

`techs.yml` needs to have the following structure:
- `tech_groups`: defines parent groups for techs or other tech_groups
- `techs`: defines the technologies, the elements are used to declare the dimension `tech`
The information of the single techs is combined with the information provided within parent tech_groups. One technology can have multiple tech_groups, if the parant has a parant. The combined information must contain:
- `name`: A detailed name of the technology
- `tech_group`: a technology-group that the technology belongs to. Groups can be: `all`, `demand`, `generation`, `dispatchable_generation`, `non_dispatchable_generation`, `storage`, `conversion`, `transmission`
- `plant_lifetime`: the lifetime of this technologies plant [a]
- `financial_lifetime`: financial time to break even [a]
- `discount_rate`: discount rate for technology [a]
- `structure`: `node` or `line` depending on the structure of the technology
- `unit`: the unit that the capacity of the technology scales with. It can be `power`[MW] or `energy`[MWh]
- `input`: the input can be a `carrier` like e.g. electricity `carrier: electricity, a `timeseries` like e.g. `timeseries: demand_electricity`, or a `fuel` like e.g. `fuel: gas`
The information can conatin:
- `constraints`: like an `efficiency` like e.g. `efficiency: 0.53` or `cap_eq` (e.g. discharge capacity is same as charge capacity) `cap_eq: bat_in`

### lines.csv
!!! note
    Each `node_start` and `node_end` has to be a `node` in the file `nodes.csv`.

|`line`|`node_start`|`node_end`|`reactance`|`resistance`|`power_ex`|`power_lim`|`voltage`|`circuits`|`length`|
|-------|------------|----------|-----------|------------|----------|-----------|---------|----------|--------|
|[line...]|`node` - line starts| `node` - line ends| reactance| resistance| exisitng capacity in MW | capacity limit in MW| voltage or description| number of circuits included| length in km|
|...| ...| ...|...| ...|...| ...| ...|...| ...|
