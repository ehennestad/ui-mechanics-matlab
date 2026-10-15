function [xCoords, yCoords] = rectangleOutlineBetween(anchor, point, xLim, yLim)
%rectangleOutlineBetween Closed outline of the rectangle spanned by two points
%
%   [xCoords, yCoords] = uim.interface.internal.rectangleOutlineBetween(...
%       anchor, point, xLim, yLim) returns the five vertices (closed) of
%   the axis-aligned rectangle with corners anchor and point, after
%   clamping point into the axes limits so a drag past the edge stops
%   at the edge.

    arguments
        anchor (1,2) double
        point (1,2) double
        xLim (1,2) double
        yLim (1,2) double
    end

    x2 = min(max(point(1), xLim(1)), xLim(2));
    y2 = min(max(point(2), yLim(1)), yLim(2));

    xCoords = [anchor(1), anchor(1), x2, x2, anchor(1)];
    yCoords = [anchor(2), y2, y2, anchor(2), anchor(2)];
end
