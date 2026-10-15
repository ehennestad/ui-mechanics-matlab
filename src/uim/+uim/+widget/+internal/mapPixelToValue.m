function value = mapPixelToValue(pixel, valueLimits, trackStart, trackLength)
%mapPixelToValue Map pixel positions on a track back to slider values
%
%   value = uim.widget.internal.mapPixelToValue(pixel, valueLimits, ...
%       trackStart, trackLength) is the inverse of mapValueToPixel: a pixel
%   at trackStart maps to valueLimits(1) and one at trackStart + trackLength
%   to valueLimits(2). Pixels outside the track extrapolate; callers clamp
%   the result themselves. pixel can be an array; value has the same size.
%
%   See also uim.widget.internal.mapValueToPixel

    arguments
        pixel {mustBeNumeric}
        valueLimits (1,2) double
        trackStart (1,1) double
        trackLength (1,1) double {mustBeNonzero}
    end

    relativePosition = (double(pixel) - trackStart) ./ trackLength;
    value = valueLimits(1) + relativePosition .* diff(valueLimits);
end
