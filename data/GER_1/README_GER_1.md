# GER-1 #
Germany one node,  with existing infrastructure of year 2015, no nuclear
![Plot](assets/GER_1.svg)
## Time Series
- `solar`: "RenewableNinja",  "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)."
- `wind`: "RenewableNinja":  "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)."
- `el_demand`: Open Source Electricity Model for Germany (ELMOD-DE) Data Documentation, Egerer, 2016, "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)."

## Installed CAP
### nodes
- `wind, pv, coal, gas, oil`: Open Source Electricity Model for Germany (ELMOD-DE) Data Documentation, Egerer, 2016

## Cost Data
### General
- economic lifetime T: Glenk, "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
- cost of capital (WACC), r:  Glenk, "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
### `cap`-costs
- `wind, pv, coal, gas, oil`: "Sektorübergreifende Modellierung und Optimierung eines zukünftigen deutschen Energiesystems unter Berücksichtigung von Energieeffizienzmaßnahmen im Gebäudesektor", Palzer, 2016
- trans: !Costs for transmission expansion are per MW*km!: "Zielkonflikte der Energiewende - Life Cycle Assessment der Dekarbonisierung Deutschlands durch sektorenübergreifende Infrastrukturoptimierung", Reinert, 2018
- bat: "Konventionelle Kraftwerke - Technologiesteckbrief zur Analyse 'Flexibilitätskonzepte für die Stromversorgung 2050'", Görner & Sauer, 2016
- h2: "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
### `fix`-costs
- `wind, pv, gas, bat, h2`: Percentages M/O per cap_cost: "Sektorübergreifende Modellierung und Optimierung eines zukünftigen deutschen Energiesystems unter Berücksichtigung von Energieeffizienzmaßnahmen im Gebäudesektor", Palzer, 2016
- oil, coal: assumption oil and coal similar to GuD fix/cap: Percentages M/O per cap_cost: "Sektorübergreifende Modellierung und Optimierung eines zukünftigen deutschen Energiesystems unter Berücksichtigung von Energieeffizienzmaßnahmen im Gebäudesektor", Palzer, 2016
- `trans`: assumption no fix costs
### `var`-costs
- `coal, gas, oil`: Calculation: varcosts_th(Masterthesis Christiane Reinert)/eff(median(eff in ELMOD-DE))
- `pv, wind, trans`: assumption no var costs
- `h2`: Glenk, "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
- `bat`: assumption of minimal var costs to avoid charge and discharge in same hour in case of energy excess

## CO2 - LCIA Recipe H Midpoint, GWP 100a
cap - construction
- `pv`: Jungbluth Niels, ESU-services, photovoltaic plant construction, 570kWp, multi-Si, on open ground, GLO, cut-off by classification, ecoinvent database version 3.3
- `wind`: Christian Bauer, Paul Scherrer Institute, wind power plant, 800kW, fixed parts [unit], GLO, cut-off by classification, ecoinvent database version 3.3, Christian Bauer, Paul Scherrer Institute, wind power plant, 800kW, moving parts [unit], GLO, cut-off by classification, ecoinvent database version 3.3
- `trans`: R. Jorge, T. Hawkins, und E. Hertwich. Life cycle assessment of electricity transmission and distribution—part 1: Power lines and cables. The International Journal of Life Cycle Assessment, 17(1):9–15, 2012. DOI: 10.1007/s11367-011-0335-1.
- `coal`: Christian Bauer, Paul Scherrer Institute, hard coal power plant construction, 500MW, GLO, cut-off by classification, ecoinvent database version 3.3; Karin Treyer, Paul Scherrer Institute, electricity production, lignite, DE, cut-off by classification, ecoinvent database version 3.3
- `gas`: Thomas Heck, Paul Scherrer Institute, gas power plant construction, 300MW electrical, GLO, cut-off by classification, ecoinvent database version 3.3
- `oil`: Niels Jungbluth, ESU-services, oil power plant construction, 500MW, RER (Europe), cut-off by classification, ecoinvent database version 3.3
- `bat_e`: Dominic Notter, Eidgenössische Materialprüf- und -forschungsanstalt, battery cell production, Li-ion, CN (China), cut-off by classification, ecoinvent database version 3.4 ;5.4933 kg CO2-Eq per 0.106 kWh
- `h2_in`: Alex Primas, ETH Zürich, fuel cell production, polymer electrolyte membrane, 2kW electrical, future, CH, cut-off by classification, ecoinvent database version 3.3

var - Electric power generation, transmission and distribution
- `coal`: Karin Treyer, Paul Scherrer Institute, electricity production, lignite, DE, cut-off by classification, ecoinvent database version 3.3
- `gas`: Karin Treyer, Paul Scherrer Institute, electricity production, natural gas, conventional power plant, DE, cut-off by classification, ecoinvent database version 3.3
- `oil`: Karin Treyer, Paul Scherrer Institute, electricity production, oil, DE, cut-off by classification, ecoinvent database version 3.3

## Other
- storage: efficiencies are in efficiency per month
- storage hydrogen: referenced in MWh with lower calorific value 33.32 kWh/kg "DIN 51850: Brennwerte und Heizwerte gasförmiger Brennstoffe" 1980
- `h2_in`, `h2_out`: Sunfire process
- `h2_e`: Cavern
