classdef ButtonScheme < handle
%ButtonScheme Colours for the four interaction states of a button
%
%   A button scheme supplies one struct per state — On, Off,
%   HighlightedOn and HighlightedOff — where "highlighted" means the
%   pointer is over the button. Each struct carries ForegroundColor,
%   BackgroundColor, BackgroundAlpha, BorderColor and BorderWidth, and
%   may carry FontWeight.
%
%   Subclass this to define a new look, and assign the subclass to a
%   control's Style property.

    % Todo: Add disabled on and off

    properties (Abstract, Constant)
        HighlightedOn
        HighlightedOff
        On
        Off
    end
end
