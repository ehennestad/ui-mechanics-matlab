classdef Line < uim.abstract.Control
%Line A decorator for drawing a plain line in a widget.

    % Todo:
    %   [ ] Should there be a list of allowed parents?
    %   [ ] Generalize Height... I.e what if separator is horizontal. Also,
    %       should it be relative units?
    %   [ ] Subclass from Decorator instead of Control

    properties (Constant)
        Type = 'Line'
    end

    properties
        XData
        YData
    end

    properties
        Color = ones(1,3) * 0.5
        LineWidth = 0.5
    end

    properties (Access = protected, Transient)
        LineHandle
    end

    methods
        function obj = Line(varargin)

            obj@uim.abstract.Control(varargin{:})

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
