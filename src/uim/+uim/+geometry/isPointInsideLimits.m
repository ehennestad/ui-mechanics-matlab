function tf = isPointInsideLimits(point, xLim, yLim)
%isPointInsideLimits True when a point lies within x- and y-limits (inclusive)
%
%   tf = uim.geometry.isPointInsideLimits(point, xLim, yLim)
%   tests the [x, y] point against the two [min, max] intervals. Pointer
%   tools use it with the axes limits (in data units) or with a pixel
%   rectangle converted to limits.

    arguments
        point (1,2) double
        xLim (1,2) double
        yLim (1,2) double
    end

    tf = point(1) >= xLim(1) && point(1) <= xLim(2) && ...
         point(2) >= yLim(1) && point(2) <= yLim(2);
end
