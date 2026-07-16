classdef ButtonScheme < handle

    % Todo: Add disabled on and off

    properties (Abstract, Constant)
        HighlightedOn
        HighlightedOff
        On
        Off
    end
end
