function [xLocal, yLocal] = mapDataToFrame(xData, yData, dataLimits, frameOrigin, scale, yDir)
%mapDataToFrame Convert data coordinates into a scaled overview frame
%
%   [xLocal, yLocal] = uim.widget.internal.mapDataToFrame(xData, yData, ...
%       dataLimits, frameOrigin, scale, yDir) maps data-space points into
%   the pixel frame that shows dataLimits (2-by-2, rows x and y) starting
%   at frameOrigin ([x, y]) with scale pixels per data unit. With yDir
%   'reverse' (image axes) the frame's top row corresponds to the smallest
%   y data value.
%
%   See also uim.widget.internal.mapFrameToData

    arguments
        xData {mustBeNumeric}
        yData {mustBeNumeric}
        dataLimits (2,2) double
        frameOrigin (1,2) double
        scale (1,1) double
        yDir {mustBeTextScalar}
    end

    xLocal = frameOrigin(1) + (xData - dataLimits(1,1)) .* scale;

    yRelative = (yData - dataLimits(2,1)) .* scale;
    frameHeight = diff(dataLimits(2,:)) .* scale;

    if strcmpi(yDir, 'reverse')
        yLocal = frameOrigin(2) + frameHeight - yRelative;
    else
        yLocal = frameOrigin(2) + yRelative;
    end
end
