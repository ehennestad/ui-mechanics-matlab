function [xCoords, yCoords] = tickMarkCoordinates(trackLimits, yCenter, tickLength, tickMode, numTicks, edgeInset)
%tickMarkCoordinates Coordinates for evenly spaced tick marks along a track
%
%   [xCoords, yCoords] = uim.widget.internal.tickMarkCoordinates(...
%       trackLimits, yCenter, tickLength, tickMode, numTicks, edgeInset)
%   returns 3-by-numTicks matrices suitable for a single NaN-separated line
%   object: each column is one tick (start, end, NaN). Ticks are spread
%   between trackLimits(1) + edgeInset and trackLimits(2) - edgeInset; the
%   inset keeps the outer ticks clear of the track's line width.
%
%   tickMode places the ticks relative to yCenter:
%       'under'   - from yCenter downwards
%       'over'    - from yCenter upwards
%       'both'    - centred on yCenter
%       'underx2' - one tick length below yCenter, extending downwards
%
%   edgeInset is optional (default 2 pixels).

    arguments
        trackLimits (1,2) double
        yCenter (1,1) double
        tickLength (1,1) double {mustBeNonnegative}
        tickMode {mustBeTextScalar}
        numTicks (1,1) double {mustBeInteger, mustBePositive}
        edgeInset (1,1) double = 2
    end

    x1 = trackLimits(1) + edgeInset;
    x2 = trackLimits(2) - edgeInset;

    y1 = yCenter;
    y2 = yCenter - tickLength;

    switch lower(char(tickMode))
        case 'under'
            % Ticks already extend downwards from yCenter.
        case 'both'
            y1 = y1 + tickLength/2;
            y2 = y2 + tickLength/2;
        case 'over'
            y1 = y1 + tickLength;
            y2 = y2 + tickLength;
        case 'underx2'
            y1 = y1 - tickLength;
            y2 = y2 - tickLength;
        otherwise
            error('uim:widget:InvalidTickMode', ...
                ['Unknown tick mode "%s". Use ''under'', ''over'', ', ...
                 '''both'' or ''underx2''.'], char(tickMode))
    end

    xCoords = repmat(linspace(x1, x2, numTicks), 3, 1);
    xCoords(3, :) = nan;
    yCoords = repmat([y1; y2; nan], 1, numTicks);
end
