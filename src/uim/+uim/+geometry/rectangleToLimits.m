function [xLim, yLim] = rectangleToLimits(rectangle)
%rectangleToLimits Convert an [x, y, width, height] crop rectangle to pixel limits
%
%   [xLim, yLim] = uim.geometry.rectangleToLimits(rectangle)
%   returns inclusive pixel limits: a rectangle of width w starting at
%   x covers pixels x through x + w - 1.
%
%   See also uim.geometry.limitsToRectangle

    arguments
        rectangle (1,4) double
    end

    xLim = [rectangle(1), rectangle(1) + rectangle(3) - 1];
    yLim = [rectangle(2), rectangle(2) + rectangle(4) - 1];
end
