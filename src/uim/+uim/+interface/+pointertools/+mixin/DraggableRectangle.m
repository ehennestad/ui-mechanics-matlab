classdef DraggableRectangle < handle
%DraggableRectangle Mixin adding a draggable selection rectangle.
%
%   Combined into uim.interface.PointerTool subclasses; relies on the
%   concrete Axes property that PointerTool already provides (a
%   protected, validated matlab.graphics.axis.Axes) rather than
%   redeclaring it here, which would conflict with PointerTool's own
%   declaration under MATLAB's property-validation-inheritance rules
%   (a property with a type/size constraint must be Abstract in every
%   superclass that declares it, and PointerTool's Axes is concrete
%   by design).

    properties
        RectanglePlotHandle = gobjects(0);
        RectangleReleaseFcn = [];
    end

    properties (Abstract)
        AnchorPoint
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

            if nargin < 2 || isempty(currentPoint)
                currentPoint = obj.Axes.CurrentPoint(1, 1:2);
            end

            % The far corner is clamped so the rectangle never exceeds the
            % axes limits.
            [xCoords, yCoords] = uim.interface.internal.rectangleOutlineBetween(...
                obj.AnchorPoint, currentPoint, obj.Axes.XLim, obj.Axes.YLim);

            obj.RectanglePlotHandle.XData = xCoords;
            obj.RectanglePlotHandle.YData = yCoords;
        end

        function resetRectangle(obj)
            delete(obj.RectanglePlotHandle)
            obj.RectanglePlotHandle = [];

            % % % set(obj.RectanglePlotHandle, 'XData', nan, 'Ydata', nan)
            % % % set(obj.RectanglePlotHandle, 'Visible', 'off')
        end
    end
end
