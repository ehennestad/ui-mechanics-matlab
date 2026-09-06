function pixel = mapValueToPixel(value, valueLimits, trackStart, trackLength)
%mapValueToPixel Map slider values onto a pixel track by linear interpolation
%
%   pixel = uim.widget.internal.mapValueToPixel(value, valueLimits, ...
%       trackStart, trackLength) maps value linearly from the interval
%   valueLimits onto the track that starts at trackStart and spans
%   trackLength pixels, so valueLimits(1) lands on trackStart and
%   valueLimits(2) on trackStart + trackLength. Values outside the limits
%   extrapolate. value can be an array; pixel has the same size.
%
%   See also uim.widget.internal.mapPixelToValue

    arguments
        value {mustBeNumeric}
        valueLimits (1,2) double {mustBeStrictlyIncreasing}
        trackStart (1,1) double
        trackLength (1,1) double
    end

    relativePosition = (double(value) - valueLimits(1)) ./ diff(valueLimits);
    pixel = trackStart + relativePosition .* trackLength;
end

function mustBeStrictlyIncreasing(limits)
    if ~(limits(2) > limits(1))
        error('uim:widget:InvalidLimits', ...
            'Limits must be strictly increasing; got [%g, %g].', limits(1), limits(2))
    end
end
