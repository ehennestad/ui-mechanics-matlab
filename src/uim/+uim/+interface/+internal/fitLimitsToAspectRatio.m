function [xLim, yLim] = fitLimitsToAspectRatio(xLim, yLim, aspectRatio)
%fitLimitsToAspectRatio Widen limits so the view fills an axes of given aspect
%
%   [xLim, yLim] = uim.interface.internal.fitLimitsToAspectRatio(xLim, ...
%       yLim, aspectRatio) expands whichever interval is too narrow for
%   the axes width/height ratio aspectRatio, symmetrically about its
%   centre, so that diff(xLim)/diff(yLim) equals aspectRatio. Nothing is
%   ever shrunk.

    arguments
        xLim (1,2) double
        yLim (1,2) double
        aspectRatio (1,1) double {mustBePositive}
    end

    xRange = diff(xLim);
    yRange = diff(yLim);

    if xRange/yRange > aspectRatio
        yLim = yLim + [-1, 1] .* (xRange/aspectRatio - yRange)/2;
    elseif xRange/yRange < aspectRatio
        xLim = xLim + [-1, 1] .* (yRange*aspectRatio - xRange)/2;
    end
end
