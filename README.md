# DynamicGrids

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://cesaraustralia.github.io/DynamicGrids.jl/dev)
[![Build Status](https://travis-ci.org/cesaraustralia/DynamicGrids.jl.svg?branch=master)](https://travis-ci.org/cesaraustralia/DynamicGrids.jl) 
[![Coverage Status](https://coveralls.io/repos/cesaraustralia/DynamicGrids.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cesaraustralia/DynamicGrids.jl?branch=master) 
[![codecov.io](http://codecov.io/github/cesaraustralia/DynamicGrids.jl/coverage.svg?branch=master)](http://codecov.io/github/cesaraustralia/DynamicGrids.jl?branch=master)

DynamicGrids is a generalised framework for building high-performance grid-based spatial models, including celluar automata, but also allowing arbitrary behviours such as long distance jumps and interactions between multiple grids. It is extended by [Dispersal.jl](https://github.com/cesaraustralia/Dispersal.jl) for modelling organism dispersal processes.

![Dispersal quarantine](https://raw.githubusercontent.com/cesaraustralia/DynamicGrids.jl/media/dispersal_quarantine.gif)

*A dispersal simulation with quarantine interactions, using Dispersal.jl, custom rules and the 
GtkOuput from [DynamicGridsGtk](https://github.com/cesaraustralia/DynamicGridsGtk.jl). 
Note that this is indicative of the real-time frame-rate on a laptop.*

A DynamicGrids.jl simulation is run with a script like this one
running the included game of life model `Life()`:

```julia
using DynamicGrids, Crayons
init = rand(Bool, 150, 200)
output = REPLOutput(init; fps=30, color=Crayon(foreground=:red, background=:black, bold=true))
ruleset = Ruleset(Life(); init=init)
sim!(output, ruleset; tspan=(1, 200))
```

![REPL life](https://github.com/cesaraustralia/DynamicGrids.jl/blob/media/life.gif?raw=true)

*A game of life simulation being displayed directly in a terminal.*


# Concepts

The framework is highly customisable, but there are some central ideas that define
how a simulation works: *rules* and *interactions*, *init* arrays and *outputs*.


## Rules and Interactions

Rules hold the parameters for running a simulation. Each rule triggers a
specific `applyrule` method that operates on each of the active cells in the grid.
Rules come in a number of flavours (outlined in the 
[docs](https://cesaraustralia.github.io/DynamicGrids.jl/stable/#Rules-1)), which allow
assumptions to be made about running them that can greatly improve performance.
Rules are joined in a `Ruleset` object and run in sequence:

```
ruleset = Ruleset(Life(2, 3))
```

The `Rulset` wrapper seems a little redundant here, but multiple models can be
combined in a `Ruleset`. Each rule will be run for the whole grid, in sequence,
using appropriate optimisations depending on the parent types of each rule:

```julia
ruleset = Ruleset(rule1, rule2)
```

For better performance (often ~2x), models included in a `Chain` object will be
combined into a single model, using only one array read and write. This
optimisation is limited to `CellRule`, or a `NeighborhoodRule`
followed by `CellRule`. If the `@inline` compiler macro is used on all
`applyrule` methods, all rules in a `Chain` will be compiled together into a single, 
efficient function call.

```julia
ruleset = Ruleset(rule1, Chain(rule2, rule3, rule4))
```

A `MultiRuleset` holds, as the name suggests, multiple rulesets. These may
either run side by side independently (say for live comparative analysis), or
interact using `Interaction` rules. An `Interaction` is a rule that operates on
multiple grids, linking multiple discrete `Ruleset`s into a larger model, such
as this hypothetical spatial predator/prey model:

```julia
MuliRuleset(rules=(predator=predatordispersal, prey=Chain(popgrowth, preydispersal)),
            interactions=(predation,))
```


## Init

The `init` array may be any `AbstractArray`, containing whatever initialisation
data is required to start the simulation. The array type, size and element type
of the `init` array determine the types used in the simulation, as well as
providing the initial conditions:

```juli
init = rand(Float32, 100, 100)
```

An `init` array can be attached to a `Ruleset`: 

```
ruleset = Ruleset(Life(); init=init)
```

or passed into a simulation, where it will take preference over the `Ruleset` init:

```
sim!(output, rulset; init=init)
```

For `MultiRuleset`, `init` is a `NamedTuple` of equal-sized arrays
matching the names given to each `Ruleset` :

```julia
init = (predator=rand(100, 100), prey=(rand(100, 100))
```

Handling and passing of the correct arrays is automated by DynamicGrids.jl.
`Interaction` rules must specify which grids they require in what order. 

Passing spatial `init` arrays from [GeoData.jl](https://github.com/rafaqz/GeoData.jl) 
will propagate through the model to give spatially explicit output. This will plot 
correctly as a map using [Plots.jl](https://github.com/JuliaPlots/Plots.jl), 
to which shape files and observation points can be easily added.

## Output 

[Outputs](https://cesaraustralia.github.io/DynamicGrids.jl/stable/#Output-1)
are ways of storing or viewing a simulation. They can be used
interchangeably depending on your needs: `ArrayOutput` is a simple storage
structure for high performance-simulations. As with most outputs, it is
initialised with the `init` array, but in this case it also requires the number
of simulation frames to preallocate before the simulation runs.

```julia
output = ArrayOutput(init, 10)
```

The `REPLOutput` shown above is an inbuilt `GraphicOutput` that can be useful for checking a
simulation when working in a terminal or over ssh:

```julia
output = REPLOutput(init)
```

`ImageOutput` is the most complex class of outputs, allowing full color visual
simulations using COlorSchemes.jl. It can also display interactions using color 
composites or layouts, as shown above in the quarantine simulation.

[DynamicGridsInteract.jl](https://github.com/cesaraustralia/DynamicGridsInteract.jl)
provides simulation interfaces for use in Juno, Jupyter, web pages or electron
apps, with live interactive control over parameters.
[DynamicGridsGtk.jl](https://github.com/cesaraustralia/DynamicGridsGtk.jl) is a
simple graphical output for Gtk. These packages are kept separate to avoid
dependencies when being used in non-graphical simulations. 

Outputs are also easy to write, and high performance or applications may benefit
from writing a custom output to reduce memory use, such as running a loss function on the fly
instead of storing the array. Performance of DynamicGrids.jl is dominated by cache
interactions, and reducing memory use has significant positive effects. Custom 
[frame processors](https://cesaraustralia.github.io/DynamicGrids.jl/stable/#Frame-processors-1)
can also be written, which can help developing specialised visualisations.

## Example

This example implements a very simple forest fire model:

```julia
using DynamicGrids, DynamicGridsGtk, ColorSchemes, Colors

const DEAD = 1
const ALIVE = 2
const BURNING = 3

# Define the Rule struct
struct ForestFire{N,PC,PR} <: NeighborhoodRule
    neighborhood::N
    prob_combustion::PC
    prob_regrowth::PR
end
ForestFire(; neighborhood=RadialNeighborhood{1}(), prob_combustion=0.0001, prob_regrowth=0.01) =
    ForestFire(neighborhood, prob_combustion, prob_regrowth)

# Define an `applyrule` method to be broadcasted over the grid for the `ForestFire` rule
@inline DynamicGrids.applyrule(rule::ForestFire, data, state::Integer, index, hoodbuffer) =
    if state == ALIVE
        if BURNING in DynamicGrids.neighbors(rule, hoodbuffer)
            BURNING
        else
            rand() <= rule.prob_combustion ? BURNING : ALIVE
        end
    elseif state in BURNING
        DEAD
    else
        rand() <= rule.prob_regrowth ? ALIVE : DEAD
    end

# Set up the init array, ruleset and output (using a Gtk window)
init = fill(ALIVE, 400, 400)
ruleset = Ruleset(ForestFire(); init=init)
processor = ColorProcessor(scheme=ColorSchemes.rainbow, zerocolor=RGB24(0.0))
output = GtkOutput(init; fps=25, minval=DEAD, maxval=BURNING, processor=processor)

# Run the simulation
sim!(output, ruleset; tspan=(1, 200))

# Save the output as a gif
savegif("forestfire.gif", output)


```
![forestfire](https://user-images.githubusercontent.com/2534009/72052469-5450c580-3319-11ea-8948-5196d1c6fd33.gif)


We could also use a "windy" custom neighborhood:

```
windyhood = CustomNeighborhood((1,1), (1,2), (1,3), (2,1), (3,1))
ruleset = Ruleset(ForestFire(; neighborhood=windyhood); init=init)
sim!(output, ruleset; tspan=(1, 200))
savegif("windy_forestfire.gif", output)
```

![windy_forestfire](https://user-images.githubusercontent.com/2534009/72198637-a95d1a80-3484-11ea-8b77-25a4a94b3943.gif)


Timing the simulation for 200 steps, the performance is quite good:

```
output = ArrayOutput(init, 200)
@time sim!(output, ruleset; tspan=(1, 200))
 1.384755 seconds (640 allocations: 2.569 MiB)

# To save a gif of the ArrayOutput we need to pass in a processor and the min and max
# values used in the simulation:

savegif("forestfire.gif", output; minval=DEAD, maxval=BURNING, processor=processor)
```


## Alternatives

[Agents.jl](https://github.com/JuliaDynamics/Agents.jl) can also do cellular-automata style simulations. The design of Agents.jl is to iterate over a list of agents, instead of broadcasting over an array of cells. This approach is well suited to when you need to track the movement and details about individual agents throughout the simulation. 

However, for simple grid models where you don't need to track individuals, like the forest fire model above, DynamicGrids.jl is two orders of magnitude faster than Agents.jl, and provides better visualisation tools. If you are doing grid-based simulation and you don't need to track individual agents, DynamicGrids.jl is probably the best tool. For other use cases, try Agents.jl.
