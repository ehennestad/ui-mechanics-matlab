classdef OverviewIndicator < uim.abstract.Control
%OverviewIndicator An interactive zoom outline for a zoomable view
%
%   indicator = uim.widget.OverviewIndicator(hParent, Name=Value)
%   creates a small overview chip showing the full data extent as a
%   frame and the currently visible region as a draggable rectangle.
%   hParent is typically a data axes, in which case the chip is drawn in
%   the overlay canvas over that axes; a uim.UIComponentCanvas also
%   works. Name-value arguments set public properties, including the
%   layout properties inherited from uim.abstract.Component such as
%   Location, Margin and Size.
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
%   Use YDir="reverse" when the target axes displays images, so the
%   outline is oriented like the image.
%
%   The widget box hugs the data-extent frame: Size (default [120, 90]
%   pixels) acts as a maximum, and the box shrinks along one dimension
%   when the data aspect ratio differs from the box aspect ratio.
%
%   Example:
%       imagesc(hAxes, imageData)
%       indicator = uim.widget.OverviewIndicator(hAxes, ...
%           Location="southeast", YDir="reverse", ...
%           DataLimits=[hAxes.XLim; hAxes.YLim], ...
%           ViewLimits=[hAxes.XLim; hAxes.YLim], ...
%           ViewChangedFcn=@(src, evt) set(hAxes, ...
%               XLim=evt.XLim, YLim=evt.YLim));
%
%   See also uim.UIComponentCanvas, uim.abstract.Control

    properties (Constant) % Inherited from Component
        Type = 'OverviewIndicator' % Component type name
    end

    properties
        DataLimits (2,2) double = [0, 1; 0, 1]  % Full extent: [xMin, xMax; yMin, yMax]
        ViewLimits (2,2) double = [0, 1; 0, 1]  % Visible region: [xMin, xMax; yMin, yMax]

        % "normal" draws y upwards; "reverse" draws y downwards, as in an
        % axes showing an image
        YDir (1,:) char {mustBeMember(YDir, {'normal', 'reverse'})} = 'normal'

        ViewChangedFcn = []     % Fired when the user moves the view. (src, uim.event.EventData with XLim/YLim)

        % Colors are applied when the outlines are created and whenever a
        % style property such as BackgroundColor changes.
        FrameColor = 'w'        % Edge color of the data-extent frame
        ViewRectColor = 'w'     % Edge/fill color of the view rectangle
    end

    properties (Access = protected, Transient)
        FrameHandle = gobjects(0,1)
        ViewRectHandle = gobjects(0,1)

        % Data-to-widget mapping, updated on every redraw
        LocalScale (1,1) double = 1     % Pixels per data unit
        FrameOrigin (1,2) double = [0, 0]

        % Size as configured by the host: the letterbox fit treats it
        % as a maximum, so the box can grow back after shrinking when
        % the data aspect ratio changes again.
        ConfiguredSize (1,2) double = [1, 1]

        % Guards ConfiguredSize while updateGraphics itself writes Size.
        IsFittingSize (1,1) logical = false

        % Drag state
        DragStartPoint (1,2) double = [0, 0]
        DragStartViewLimits (2,2) double = [0, 1; 0, 1]
        DragMotionListener
        DragReleaseListener
    end

    methods % Structors

        function obj = OverviewIndicator(hParent, propertyValues)
        %OverviewIndicator Create the overview chip in an axes, canvas or container
        %
        %   indicator = uim.widget.OverviewIndicator(hParent, Name=Value)

            arguments
                hParent
                propertyValues.?uim.widget.OverviewIndicator
            end

            obj@uim.abstract.Control(hParent, propertyValues)

            % View-rect drags read CurrentPoint from motion listeners; in
            % java figures that requires a WindowButtonMotionFcn.
            uim.internal.ensurePointerMotionTracking(...
                ancestor(obj.CanvasAxes, 'figure'))

            obj.ConfiguredSize = obj.Position(3:4);

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
        %
        %   indicator.centerViewOn(x, y) moves ViewLimits so the view, at
        %   its current size, is centered on (x, y) in data units, then
        %   shifts it to stay inside DataLimits. When the limits change it
        %   calls ViewChangedFcn, like a click in the frame does.

            viewSize = diff(obj.ViewLimits, 1, 2);
            newLimits = uim.geometry.centeredLimits([x, y], viewSize');
            obj.applyViewFromUser(newLimits)
        end
    end

    methods % Set/Get

        function set.DataLimits(obj, newValue)
            obj.DataLimits = newValue;
            obj.updateGraphics()
        end

        function set.ViewLimits(obj, newValue)
            % The recommended host wiring echoes ViewLimits back through
            % an XLim/YLim PostSet listener; skip the redundant redraw.
            if isequal(newValue, obj.ViewLimits); return; end
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

            % Fit the data extent inside the configured (maximum) box,
            % preserving the data aspect ratio (letterboxed when they
            % differ).
            paddingSize = obj.Padding(1:2) + obj.Padding(3:4);
            maxInnerSize = max(obj.ConfiguredSize - paddingSize, 0);

            [obj.LocalScale, frameSize] = uim.geometry.letterboxFit(...
                dataSize', maxInnerSize);

            % Shrink the widget box to hug the letterboxed frame, so the
            % chip background does not extend past the outline. The fit
            % is computed from ConfiguredSize, never from the already
            % fitted box, so a later DataLimits push can grow the box
            % back up to the configured maximum. The box re-anchors
            % through set.Size and this method runs again with the
            % fitted size.
            targetSize = frameSize + paddingSize;
            if any(abs(targetSize - obj.Position(3:4)) > 0.5)
                obj.IsFittingSize = true;
                restoreFlag = onCleanup(@() obj.stopFittingSize());
                obj.Size = targetSize;
                delete(restoreFlag)
                return
            end

            innerOrigin = obj.Position(1:2) + obj.Padding(1:2);
            innerSize = obj.Position(3:4) - paddingSize;
            obj.FrameOrigin = innerOrigin + (innerSize - frameSize)/2;

            [frameX, frameY] = obj.dataToLocal(...
                obj.DataLimits(1, [1, 2, 2, 1]), obj.DataLimits(2, [1, 1, 2, 2]));
            set(obj.FrameHandle, 'XData', frameX, 'YData', frameY)

            [viewX, viewY] = obj.dataToLocal(...
                obj.ViewLimits(1, [1, 2, 2, 1]), obj.ViewLimits(2, [1, 1, 2, 2]));
            set(obj.ViewRectHandle, 'XData', viewX, 'YData', viewY)
        end

        function [xLocal, yLocal] = dataToLocal(obj, xData, yData)
        %dataToLocal Convert data coordinates to canvas-local pixels
            [xLocal, yLocal] = uim.widget.internal.mapDataToFrame(...
                xData, yData, obj.DataLimits, obj.FrameOrigin, ...
                obj.LocalScale, obj.YDir);
        end

        function [x, y] = localToData(obj, localPoint)
        %localToData Convert a canvas-local pixel point to data coordinates
            [x, y] = uim.widget.internal.mapFrameToData(localPoint, ...
                obj.DataLimits, obj.FrameOrigin, obj.LocalScale, obj.YDir);
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

            % A press can arrive before the previous drag's release, for
            % example after a release outside the figure. Its listeners
            % live as long as the figure, so end that drag first.
            obj.stopDrag()

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

        function stopFittingSize(obj)
            if isvalid(obj)
                obj.IsFittingSize = false;
            end
        end

        function applyViewFromUser(obj, newLimits)
        %applyViewFromUser Shift the view inside the data extent, update and notify

            newLimits = uim.geometry.internal.shiftLimitsInside(...
                newLimits, obj.DataLimits);

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

            % A host-driven size is the new maximum for the letterbox
            % fit; the internal hug-fit must not ratchet it down.
            if ~obj.IsFittingSize
                obj.ConfiguredSize = newPosition(3:4);
            end

            obj.updateGraphics()
        end

        function relocate(obj, shift)
            relocate@uim.abstract.Control(obj, shift)
            obj.updateGraphics()
        end
    end

    methods (Static)

        function S = getTypeDefaults()
        %getTypeDefaults Default property values for this component type
        %
        %   S = uim.widget.OverviewIndicator.getTypeDefaults() returns a
        %   struct of property values used at construction: a fixed size
        %   of [120, 90] pixels, 6 pixel padding and a translucent black
        %   background. A name-value pair for the same property replaces
        %   the default.
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
