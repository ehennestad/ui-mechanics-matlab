function limits = centeredLimits(center, viewSize)
%centeredLimits Axis limits of a view window centred on a point
%
%   limits = uim.widget.internal.centeredLimits(center, viewSize) returns
%   the 2-by-2 limits ([xMin, xMax; yMin, yMax]) of a window of viewSize
%   ([width, height]) whose centre is center ([x, y]).

    arguments
        center (1,2) double
        viewSize (1,2) double {mustBeNonnegative}
    end

    halfSize = viewSize(:) ./ 2;
    limits = [center(:), center(:)] + [-halfSize, halfSize];
end
