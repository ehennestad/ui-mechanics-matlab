classdef DraggableRectangle < handle

    properties
        RectanglePlotHandle = gobjects(0);
        RectangleReleaseFcn = [];
    end

    properties (Abstract)
        AnchorPoint
    end

    properties (Abstract, SetAccess = protected)
        Axes
    end

    methods

        function plotRectangle(obj)

            if isempty(obj.RectanglePlotHandle)
                obj.RectanglePlotHandle = plot(obj.Axes, nan, nan);
                obj.RectanglePlotHandle.Color = 'white';
                obj.RectanglePlotHandle.Color = ones(1,3)*0.5;
                obj.RectanglePlotHandle.LineWidth = 1;
                obj.RectanglePlotHandle.PickableParts = 'none';
                obj.RectanglePlotHandle.HitTest = 'off';
                obj.RectanglePlotHandle.Tag = 'Rectangular Selection Outline';
            else
                set(obj.RectanglePlotHandle, 'XData', nan, 'Ydata', nan)
            end

            if ~isempty(obj.RectanglePlotHandle)
                set(obj.RectanglePlotHandle, 'Visible', 'on')
            end
        end

        function updateRectangle(obj, currentPoint)

            if isempty(obj.RectanglePlotHandle); return; end

            % Set rectangle vertex coordinates
            x1 = obj.AnchorPoint(1);
            y1 = obj.AnchorPoint(2);

            if nargin < 2 || isempty(currentPoint)
                currentPoint = obj.Axes.CurrentPoint(1, 1:2);
            end

            x2 = currentPoint(1);
            y2 = currentPoint(2);

            % Make sure rectangle does not exceed axes limits.
            xLim = obj.Axes.XLim;
            yLim = obj.Axes.YLim;

            if      x2 < xLim(1);   x2 = xLim(1);
            elseif  x2 > xLim(2);   x2 = xLim(2);
            end

            if      y2 < yLim(1);   y2 = yLim(1);
            elseif  y2 > yLim(2);   y2 = yLim(2);
            end

            % Assign rectangle vertex coordinates to plot handle
            if ~isempty(obj.RectanglePlotHandle)
                obj.RectanglePlotHandle.XData = [x1, x1, x2, x2, x1];
                obj.RectanglePlotHandle.YData = [y1, y2, y2, y1, y1];
            end
        end

        function resetRectangle(obj)
            delete(obj.RectanglePlotHandle)
            obj.RectanglePlotHandle = [];

            % % % set(obj.RectanglePlotHandle, 'XData', nan, 'Ydata', nan)
            % % % set(obj.RectanglePlotHandle, 'Visible', 'off')
        end
    end
end
