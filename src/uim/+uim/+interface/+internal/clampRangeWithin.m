function range = clampRangeWithin(range, bounds)
%clampRangeWithin Keep a [min, max] range inside bounds without resizing it
%
%   range = uim.interface.internal.clampRangeWithin(range, bounds) snaps
%   back to bounds when range is wider than bounds, and otherwise shifts
%   range (preserving its width) so it does not extend past either edge
%   of bounds. Zoom tools use it so a zoomed view never shows anything
%   outside the original axes limits.

    arguments
        range (1,2) double
        bounds (1,2) double
    end

    if diff(range) > diff(bounds)
        range = bounds;
    elseif range(1) <= bounds(1)
        range = range - range(1) + bounds(1);
    elseif range(2) > bounds(2)
        range = range - (range(2) - bounds(2));
    end
end
