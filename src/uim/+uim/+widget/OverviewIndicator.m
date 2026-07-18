classdef OverviewIndicator < uim.abstract.Control
%OverviewIndicator An interactive zoom outline for a zoomable view
%
%   indicator = uim.widget.OverviewIndicator(hParent, Name, Value, ...)
%   creates a small overview chip (typically corner-anchored inside a
%   data axes via the overlay canvas) showing the full data extent as a
%   frame and the currently visible region as a draggable rectangle.
%
%   The host pushes state in:
%       DataLimits - [xMin, xMax; yMin, yMax] full extent of the data
%       ViewLimits - [xMin, xMax; yMin, yMax] currently visible region
%
%   User interactions notify the host through ViewChangedFcn(src, evt),
%   where evt is a uim.event.EventData with XLim and YLim properties:
%     - dragging the view rectangle pans it inside the data extent
%       (fires continuously while dragging);
%     - clicking elsewhere in the frame centers the view there (also
%       available programmatically as centerViewOn(x, y), which
%       notifies like the interaction it backs).
%
%   Programmatic assignment to ViewLimits/DataLimits updates the display
%   without firing the callback (push model). The host owns the axes:
%   apply evt.XLim/evt.YLim to the target axes in ViewChangedFcn.
%
%   Use YDir = 'reverse' when the target axes displays images, so the
%   outline is oriented like the image.
%
%   The widget box hugs the data-extent frame: Size acts as a maximum,
%   and the box shrinks along one dimension when the data aspect ratio
%   differs from the box aspect ratio.
%
%   Example:
%       imagesc(hAxes, imageData)
%       indicator = uim.widget.OverviewIndicator(hAxes, ...
%           'Location', 'southeast', 'YDir', 'reverse', ...
%           'DataLimits', [hAxes.XLim; hAxes.YLim], ...
%           'ViewLimits', [hAxes.XLim; hAxes.YLim], ...
%           'ViewChangedFcn', @(src, evt) set(hAxes, ...
%               'XLim', evt.XLim, 'YLim', evt.YLim));

    properties (Constant) % Inherited from Component
        Type = 'OverviewIndicator'
    end

    properties
        DataLimits (2,2) double = [0, 1; 0, 1]  % Full extent: [xMin, xMax; yMin, yMax]
        ViewLimits (2,2) double = [0, 1; 0, 1]  % Visible region: [xMin, xMax; yMin, yMax]

        YDir (1,:) char {mustBeMember(YDir, {'normal', 'reverse'})} = 'normal'

        ViewChangedFcn = []     % Fired when the user moves the view. (src, uim.event.EventData with XLim/YLim)

        FrameColor = 'w'        % Edge color of the data-extent frame
        ViewRectColor = 'w'     % Edge/fill color of the view rectangle
    end

    properties (Access = protected, Transient)
        FrameHandle = gobjects(0,1)
        ViewRectHandle = gobjects(0,1)

        % Data-to-widget mapping, updated on every redraw
        LocalScale (1,1) double = 1     % Pixels per data unit
        FrameOrigin (1,2) double = [0, 0]

        % Drag state
        DragStartPoint (1,2) double = [0, 0]
        DragStartViewLimits (2,2) double = [0, 1; 0, 1]
        DragMotionListener
        DragReleaseListener
    end

    methods % Structors

        function obj = OverviewIndicator(hParent, varargin)

            obj@uim.abstract.Control(hParent, varargin{:})

            % View-rect drags read CurrentPoint from motion listeners; in
            % java figures that requires a WindowButtonMotionFcn.
            uim.utility.ensurePointerMotionTracking(...
                ancestor(obj.CanvasAxes, 'figure'))

            obj.plotOutlines()

            obj.IsConstructed = true;

            obj.updateGraphics()
            obj.onVisibleChanged()
        end

        function delete(obj)
            obj.stopDrag()

            handles = [obj.FrameHandle, obj.ViewRectHandle];
            delete(handles(isvalid(handles)))
        end
    end

    methods % Public

        function centerViewOn(obj, x, y)
        %centerViewOn Center the view on a data point and notify the host

            viewSize = diff(obj.ViewLimits, 1, 2);
            newLimits = [x, x; y, y] + [-1, 1; -1, 1].*viewSize/2;
            obj.applyViewFromUser(newLimits)
        end
    end

    methods % Set/Get

        function set.DataLimits(obj, newValue)
            obj.DataLimits = newValue;
            obj.updateGraphics()
        end

        function set.ViewLimits(obj, newValue)
            obj.ViewLimits = newValue;
            obj.updateGraphics()
        end

        function set.YDir(obj, newValue)
            obj.YDir = newValue;
            obj.updateGraphics()
        end
    end

    methods (Hidden, Access = protected)

        function plotOutlines(obj)

            obj.FrameHandle = patch(obj.CanvasAxes, nan, nan, 'w');
            obj.FrameHandle.FaceAlpha = 0;
            obj.FrameHandle.EdgeColor = obj.FrameColor;
            obj.FrameHandle.EdgeAlpha = 0.6;
            obj.FrameHandle.LineWidth = 0.5;
            obj.FrameHandle.Tag = 'OverviewFrame';
            obj.FrameHandle.HitTest = 'on';
            obj.FrameHandle.PickableParts = 'all';
            obj.FrameHandle.ButtonDownFcn = @(~, ~) obj.onFrameClicked();

            obj.ViewRectHandle = patch(obj.CanvasAxes, nan, nan, ...
                obj.ViewRectColor);
            obj.ViewRectHandle.FaceAlpha = 0.15;
            obj.ViewRectHandle.EdgeColor = obj.ViewRectColor;
            obj.ViewRectHandle.LineWidth = 1;
            obj.ViewRectHandle.Tag = 'OverviewViewRect';
            obj.ViewRectHandle.HitTest = 'on';
            obj.ViewRectHandle.PickableParts = 'all';
            obj.ViewRectHandle.ButtonDownFcn = @(~, ~) obj.startDrag();
        end

        function updateGraphics(obj)
        %updateGraphics Map data-space rectangles into the widget box

            if ~obj.IsConstructed || isempty(obj.FrameHandle); return; end

            dataSize = diff(obj.DataLimits, 1, 2);
            if any(dataSize <= 0); return; end

            % Fit the data extent inside the padded widget box, preserving
            % the data aspect ratio (letterboxed when they differ).
            innerOrigin = obj.Position(1:2) + obj.Padding(1:2);
            innerSize = obj.Position(3:4) ...
                - obj.Padding(1:2) - obj.Padding(3:4);

            obj.LocalScale = min(innerSize(:)./dataSize);
            frameSize = (dataSize*obj.LocalScale)';
            obj.FrameOrigin = innerOrigin + (innerSize - frameSize)/2;

            % Shrink the widget box to hug the letterboxed frame, so the
            % chip background does not extend past the outline. Size acts
            % as a maximum; the box re-anchors through set.Size and this
            % method runs again with the fitted size.
            targetSize = frameSize + obj.Padding(1:2) + obj.Padding(3:4);
            if any(abs(targetSize - obj.Position(3:4)) > 0.5)
                obj.Size = targetSize;
                return
            end

            [frameX, frameY] = obj.dataToLocal(...
                obj.DataLimits(1, [1, 2, 2, 1]), obj.DataLimits(2, [1, 1, 2, 2]));
            set(obj.FrameHandle, 'XData', frameX, 'YData', frameY)

            [viewX, viewY] = obj.dataToLocal(...
                obj.ViewLimits(1, [1, 2, 2, 1]), obj.ViewLimits(2, [1, 1, 2, 2]));
            set(obj.ViewRectHandle, 'XData', viewX, 'YData', viewY)
        end

        function [xLocal, yLocal] = dataToLocal(obj, xData, yData)
        %dataToLocal Convert data coordinates to canvas-local pixels

            xLocal = obj.FrameOrigin(1) ...
                + (xData - obj.DataLimits(1,1))*obj.LocalScale;

            yRelative = (yData - obj.DataLimits(2,1))*obj.LocalScale;
            frameHeight = diff(obj.DataLimits(2,:))*obj.LocalScale;

            if strcmp(obj.YDir, 'reverse')
                yLocal = obj.FrameOrigin(2) + frameHeight - yRelative;
            else
                yLocal = obj.FrameOrigin(2) + yRelative;
            end
        end

        function [x, y] = localToData(obj, localPoint)
        %localToData Convert a canvas-local pixel point to data coordinates

            x = obj.DataLimits(1,1) ...
                + (localPoint(1) - obj.FrameOrigin(1))/obj.LocalScale;

            frameHeight = diff(obj.DataLimits(2,:))*obj.LocalScale;
            if strcmp(obj.YDir, 'reverse')
                yRelative = obj.FrameOrigin(2) + frameHeight - localPoint(2);
            else
                yRelative = localPoint(2) - obj.FrameOrigin(2);
            end
            y = obj.DataLimits(2,1) + yRelative/obj.LocalScale;
        end

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end

            obj.Background.Visible = obj.Visible;
            handles = [obj.FrameHandle, obj.ViewRectHandle];
            set(handles(isvalid(handles)), 'Visible', obj.Visible)
        end
    end

    methods (Access = private) % User interactions

        function startDrag(obj)

            obj.DragStartPoint = obj.CanvasAxes.CurrentPoint(1, 1:2);
            obj.DragStartViewLimits = obj.ViewLimits;

            hFigure = ancestor(obj.Background, 'figure');
            obj.DragMotionListener = addlistener(hFigure, ...
                'WindowMouseMotion', @(~, ~) obj.onDragMotion());
            obj.DragReleaseListener = addlistener(hFigure, ...
                'WindowMouseRelease', @(~, ~) obj.stopDrag());
        end

        function onDragMotion(obj)

            currentPoint = obj.CanvasAxes.CurrentPoint(1, 1:2);
            deltaPixels = currentPoint - obj.DragStartPoint;

            deltaData = deltaPixels/obj.LocalScale;
            if strcmp(obj.YDir, 'reverse')
                deltaData(2) = -deltaData(2);
            end

            newLimits = obj.DragStartViewLimits + ...
                [deltaData(1), deltaData(1); deltaData(2), deltaData(2)];
            obj.applyViewFromUser(newLimits)
        end

        function stopDrag(obj)
            if ~isempty(obj.DragMotionListener)
                delete(obj.DragMotionListener)
                obj.DragMotionListener = [];
            end
            if ~isempty(obj.DragReleaseListener)
                delete(obj.DragReleaseListener)
                obj.DragReleaseListener = [];
            end
        end

        function onFrameClicked(obj)
            clickPoint = obj.CanvasAxes.CurrentPoint(1, 1:2);
            [x, y] = obj.localToData(clickPoint);
            obj.centerViewOn(x, y)
        end

        function applyViewFromUser(obj, newLimits)
        %applyViewFromUser Clamp to the data extent, update and notify

            for dim = 1:2
                overshoot = max(0, obj.DataLimits(dim,1) - newLimits(dim,1)) ...
                    - max(0, newLimits(dim,2) - obj.DataLimits(dim,2));
                newLimits(dim,:) = newLimits(dim,:) + overshoot;
            end

            if isequal(newLimits, obj.ViewLimits); return; end

            obj.ViewLimits = newLimits;

            if ~isempty(obj.ViewChangedFcn)
                evtData = uim.event.EventData(...
                    'XLim', newLimits(1,:), 'YLim', newLimits(2,:));
                obj.ViewChangedFcn(obj, evtData)
            end
        end
    end

    methods (Access = protected)

        function onStyleChanged(obj)
            onStyleChanged@uim.abstract.Component(obj)

            if obj.IsConstructed && ~isempty(obj.FrameHandle)
                obj.FrameHandle.EdgeColor = obj.FrameColor;
                obj.ViewRectHandle.EdgeColor = obj.ViewRectColor;
                obj.ViewRectHandle.FaceColor = obj.ViewRectColor;
            end
        end

        function onSizeChanged(obj, oldPosition, newPosition)
            onSizeChanged@uim.abstract.Control(obj, oldPosition, newPosition)
            obj.updateGraphics()
        end

        function relocate(obj, shift)
            relocate@uim.abstract.Control(obj, shift)
            obj.updateGraphics()
        end
    end

    methods (Static)

        function S = getTypeDefaults()
            S.IsFixedSize = [true, true];
            S.Size = [120, 90];
            S.Padding = [6, 6, 6, 6];
            % Dark chip chrome so the outline is visible on any plot.
            S.BackgroundColor = 'k';
            S.BackgroundAlpha = 0.3;
            S.CornerRadius = 3;
        end
    end
end
