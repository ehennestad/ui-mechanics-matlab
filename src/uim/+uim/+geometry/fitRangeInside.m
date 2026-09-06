function range = fitRangeInside(range, bounds)
%fitRangeInside Shift a range inside bounds, narrowing it only if it cannot fit
%
%   range = uim.geometry.fitRangeInside(range, bounds) shifts a [min, max]
%   range, preserving its width, so it does not extend past either edge of
%   bounds. A range wider than bounds cannot be placed inside by shifting
%   alone, and is narrowed to bounds instead. Zoom tools use this so a
%   zoomed view never shows anything outside the original axes limits.
%
%   See also uim.geometry.shiftLimitsInside, uim.geometry.intersectRanges

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
