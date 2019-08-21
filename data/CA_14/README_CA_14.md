# CA-14
California (modeling CAISO) 14-node model, no existing capacity (currently not published)
![Plot](assets/CA_14.svg)
## Time Series
- `el_demand`: http://www.caiso.com/planning/Pages/ReliabilityRequirements/Default.aspx#Historical
- `solar`: "RenewableNinja",  "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)." (dataset="merra2",system_loss = 10,tracking = 1,tilt = 35,azim = 180)
- `wind`: "RenewableNinja":  "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)."; average hub height in 2016: 80m https://www.eia.gov/todayinenergy/detail.php?id=33912#tab1
(capacity = 1.0,height = 80,turbine = "Vestas+V80+2000",dataset="merra2",system_loss = 10), locations based on current wind-farms, if available in region (https://www.energy.ca.gov/maps/renewable/wind/WindResourceArea_CA_Statewide.pdf)

## Cost Data
### General
- economic lifetime T: NREL
- cost of capital (WACC), r: NREL
### `cap`-costs
- `wind, pv, coal, gas, oil, bat`: NREL
- `trans`: !Costs for transmission expansion are per MW*km!: "Zielkonflikte der Energiewende - Life Cycle Assessment der Dekarbonisierung Deutschlands durch sektorenübergreifende Infrastrukturoptimierung", Reinert, 2018
- `h2`: "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
### `fix`-costs
- `wind, pv, gas, bat, h2, oil, coal`: NREL
- `trans`: assumption no fix costs
### `var`-costs
- `pv, wind, coal, gas, oil`: NREL
- `trans`: assumption no var costs
- `bat, h2`: assumption of minimal var costs to avoid charge and discharge in same hour in case of energy excess

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
- `trans`: efficiency is 0.9995 per km
- storage: efficiencies are in efficiency per month
- storage hydrogen: referenced in MWh with lower calorific value 33.32 kWh/kg "DIN 51850: Brennwerte und Heizwerte gasförmiger Brennstoffe" 1980
- `h2_in`, `h2_out`: Sunfire process
- `h2_e`: Cavern
