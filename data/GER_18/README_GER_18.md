# GER-18
Germany 18 (dena) nodes, with existing infrastructure of year 2015, no nuclear
![Plot](assets/GER_18.svg)
## Time Series
- `solar`: RenewableNinja nuts2 aggregated to dena-zones weighted by geographic area https://www.renewables.ninja
- `wind`: RenewableNinja nuts2 aggregated to dena-zones weighted by geographic area https://www.renewables.ninja
- `el_demand`: Share of "low" and "high"Open Source Electricity Model for Germany (ELMOD-DE) Data Documentation, Egerer, 2016, "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)."

## Installed CAP
### nodes
- `wind, pv, coal, gas, oil`: Open Source Electricity Model for Germany (ELMOD-DE) Data Documentation, Egerer, 2016
### lines
- `trans`: Open Source Electricity Model for Germany (ELMOD-DE) Data Documentation, Egerer, 2016

## Cost Data
### `cap`-costs
- `wind, pv, coal, gas, oil`: "Sektorübergreifende Modellierung und Optimierung eines zukünftigen deutschen Energiesystems unter Berücksichtigung von Energieeffizienzmaßnahmen im Gebäudesektor", Palzer, 2016
- `trans`: !Costs for transmission expansion are per MW*km!: "Zielkonflikte der Energiewende - Life Cycle Assessment der Dekarbonisierung Deutschlands durch sektorenübergreifende Infrastrukturoptimierung", Reinert, 2018
- `bat`: "Konventionelle Kraftwerke - Technologiesteckbrief zur Analyse 'Flexibilitätskonzepte für die Stromversorgung 2050'", Görner & Sauer, 2016
- `h2`: "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
### `fix`-costs
- `wind, pv, gas, bat, h2`: Percentages M/O per cap_cost: "Sektorübergreifende Modellierung und Optimierung eines zukünftigen deutschen Energiesystems unter Berücksichtigung von Energieeffizienzmaßnahmen im Gebäudesektor", Palzer, 2016
- `oil, coal`: assumption oil and coal similar to GuD fix/cap: Percentages M/O per cap_cost: "Sektorübergreifende Modellierung und Optimierung eines zukünftigen deutschen Energiesystems unter Berücksichtigung von Energieeffizienzmaßnahmen im Gebäudesektor", Palzer, 2016
- `trans`: assumption no fix costs
- `h2`: "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
### `var`-costs
- `coal, gas, oil`: Calculation: varcosts_th(Masterthesis Christiane Reinert)/eff(median(eff in ELMOD-DE))
- `pv, wind, bat, h2, trans`: assumption no var costs

## LCIA Recipe H Midpoint, GWP 100a
- `pv, wind, trans, coal, gas, oil`: Ecoinvent v3.3
- `bat_e`: "battery cell production, Li-ion, CN", 5.4933 kg CO2-Eq per 0.106 kWh, Ecoinvent v3.5
- `h2_in`: "fuel cell CH future 2kW", Ecoinvent v3.3

## Other
- `trans`: efficiency is 0.9995 per km
- storage: efficiencies are in efficiency per month
- storage hydrogen: referenced in MWh with lower calorific value 33.32 kWh/kg "DIN 51850: Brennwerte und Heizwerte gasförmiger Brennstoffe" 1980
- `h2_in`, `h2_out`: Sunfire process
- `h2_e`: Cavern
