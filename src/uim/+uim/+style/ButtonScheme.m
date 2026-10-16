classdef ButtonScheme < handle
%ButtonScheme Colours for the four interaction states of a button
%
%   A button scheme supplies one struct per state — On, Off,
%   HighlightedOn and HighlightedOff — where "highlighted" means the
%   pointer is over the button. A button that is off shows HighlightedOn
%   while it is pressed. Each struct carries ForegroundColor,
%   BackgroundColor, BackgroundAlpha, BorderColor and BorderWidth, and
%   may carry FontWeight.
%
%   Subclass this to define a new look, and assign an instance of the
%   subclass to a control's Style property, for example
%   'Style', uim.style.TabButton.
%
%   Fields of each state struct:
%       ForegroundColor - Colour of the label text and icon
%       BackgroundColor - Fill colour
%       BackgroundAlpha - Fill opacity, 0 (transparent) to 1 (opaque)
%       BorderColor     - Border colour, or 'none'
%       BorderWidth     - Border line width
%       FontWeight      - (Optional) 'normal' or 'bold' for the label
%
%   Colours are RGB triplets or colour names such as 'k'.
%
%   See also uim.control.Button, uim.style.ButtonDarkMode

    % Todo: Add disabled on and off

    properties (Abstract, Constant)
        HighlightedOn   % Button on with the pointer over it, or any button while pressed
        HighlightedOff  % Button off with the pointer over it
        On              % Button on
        Off             % Button off
    end
end
