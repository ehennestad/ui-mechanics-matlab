function [xLimNew, yLimNew] = zoomLimitsAboutPoint(xLim, yLim, zoomFactor, pointerPixel, axesSizePixels, pointerData, yDir)
%zoomLimitsAboutPoint Scale axes limits so the point under the pointer stays put
%
%   [xLimNew, yLimNew] = uim.interface.internal.zoomLimitsAboutPoint(...
%       xLim, yLim, zoomFactor, pointerPixel, axesSizePixels, pointerData,
%       yDir) scales both limits by zoomFactor (see scaleLimits) and then
%   shifts them so the data point pointerData ([x, y]) remains under the
%   pointer, which sits at pointerPixel ([x, y] pixels from the axes'
%   lower-left corner) in an axes of axesSizePixels ([width, height]).
%   yDir is the axes YDir ('normal' or 'reverse').
%
%   The quarter-pixel corrections were tuned empirically for precise
%   zooming on image axes (half a pixel of image-coordinate offset,
%   halved again); they are kept for behavioural compatibility.

    arguments
        xLim (1,2) double
        yLim (1,2) double
        zoomFactor (1,1) double
        pointerPixel (1,2) double
        axesSizePixels (1,2) double {mustBePositive}
        pointerData (1,2) double
        yDir {mustBeTextScalar}
    end

    xLimNew = uim.interface.internal.scaleLimits(xLim, zoomFactor);
    yLimNew = uim.interface.internal.scaleLimits(yLim, zoomFactor);

    width = axesSizePixels(1);
    height = axesSizePixels(2);

    % Offset between the new window's centre and the pointer's data
    % coordinate, expressed through the pointer's relative pixel position.
    shiftX = (width - pointerPixel(1) + 0.25) / width * diff(xLimNew) ...
        - (xLim(1) + diff(xLim)/2 + diff(xLimNew)/2 - pointerData(1));

    if strcmpi(yDir, 'reverse')
        relativeY = (height - abs(height - pointerPixel(2) - 0.25)) / height;
    else
        relativeY = (height - pointerPixel(2)) / height;
    end
    shiftY = relativeY * diff(yLimNew) ...
        - (yLim(1) + diff(yLim)/2 + diff(yLimNew)/2 - pointerData(2));

    xLimNew = xLimNew + shiftX;
    yLimNew = yLimNew + shiftY;
end
