classdef EventData < event.EventData & dynamicprops
%EventData Event data carrying caller-defined name-value properties
%
%   Generic event data for events and callbacks whose payload does not
%   need its own class. Each name-value pair becomes a dynamic property
%   of the object, so a listener reads the payload as evt.<Name>.
%
%   evt = uim.event.EventData() creates event data with no payload.
%
%   evt = uim.event.EventData(Name1, Value1, Name2, Value2, ...) adds one
%   property per pair. Names are text and must be valid MATLAB variable
%   names; values can be anything.
%
%   evt = uim.event.EventData({Name1, Value1, ...}) accepts the pairs as
%   a single cell array.
%
%   Errors:
%       uim:EventData:InvalidPairs - an odd number of inputs was given.
%       uim:EventData:InvalidName - a name is not a valid variable name.
%
%   Example:
%       evt = uim.event.EventData("Index", 4);
%       evt.Index   % returns 4
%
%   See also uim.event.ValueChangedEventData, uim.event.ToggleEvent

    methods
        function obj = EventData(nameValuePairs)
        %EventData Create event data from name-value pairs
            arguments (Repeating)
                nameValuePairs
            end

            inputs = nameValuePairs;
            if isscalar(inputs) && iscell(inputs{1})
                inputs = inputs{1};
            end
            if mod(numel(inputs), 2) ~= 0
                error("uim:EventData:InvalidPairs", ...
                    "Event data must be provided as name-value pairs.")
            end

            for i = 1:2:numel(inputs)
                propertyName = char(string(inputs{i}));
                if ~isvarname(propertyName)
                    error("uim:EventData:InvalidName", ...
                        "'%s' is not a valid event-data property name.", propertyName)
                end
                addprop(obj, propertyName);
                obj.(propertyName) = inputs{i+1};
            end
        end
    end
end
