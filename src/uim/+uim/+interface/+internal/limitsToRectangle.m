function rectangle = limitsToRectangle(xLim, yLim)
%limitsToRectangle Convert crop limits to an [x, y, width, height] rectangle
%
%   rectangle = uim.interface.internal.limitsToRectangle(xLim, yLim)
%   returns [] when no crop is defined (both empty, or both the [1, inf]
%   "whole image" sentinel), and otherwise the rectangle covering the
%   inclusive pixel limits: xLim = [11, 30] spans 20 pixels, so the
%   rectangle is [11, y, 20, h]. This is the inverse of
%   rectangleToLimits, so a crop survives repeated tool activations
%   unchanged.
%
%   See also uim.interface.internal.rectangleToLimits

    arguments
        xLim double
        yLim double
    end

    isWholeImage = isequal(xLim, [1, inf]) && isequal(yLim, [1, inf]);
    if isWholeImage || (isempty(xLim) && isempty(yLim))
        rectangle = [];
        return
    end

    rectangle = [xLim(1), yLim(1), xLim(2) - xLim(1) + 1, yLim(2) - yLim(1) + 1];
end
