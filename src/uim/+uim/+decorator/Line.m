classdef Line < uim.abstract.Control
%Line Plain line drawn on a component canvas
%
%   A decorative line, for example a divider inside a widget. The
%   component background is hidden; only the line is drawn.
%
%   ln = uim.decorator.Line(parent, Name=Value) creates the line in
%   parent (a uim.UIComponentCanvas, a uim container, an axes or a
%   graphics container) and sets public properties, for example
%
%       ln = uim.decorator.Line(canvas, XData=[5, 25], YData=[30, 30], ...
%           Color=[1, 0, 0], LineWidth=2);
%
%   Without XData and YData the line runs from (Position(1),
%   Position(2)) to (Position(3), Position(4)): the last two elements of
%   Position are read as end coordinates, not as width and height.
%
%   Color and LineWidth are applied when the line is created; changing
%   them afterwards does not update the line.
%
%   See also uim.decorator.Separator

    % Todo:
    %   [ ] Should there be a list of allowed parents?
    %   [ ] Generalize Height... I.e what if separator is horizontal. Also,
    %       should it be relative units?
    %   [ ] Subclass from Decorator instead of Control

    properties (Constant)
        Type = 'Line' % Component type name.
    end

    properties
        XData % Line x-coordinates in canvas pixels. Empty uses Position (see class help).
        YData % Line y-coordinates in canvas pixels. Empty uses Position (see class help).
    end

    properties
        Color = ones(1,3) * 0.5 % Line colour. Read at construction only.
        LineWidth = 0.5 % Line width in points. Read at construction only.
    end

    properties (Access = protected, Transient)
        LineHandle
    end

    methods
        function obj = Line(hParent, propertyValues)
        %Line Create a line decorator
        %
        %   ln = uim.decorator.Line(parent, Name=Value)

            arguments
                hParent
                propertyValues.?uim.decorator.Line
            end

            obj@uim.abstract.Control(hParent, propertyValues)

            %delete(obj.Background);
            obj.Background.Visible = 'off';
            obj.plotLine()

            %obj.Tag = 'Toolbar Separator';

            obj.IsConstructed = true;
            obj.onVisibleChanged()
        end
    end

    methods (Access = private)
        function plotLine(obj)

            [X, Y] = obj.getPlotData();

            h = plot(obj.CanvasAxes, X, Y);

            h.HitTest = 'off';
            h.PickableParts = 'none';
            h.Clipping = 'off';

            h.Color = obj.Color;
            h.LineWidth = obj.LineWidth;

            obj.LineHandle = h;
        end

        function [X, Y] = getPlotData(obj)
            if isempty(obj.XData)
                X = [obj.Position(1), obj.Position(3)];
            else
                X = obj.XData;
            end

            if isempty(obj.YData)
                Y = [obj.Position(2), obj.Position(4)];
            else
                Y = obj.YData;
            end
        end
    end

    methods (Access = protected)
        function relocate(obj, ~)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.LineHandle, 'XData', X, 'YData', Y)
            end
        end

        function resize(obj)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.LineHandle, 'XData', X, 'YData', Y)
            end
        end

        function updateLocation(obj, ~)
            if obj.IsConstructed
            end
        end
    end

    methods (Hidden, Access = protected)
        function onVisibleChanged(obj, ~)
            switch obj.Visible
                case 'on'
                    obj.LineHandle.Visible = 'on';
                case 'off'
                    obj.LineHandle.Visible = 'off';
            end
        end
    end
end
