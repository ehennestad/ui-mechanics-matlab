function tf = isRangeStrictlyInside(range, bounds)
%isRangeStrictlyInside True when a [min, max] range lies strictly within bounds
%
%   tf = uim.geometry.isRangeStrictlyInside(range, bounds) is
%   true when range(1) > bounds(1) and range(2) < bounds(2). Panning uses
%   it to refuse moves that would reveal space beyond the original view.

    arguments
        range (1,2) double
        bounds (1,2) double
    end

    tf = range(1) > bounds(1) && range(2) < bounds(2);
end
