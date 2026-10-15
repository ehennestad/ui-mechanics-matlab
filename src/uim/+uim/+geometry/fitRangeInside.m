function range = fitRangeInside(range, bounds)
%fitRangeInside Shift a range inside bounds, narrowing it only if it cannot fit
%
%   range = uim.geometry.fitRangeInside(range, bounds) shifts a [min, max]
%   range, preserving its width, so it does not extend past either edge of
%   bounds. A range wider than bounds cannot be placed inside by shifting
%   alone, and is narrowed to bounds instead. Zoom tools use this so a
%   zoomed view never shows anything outside the original axes limits.
%
%   Both inputs must be ordered [min, max]; a reversed range or bounds
%   raises uim:fitRangeInside:InvalidRange.
%
%   See also uim.geometry.intersectRanges

    arguments
        range (1,2) double {mustBeMinMaxPair}
        bounds (1,2) double {mustBeMinMaxPair}
    end

    if diff(range) > diff(bounds)
        range = bounds;
    elseif range(1) <= bounds(1)
        range = range - range(1) + bounds(1);
    elseif range(2) > bounds(2)
        range = range - (range(2) - bounds(2));
    end
end

function mustBeMinMaxPair(values)
    if values(1) > values(2)
        error("uim:fitRangeInside:InvalidRange", ...
            "A range must be ordered as [min, max]; got [%g, %g].", values(1), values(2))
    end
end
