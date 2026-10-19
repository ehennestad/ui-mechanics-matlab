classdef Box < uim.abstract.Control
%Box Decorative box with a background and border
%
%   A component that only draws its background and border, for example
%   to group or frame other components on a canvas. Its look is set with
%   the style properties inherited from uim.abstract.Component
%   (BackgroundColor, BackgroundAlpha, BorderColor, BorderWidth,
%   CornerRadius), and the background is redrawn when the box is
%   resized.
%
%   box = uim.decorator.Box(parent) creates a box in parent: a
%   uim.UIComponentCanvas, a uim container, an axes or a graphics
%   container such as a uipanel.
%
%   box = uim.decorator.Box(parent, Name=Value) also sets public
%   properties, for example
%
%       box = uim.decorator.Box(canvas, Position=[20, 30, 120, 60], ...
%           PositionMode="manual", BackgroundColor=[0.2, 0.2, 0.2]);
%
%   See also uim.abstract.Component

    properties (Constant)
        Type = 'Box' % Component type name.
    end

    methods % Structors
        function obj = Box(hParent, propertyValues)
        %Box Create a decorative box
        %
        %   box = uim.decorator.Box(parent, Name=Value)

            arguments
                hParent
                propertyValues.?uim.decorator.Box
            end

            obj@uim.abstract.Control(hParent, propertyValues)

            obj.IsConstructed = true;
        end
    end

    methods (Access = protected)
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.SizeMode; end
            updateSize@uim.abstract.Component(obj, mode)
            obj.resize()
        end
    end
end
