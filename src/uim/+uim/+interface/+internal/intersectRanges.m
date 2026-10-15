function range = intersectRanges(range, bounds)
%intersectRanges Clip each end of a [min, max] range to bounds
%
%   range = uim.interface.internal.intersectRanges(range, bounds) raises
%   the lower end to bounds(1) and lowers the upper end to bounds(2) as
%   needed. Unlike clampRangeWithin, the range shrinks rather than shifts.

    arguments
        range (1,2) double
        bounds (1,2) double
    end

    range = [max(range(1), bounds(1)), min(range(2), bounds(2))];
end
