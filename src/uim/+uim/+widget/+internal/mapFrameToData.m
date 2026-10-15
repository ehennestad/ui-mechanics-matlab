function [x, y] = mapFrameToData(localPoint, dataLimits, frameOrigin, scale, yDir)
%mapFrameToData Convert a point in a scaled overview frame to data coordinates
%
%   [x, y] = uim.widget.internal.mapFrameToData(localPoint, dataLimits, ...
%       frameOrigin, scale, yDir) is the inverse of mapDataToFrame for a
%   single pixel point ([x, y]).
%
%   See also uim.widget.internal.mapDataToFrame

    arguments
        localPoint (1,2) double
        dataLimits (2,2) double
        frameOrigin (1,2) double
        scale (1,1) double {mustBeNonzero}
        yDir {mustBeTextScalar}
    end

    x = dataLimits(1,1) + (localPoint(1) - frameOrigin(1)) ./ scale;

    frameHeight = diff(dataLimits(2,:)) .* scale;
    if strcmpi(yDir, 'reverse')
        yRelative = frameOrigin(2) + frameHeight - localPoint(2);
    else
        yRelative = localPoint(2) - frameOrigin(2);
    end
    y = dataLimits(2,1) + yRelative ./ scale;
end
