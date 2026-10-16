classdef Location < handle
%Location Enumeration of named layout locations
%
%   Each member carries its name as a lowercase character vector in the
%   Key property, e.g. uim.enum.Location.NORTHWEST.Key is 'northwest'.
%
%   Layout properties in this toolbox take text, not members of this
%   enumeration. Use Key to get the text: the keys 'center',
%   'northeast', 'northwest', 'southeast' and 'southwest' are valid
%   values of uim.abstract.Component's Location property.
%
%   See also uim.abstract.Component

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
        %Location Create a member that carries its lowercase key
        %
        %   MATLAB calls this for each enumeration member; use the members,
        %   e.g. uim.enum.Location.NORTHWEST, rather than calling it.
            obj.Key = key;
        end
    end
end
