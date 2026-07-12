classdef EventData < event.EventData & dynamicprops
%EVENTDATA Event data carrying caller-defined name-value properties.

    methods
        function obj = EventData(nameValuePairs)
            arguments (Repeating)
                nameValuePairs
            end

            inputs = nameValuePairs;
            if isscalar(inputs) && iscell(inputs{1})
                inputs = inputs{1};
            end
            if mod(numel(inputs), 2) ~= 0
                error("uim:event:EventData:InvalidPairs", ...
                    "Event data must be provided as name-value pairs.")
            end

            for i = 1:2:numel(inputs)
                propertyName = char(string(inputs{i}));
                if ~isvarname(propertyName)
                    error("uim:event:EventData:InvalidName", ...
                        "'%s' is not a valid event-data property name.", propertyName)
                end
                addprop(obj, propertyName);
                obj.(propertyName) = inputs{i+1};
            end
        end
    end
end
