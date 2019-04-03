# CSV-Structure
## Units
- Power - MW
- Energy - MWh
- lengths - km

### Setup for each model
- folder-name: [region]-[nodes]
-  subfolder: TS - containing time-series-data
-    [dependency].csv

| Timestamp| year | [nodes...] |
|----------|------|------|
| [some iterator]| relative value of installed capacity for renewables or absolute values for demand or so |
|...| ...|

### costs.csv

| tech  |  year | account |[currency] | [LCA-Impact categories...] |
|-------|-------|---------|-----------|------------|
|[techs]| year of this price | `cap` or `fix` or `var` |Cost per unit Power(MW) or Energy (MWh) | Emissions per unit Power(MW) or Energy (MWh)...|
|...    | ... | ... | ... | ... |

### nodes.csv

|nodes|region|infrastruct|lon | lat|[techs...] |
|-------|--------|------------|--------|------------|--------|
|[nodes...]|region of this node| `ex` - existing or `lim` - limiting capacity| Latitude in °| Longitude in °| installed capacity of each tech at this node|
|...| ...| ...|...| ...|

### techs.csv
|`tech`|`categ`|`sector`|`fuel|`eff_in`|`eff_out`|`max_gradient`|`time_series`|`lifetime`|`financial_lifetime`|`discount_rate`|
|-------|--------|------|-----|--------|-------|-----------------|------------|----------|--------------------|---------------|
|[techs...]| function handeling those |el for electricity|fuel dependency|efficiency in for storage|efficiency out for storage |max gradient of this technology| time-series dependency of this tech|lifetime of an installed cap|time in which you have to pay back your loan| `discount_rate`|

### lines.csv
|`lines`|`node_start`|`node_end`|`reactance`|`resistance`|`power`|`voltage`|`circuits`|`length`|
|[lines...]|node where line starts| node where line ends| reactance| resistance| max power| voltage or description| number of circuits included| length in km|
