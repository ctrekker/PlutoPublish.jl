# PlutoPublish.jl

The Julia package that makes [plutopublish.com](https://plutopublish.com) work. Check out the website's [docs](https://plutopublish.com/docs) for more information on how the online service works.

## Installation

```julia
(@v1.7) pkg> add PlutoPublish
```

## Quick Start

Make sure you have an up-to-date version of both [Julia](https://julialang.org/) and [Pluto.jl](https://github.com/fonsp/Pluto.jl) installed first!

Next, open up a Julia REPL with the `julia` command in a terminal. Enter Pkg mode by pressing `]` and install PlutoPublish by typing `add PlutoPublish`.

```julia
(@v1.7) pkg> add PlutoPublish
```

Now start a Pluto server __with the publisher enabled__. This _will not_ publish any notebooks without explicit action later.

```julia
using Pluto, PlutoPublish
Pluto.run(; on_event=publisher())
```

By passing in the `publish` function exported by `PlutoPublish` we listen for publishing requests inside notebooks and will automatically push updates when we do get requests.

Once you've got a notebook open that you want to publish, just add a cell with the following code in it:

```julia
PUBLISH = true;
```

<span class="note"><b>NOTE:</b> This code __must__ be in __its own cell__

The `PlutoPublish` package will detect this cell and automatically upload and publish your notebook to this site every time you make a change!
