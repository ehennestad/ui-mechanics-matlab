function [xLim, yLim] = panLimits(xLim, yLim, shiftPixels, axesSizePixels, yDir)
%panLimits Translate axes limits by a pointer movement in pixels
%
%   [xLim, yLim] = uim.geometry.panLimits(xLim, yLim, ...
%       shiftPixels, axesSizePixels, yDir) moves the limits opposite to
%   the pointer shift ([dx, dy] pixels) so the content follows the
%   pointer. axesSizePixels is [width, height]; with yDir 'reverse'
%   (image axes) the vertical direction is flipped.

    arguments
        xLim (1,2) double
        yLim (1,2) double
        shiftPixels (1,2) double
        axesSizePixels (1,2) double {mustBePositive}
        yDir {mustBeTextScalar}
    end

    if strcmpi(yDir, 'reverse')
        shiftPixels(2) = -shiftPixels(2);
    end

    shiftData = shiftPixels ./ axesSizePixels .* [diff(xLim), diff(yLim)];
    xLim = xLim - shiftData(1);
    yLim = yLim - shiftData(2);
end
