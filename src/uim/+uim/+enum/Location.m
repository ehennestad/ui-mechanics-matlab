classdef Location < handle
%Location Enumeration of anchor locations used for component layout.
%
%   Each member carries the corresponding lowercase location key (Key)
%   used by the string-based layout properties, e.g.
%   uim.enum.Location.NORTHWEST.Key is 'northwest'.

    enumeration
        BOTTOM('bottom')
        TOP('top')
        CENTER('center')
        LEFT('left')
        RIGHT('right')
        SOUTHEAST('southeast')
        SOUTHWEST('southwest')
        NORTHEAST('northeast')
        NORTHWEST('northwest')
    end

    properties (SetAccess = immutable)
        Key % Lowercase location key ('bottom', 'northwest', ...)
    end

    methods
        function obj = Location(key)
            obj.Key = key;
        end
    end
end
