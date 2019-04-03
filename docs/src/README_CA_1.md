# CA-1
California (modeling CAISO) one node

## Time Series
- el_demand: http://www.caiso.com/planning/Pages/ReliabilityRequirements/Default.aspx#Historical
- solar: weighted by area of each of the CA_14 nodes: "RenewableNinja",  "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)." (dataset="merra2",system_loss = 10,tracking = 0,tilt = 35,azim = 180)
- wind: weighted by installed capacity on each of the CA_14 nodes: "RenewableNinja":  "Open Power System Data. 2018. Data Package Time series. Version 2018-06-30. https://doi.org/10.25832/time_series/2018-06-30. (Primary data from various sources, for a complete list see URL)."; average hub height in 2016: 80m https://www.eia.gov/todayinenergy/detail.php?id=33912#tab1
(capacity = 1.0,height = 80,turbine = "Vestas+V80+2000",dataset="merra2",system_loss = 10), locations based on current wind-farms, if available in region (https://www.energy.ca.gov/maps/renewable/wind/WindResourceArea_CA_Statewide.pdf)

## Installed CAP
### nodes
- wind, pv, coal, gas, oil: EJ
### lines
- trans: EJ

## Cost Data
### General
- economic lifetime T: NREL
- cost of capital (WACC), r: NREL
### cap_costs
- wind, pv, coal, gas, oil, bat: NREL
- trans: !Costs for transmission expansion are per MW*km!: "Zielkonflikte der Energiewende - Life Cycle Assessment der Dekarbonisierung Deutschlands durch sektorenübergreifende Infrastrukturoptimierung", Reinert, 2018
- h2: "Shared Capacity and Levelized Cost with Application to Power-to-Gas Technology", Glenk, 2019
### fix_costs
- wind, pv, gas, bat, h2, oil, coal: NREL
- trans: assumption no fix costs
### var_costs
- pv, wind, bat, coal, gas, oil: NREL
- h2, trans: assumption no var costs

## LCIA Recipe H Midpoint, GWP 100a
- pv, wind, trans, coal, gas, oil: Ecoinvent v3.3
- bat_e: "battery cell production, Li-ion, CN", 5.4933 kg CO2-Eq per 0.106 kWh, Ecoinvent v3.5
- h2_in: "fuel cell CH future 2kW", Ecoinvent v3.3
- php: ref plant: 15484 GWh/a (BEW 2001a). Lifetime is assumed to be 80 years: 4930800000 kg-CO2-eq (recipe-h-midpoint)/plant, 4930800000/(15484 000 MWh/a*80a)(80a*8760h/a) → CO2-eq/MW, Ecoinvent v3.5

## Other
- trans: efficiency is 0.9995 per km
- storage: efficiencies are in efficiency per month
- storage hydrogen: referenced in MWh with lower calorific value 33.32 kWh/kg "DIN 51850: Brennwerte und Heizwerte gasförmiger Brennstoffe" 1980
- h2_in, h2_out: Sunfire process
- h2_e: Cavern
