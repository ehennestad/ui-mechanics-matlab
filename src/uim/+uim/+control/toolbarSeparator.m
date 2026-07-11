classdef toolbarSeparator < uim.abstract.Control
%toolbarSeparator A decorator for separating groups of buttons in a toolbar.

    properties (Constant)
        Type = 'ToolbarSeparator'
    end

    properties
        Color = ones(1,3) * 0.5
        LineWidth = 1
        Height = 0.8 % Fraction of toolbar height (0,1)
    end

    properties (Access = protected, Transient)
        hSeparator
    end

    methods
        function obj = toolbarSeparator(varargin)

            assertMsg = 'Parent must be an instance of uim.widget.toolbar_ or uim.widget.wtoolbar';
            assert(isa(varargin{1}, 'uim.widget.toolbar_') || isa(varargin{1}, 'uim.widget.wtoolbar'), assertMsg)

            obj@uim.abstract.Control(varargin{:})

            obj.hBackground.Visible = 'off';
            obj.plotSeparator()
            obj.Tag = 'Toolbar Separator';

            obj.IsConstructed = true;
            obj.onVisibleChanged()
        end
    end

    methods (Access = private)
        function plotSeparator(obj)

            [X, Y] = obj.getPlotData();

            h = plot(obj.CanvasAxes, X, Y);

            h.Color = obj.Color;
            h.LineWidth = obj.LineWidth;
            h.HitTest = 'off';
            h.PickableParts = 'none';

            obj.hSeparator = h;
        end

        function [X, Y] = getPlotData(obj)
            [x1, x2] = deal(obj.Position(1));

            yMean = obj.Position(2) + obj.Position(4)/2;

            y1 = yMean - (obj.Position(4)*obj.Height)/2;
            y2 = yMean + (obj.Position(4)*obj.Height)/2;

            X = [x1, x2];
            Y = [y1, y2];
        end
    end

    methods
        function relocate(obj, ~)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.hSeparator, 'XData', X, 'YData', Y)
            end
        end

        function resize(obj)
            if obj.IsConstructed
                [X, Y] = obj.getPlotData();
                set(obj.hSeparator, 'XData', X, 'YData', Y)
            end
        end
    end

    methods
        function updateLocation(obj, ~)
            if obj.IsConstructed
            end
        end
    end

    methods (Hidden, Access = protected)
        function onVisibleChanged(obj, ~)
            switch obj.Visible
                case 'on'
                    obj.hSeparator.Visible = 'on';
                case 'off'
                    obj.hSeparator.Visible = 'off';
            end
        end
    end
end
