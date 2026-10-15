classdef DraggableRectangle < handle
%DraggableRectangle Mixin that draws a rubber-band rectangle for a pointer tool
%
%   Combine this mixin with uim.interface.PointerTool in a tool class
%   that selects a rectangle by dragging, as ZoomIn does:
%
%       classdef MyTool < uim.interface.PointerTool & ...
%               uim.interface.pointertools.mixin.DraggableRectangle
%
%   The subclass defines AnchorPoint, the fixed [x, y] corner of the
%   rectangle in data units (typically the press point), and calls:
%     plotRectangle   - on press, to create or reuse the outline
%     updateRectangle - on motion, to stretch it from AnchorPoint to the
%                       pointer
%     resetRectangle  - on release, to delete it
%   The outline is a grey line that ignores mouse clicks, drawn with
%   plot into the tool's Axes, so the axes must be held.
%
%   See also uim.interface.pointertools.ZoomIn, uim.interface.PointerTool

%   The mixin uses the Axes property that PointerTool provides (a
%   protected, validated matlab.graphics.axis.Axes) rather than
%   redeclaring it here, which would conflict with PointerTool's own
%   declaration under MATLAB's property-validation-inheritance rules
%   (a property with a type/size constraint must be Abstract in every
%   superclass that declares it, and PointerTool's Axes is concrete
%   by design).

    properties
        RectanglePlotHandle = gobjects(0); % Line object of the outline, or empty when none is drawn
        RectangleReleaseFcn = []; % Not used
    end

    properties (Abstract)
        AnchorPoint % [x, y] fixed corner of the rectangle, in data units
    end

    methods

        function plotRectangle(obj)
        %plotRectangle Create the outline, or clear the existing one, and show it
        %
        %   tool.plotRectangle() creates an empty outline in the axes, or
        %   clears the data of an existing one, and makes it visible.

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
        %updateRectangle Stretch the outline from AnchorPoint to a point
        %
        %   tool.updateRectangle() uses the axes CurrentPoint.
        %   tool.updateRectangle(currentPoint) uses an [x, y] point in data
        %   units. The far corner is clamped to the axes limits. Does
        %   nothing when no outline exists.

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
        %resetRectangle Delete the outline
            delete(obj.RectanglePlotHandle)
            obj.RectanglePlotHandle = [];

            % % % set(obj.RectanglePlotHandle, 'XData', nan, 'Ydata', nan)
            % % % set(obj.RectanglePlotHandle, 'Visible', 'off')
        end
    end
end
