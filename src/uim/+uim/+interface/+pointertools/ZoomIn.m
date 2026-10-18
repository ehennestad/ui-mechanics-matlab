classdef ZoomIn < uim.interface.PointerTool & uim.mixin.Zoomable & ...
        uim.interface.pointertools.mixin.DraggableRectangle
%ZoomIn Pointer tool that zooms in on a click or to a dragged rectangle
%
%   tool = uim.interface.pointertools.ZoomIn(hAxes) creates the tool for
%   hAxes. The axes limits at construction become XLimOrig and YLimOrig,
%   the outer bounds for every zoom, so set the limits to the full view
%   first. A PointerManager creates the tool for the key "zoomIn".
%
%   With the left mouse button:
%     - A click (press and release less than 1% of the mean axis range
%       apart) zooms in about the pointer: each end of the limits moves
%       in by ZoomFactor times the width.
%     - A drag draws a rectangle, and the release zooms to it.
%   The new limits are widened to the axes aspect ratio and kept inside
%   XLimOrig and YLimOrig, then ZoomFinishedFcn runs. Right-button
%   presses are ignored. The drag rectangle is drawn with plot, so the
%   axes must be held (PointerManager holds it).
%
%   A host can take over the zoom: ZoomInFcn() replaces the click zoom
%   and RectangularZoomFcn(xLim, yLim) replaces the rectangle zoom.
%   With RunDefault true the default zoom runs first.
%
%   ExitMode is 'previous'. The zoom methods (imageZoom,
%   setNewImageLimits, ...) come from uim.mixin.Zoomable.
%
%   See also uim.interface.pointertools.ZoomOut, uim.mixin.Zoomable,
%   uim.interface.PointerManager

    properties (Constant)
        ExitMode = 'previous'; % On toggle-off, PointerManager makes the suspended previous tool current
    end

    properties % Tool specific
        ZoomInFcn % Host callback ZoomInFcn() run on a click instead of the default zoom
        RectangularZoomFcn % Host callback RectangularZoomFcn(xLim, yLim) run on a drag instead of the default zoom
        RunDefault = false; % If true, run the default zoom before ZoomInFcn or RectangularZoomFcn
    end

    properties % Implement abstract properties from zoom
        ZoomFactor = 0.25 % Fraction of the width each limit moves in per click; 0.25 halves the view
        XLimOrig % [min, max] x bounds for zooming, taken from the axes at construction
        YLimOrig % [min, max] y bounds for zooming, taken from the axes at construction
    end

    properties % Implement abstract properties hasDraggableRectangle
        AnchorPoint = [nan, nan] % [x, y] press point in data units
        IsButtonDown = false % True between a left press and its release
    end

    methods

        function obj = ZoomIn(hAxes)
        %ZoomIn Create the tool for an axes
        %
        %   tool = uim.interface.pointertools.ZoomIn(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
        %setPointerSymbol Set the figure pointer to a magnifier with a plus
            setptr(obj.Figure, 'glassplus');
        end

        function onButtonDown(obj, ~, evt)
        %onButtonDown Start a click or a rectangle drag at the pointer

            if evt.Button==3; return; end

            obj.IsButtonDown = true;
            obj.IsActive = true;

            obj.AnchorPoint = obj.Axes.CurrentPoint(1, 1:2);

            obj.plotRectangle()

            set(obj.Figure, 'Pointer', 'crosshair');
        end

        function onButtonMotion(obj, ~, ~)
        %onButtonMotion Resize the drag rectangle while the button is down
            if obj.IsButtonDown
                obj.updateRectangle()
            end
        end

        function onButtonUp(obj, ~, ~)
        %onButtonUp Zoom in about the pointer (click) or to the rectangle (drag)
            if ~obj.IsButtonDown; return; end % MouseDown happened before tool was activated

            obj.IsButtonDown = false;
            obj.IsActive = false;

            currentPoint = get(obj.Axes, 'CurrentPoint');
            currentPoint = currentPoint(1, 1:2);

            isClick = uim.interface.internal.isClickWithoutDrag(...
                obj.AnchorPoint, currentPoint, obj.Axes.XLim, obj.Axes.YLim);

            if isClick
                % A small rectangle may have been drawn during the motion
                obj.resetRectangle();

                if ~isempty(obj.ZoomInFcn)
                    if obj.RunDefault
                        obj.imageZoom('in')
                    end
                    obj.ZoomInFcn()
                else
                    obj.imageZoom('in')
                end
                %obj.ButtonUpFcn();
            else
                newXLim = sort( [obj.AnchorPoint(1), currentPoint(1)] );
                newYLim = sort( [obj.AnchorPoint(2), currentPoint(2)] );

                obj.resetRectangle();

                if ~isempty( obj.RectangularZoomFcn )
                    if obj.RunDefault
                        obj.setNewImageLimits(newXLim, newYLim)
                    end
                    obj.RectangularZoomFcn(newXLim, newYLim);
                else
                    obj.setNewImageLimits(newXLim, newYLim)
                    % obj.ButtonUpFcn(newXLim, newYLim);
                end

%                 obj.imageZoomRect(); % Set new limits based on new and old point
            end

            obj.setPointerSymbol()
        end
    end
end
