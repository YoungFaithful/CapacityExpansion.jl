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
- techs.csv
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
    A storage technology has always three components
    - `storage_e`: The energy part of the storage device [MWh]
    - `storage_in`: The power part for charging the storage device [MW]
    - `storage_out`: The power part for discharging the storage device [MW]
    If e.g. in a lithium-ion battery the `storage_in` should be the same as `storage_out`, just set the `cap` costs in `costs.csv` of either `storage_in` or `storage_out` to zero. This will add a constraint to bind their capacities.

|`tech`|`categ`|`sector`|`fuel`|`eff`|`max_gradient`|`time_series`|`lifetime`|`financial_lifetime`|`discount_rate`|
|-------|--------|------|-----|--------|-------|-----------------|------------|----------|--------------------|
|[tech...]| function handeling those |`el` for electricity|`none` or fuel dependency|efficiency |max gradient of this technology| `none` or time-series name of this tech|lifetime of an installed cap|time in which you have to pay back your loan| `discount_rate`|
|... |... |... |... |... |... |... |... |... |... |

### lines.csv
!!! note
    Each `node_start` and `node_end` has to be a `node` in the file `nodes.csv`.

|`line`|`node_start`|`node_end`|`reactance`|`resistance`|`power_ex`|`power_lim`|`voltage`|`circuits`|`length`|
|-------|------------|----------|-----------|------------|----------|-----------|---------|----------|--------|
|[line...]|`node` - line starts| `node` - line ends| reactance| resistance| exisitng capacity in MW | capacity limit in MW| voltage or description| number of circuits included| length in km|
|...| ...| ...|...| ...|...| ...| ...|...| ...|
