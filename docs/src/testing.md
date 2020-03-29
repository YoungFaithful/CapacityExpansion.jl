Testing
========
The model is being tested against a capacity expansion model presented in the paper [`On representation of temporal variability in electricity capacity
planning models` by Merrick 2016](http://dx.doi.org/10.1016/j.eneco.2016.08.001). The model additionally tests itself against previously calculated data to detect new errors.

Testing is defined in the `/test/` directory:
- `cep_exact_data.jld2` stores previously calculated data
- `cep.jl` is used to test the calculations against the capacity expansion model presented in the paper (`TX_1`) and the previously calculated data (`GER_18`, `GER_1`, `CA_14`, and `CA_1`)

In order to run the test:
```julia
using CapacityExpansion
include(joinpath(CapacityExpansion.DIR),"test","cep.jl")
```
