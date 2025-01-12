using REPL

abstract type CharStyle end
struct Block <: CharStyle end
struct Braile <: CharStyle end

"""
    REPLOutput <: GraphicOutput

    REPLOutput(init; tspan, kw...)

An output that is displayed directly in the REPL. It can either store or discard
simulation frames.

# Arguments:

- `init`: initialisation `AbstractArray` or `NamedTuple` of `AbstractArray`.

# Keywords

- `color`: a color from Crayons.jl
- `cutoff`: `Real` cutoff point to display a full or empty cell. Default is `0.5`
- `style`: `CharStyle` `Block()` or `Braile()` printing. `Braile` uses 1/4 the screen space of `Block`.

$GRAPHICOUTPUT_KEYWORDS

e `GraphicConfig` object can be also passed to the `graphicconfig` keyword, and other keywords will be ignored.
"""
mutable struct REPLOutput{T,F<:AbstractVector{T},E,GC,Co,St,Cu} <: GraphicOutput{T,F}
    frames::F
    running::Bool
    extent::E
    graphicconfig::GC
    color::Co
    style::St
    cutoff::Cu
end
function REPLOutput(;
    frames, running, extent, graphicconfig,
    color=:white, cutoff=0.5, style=Block(), kw...
)
    if store(graphicconfig)
        append!(frames, _zerogrids(first(frames), length(tspan(extent))-1))
    end
    REPLOutput(frames, running, extent, graphicconfig, color, style, cutoff)
end

function showframe(frame::AbstractArray, o::REPLOutput, data::AbstractSimData)
    f = currentframe(data)
    t = currenttime(data)
    if f == 1 # Clear the console
        print(stdout, "\033c") 
    end
    _print_to_repl((0, 0), o.color, _replframe(>(o.cutoff), o, frame, f))
    # Print the timestamp in the top right corner
    _print_to_repl((0, 0), o.color, string("Time $(t)"))
end

# Terminal commands
_savepos(io::IO=terminal.out_stream) = print(io, "\x1b[s")
_restorepos(io::IO=terminal.out_stream) = print(io, "\x1b[u")
_movepos(io::IO, c=(0,0)) = print(io, "\x1b[$(c[2]);$(c[1])H")
_cursor_hide(io::IO=terminal.out_stream) = print(io, "\x1b[?25l")
_cursor_show(io::IO=terminal.out_stream) = print(io, "\x1b[?25h")

_print_to_repl(pos, c::Symbol, str) =
    _print_to_repl(pos, Crayon(foreground=c), str)
function _print_to_repl(pos, color::Crayon, str)
    io = terminal.out_stream
    _savepos(io)
    _cursor_hide(io)
    _movepos(io, pos)
    print(io, color)
    print(io, str)
    _cursor_show(io)
    _restorepos(io)
end

# Block size constants to calculate the frame size as 
# braile pixels are half the height and width of block pixels
const YBRAILE = 4
const XBRAILE = 2
const YBLOCK = 2
const XBLOCK = 1

_chartype(o::REPLOutput) = _chartype(o.style)
_chartype(s::Braile) = YBRAILE, XBRAILE, :braille
_chartype(s::Block) = YBLOCK, XBLOCK, :block

function _replframe(pred, o, frame::AbstractArray{<:Any,1}, currentframe)
    ystep, xstep, chartype = _chartype(o)
    # Limit output area to available terminal size.
    dispy, dispx = displaysize(stdout)

    f = currentframe
    disprows = (dispy - 1) * ystep + 1
    # For 1D we show all the rows every time
    tlen = length(tspan(o))
    iobuf = IOBuffer()
    catframes = reduce(hcat, frames(o)[f - min(f, disprows) + 1:f])
    uprint(iobuf, pred, permutedims(catframes, (2, 1)), chartype)
    return String(take!(iobuf))
end
function _replframe(pred, o, frame::AbstractArray{<:Any,2}, currentframe)
    ystep, xstep, chartype = _chartype(o)
    # Limit output area to available terminal size.
    dispy, dispx = displaysize(stdout)

    youtput, xoutput = outputsize = size(frame)
    yoffset, xoffset = (0, 0)

    yrange = max(1, ystep * yoffset):min(youtput, ystep * (dispy + yoffset - 1))
    xrange = max(1, xstep * xoffset):min(xoutput, xstep * (dispx + xoffset - 1))
    framewindow = view(Adapt.adapt(Array, frame), yrange, xrange) # TODO make this more efficient on GPU
    iobuf = IOBuffer()
    uprint(iobuf, pred, framewindow, chartype)
    return String(take!(iobuf))
end
