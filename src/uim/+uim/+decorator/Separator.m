classdef Separator < uim.abstract.Control
%Separator Vertical divider between groups of controls
%
%   A vertical line at the left edge of the component (x = Position(1)),
%   centred vertically and spanning Height times the component height.
%   uim.widget.Toolbar and uim.widget.TabBar create separators with
%   their addSeparator methods; create one directly only for a custom
%   container.
%
%   sep = uim.decorator.Separator(parent, Name=Value) creates the
%   separator in parent and sets public properties, for example
%
%       sep = uim.decorator.Separator(canvas, Position=[100, 5, 0, 30], ...
%           PositionMode="manual", SizeMode="manual", Height=0.6);
%
%   Color, LineWidth and Height are applied when the line is drawn or
%   moved; changing Color or LineWidth afterwards does not update it.
%
%   See also uim.widget.Toolbar, uim.decorator.Line

    % Todo:
    %   [ ] Should there be a list of allowed parents?
    %   [ ] Generalize Height... I.e what if separator is horizontal. Also,
    %       should it be relative units?
    %   [ ] Subclass from Decorator instead of Control

    properties (Constant)
        Type = 'Separator' % Component type name.
    end

    properties
        Color = ones(1,3) * 0.5 % Line colour. Read at construction only.
        LineWidth = 1 % Line width in points. Read at construction only.
        Height = 0.8 % Line length as a fraction (0 to 1) of the component height.
    end

    properties (Access = protected, Transient)
        SeparatorHandle
    end

    methods
        function obj = Separator(hParent, propertyValues)
        %Separator Create a separator
        %
        %   sep = uim.decorator.Separator(parent, Name=Value)

            arguments
                hParent
                propertyValues.?uim.decorator.Separator
            end

            obj@uim.abstract.Control(hParent, propertyValues)

            %delete(obj.Background);
            obj.Background.Visible = 'off';
            obj.plotSeparator()

            %obj.Tag = 'Toolbar Separator';

            obj.IsConstructed = true;
            obj.onVisibleChanged()
        end
    end

    methods (Access = private)
        function plotSeparator(obj)

            [X, Y] = obj.getPlotData();

            h = plot(obj.CanvasAxes, X, Y);

            h.HitTest = 'off';
            h.PickableParts = 'none';

            h.Color = obj.Color;
            h.LineWidth = obj.LineWidth;

            obj.SeparatorHandle = h;
        end

        function [X, Y] = getPlotData(obj)
            [x1, x2] = deal(obj.Position(1));

            yMean = obj.Position(2) + obj.Position(4)/2;

            y1 = yMean - (obj.Position(4)*obj.Height)/2;
            y2 = yMean + (obj.Position(4)*obj.Height)/2;

%             y1 = obj.Position(2);
%             y2 = sum(obj.Position([2,4]));

            X = [x1, x2];
            Y = [y1, y2];
        end
    end

    methods (Access = protected)
        function relocate(obj, ~)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.SeparatorHandle, 'XData', X, 'YData', Y)
            end
        end

        function resize(obj)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.SeparatorHandle, 'XData', X, 'YData', Y)
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
                    obj.SeparatorHandle.Visible = 'on';
                case 'off'
                    obj.SeparatorHandle.Visible = 'off';
            end
        end
    end
end
