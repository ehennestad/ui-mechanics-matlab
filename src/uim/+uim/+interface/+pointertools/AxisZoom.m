classdef AxisZoom < uim.interface.PointerTool
%AxisZoom Pointer tool for stretching the x or y limits by dragging
%
%   tool = uim.interface.pointertools.AxisZoom(hAxes) creates the tool for
%   hAxes. The axes limits at construction become XLimOrig and YLimOrig,
%   which the stretched limits never exceed. A PointerManager creates the
%   tool for the key "axisZoom".
%
%   The tool provides the stretch operations, and the host drives them:
%     - A left press records the pointer position in
%       PreviousMouseClickPoint and PreviousMousePoint. The tool does not
%       update PreviousMousePoint during the drag.
%     - Each motion while the button is down calls the host's
%       ButtonMotionFcn(shift), with shift the pointer position minus
%       PreviousPoint, the point of the last motion the tool handled.
%       The press does not reset PreviousPoint. Without a
%       ButtonMotionFcn a drag raises an error.
%     - dragXLimits() and dragYLimits(location) stretch the limits by
%       the pointer distance from PreviousMousePoint.
%   Pointer positions and distances are in pixels, whatever the figure
%   and axes Units are. CurrentAxis ('x' or 'y') selects the pointer
%   symbol. Right-button presses are ignored.
%
%   ExitMode is 'previous'.
%
%   See also uim.interface.pointertools.Pan, uim.interface.PointerManager

%   TODO:
%       [ ] Options for syncing two axis (if axes has dual axis along the
%           dimensions)

    properties (Constant)
        ExitMode = 'previous'; % On toggle-off, PointerManager makes the suspended previous tool current
    end

    properties
        XLimOrig % [min, max] x bounds for the stretched limits, taken from the axes at construction
        YLimOrig % [min, max] y bounds for the stretched limits, taken from the axes at construction

        ConstrainX = true; % Not used
        ConstrainY = true; % Not used

        % Axis being dragged: 'x' (pointer 'left'), 'y' (pointer 'top'),
        % or '' (pointer unchanged)
        CurrentAxis = ''

        % Pointer position in pixels at the last motion handled during a drag
        PreviousPoint (1,2) double = [nan, nan] % Todo: Should be property of pointermanager, or at least super class...???
        IsButtonDown (1,1) logical = false % True between a left press and its release

        PreviousMouseClickPoint   % Pointer position in pixels where the mouse was last clicked
        PreviousMousePoint % Reference point for dragXLimits and dragYLimits, in pixels
    end

    properties (Access = private)
        % True while onButtonMotion handles a motion; motion events that
        % arrive meanwhile are dropped
        IsHandlingMotion (1,1) logical = false
    end

    methods

        function obj = AxisZoom(hAxes)
        %AxisZoom Create the tool for an axes
        %
        %   tool = uim.interface.pointertools.AxisZoom(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
        %setPointerSymbol Set the figure pointer for the axis in CurrentAxis
            switch obj.CurrentAxis
                case 'y'
                    obj.Figure.Pointer = 'top';
                case 'x'
                    obj.Figure.Pointer = 'left';
                otherwise
                    % Should be manages elsewhere
            end
        end

        function onButtonDown(obj, ~, evt)
        %onButtonDown Record the press point for a drag

            if evt.Button == 3; return; end

            if strcmp(obj.Figure.SelectionType, 'normal')
                obj.IsButtonDown = true;
                obj.PreviousMouseClickPoint = obj.getCurrentPointInPixels();
                obj.PreviousMousePoint = obj.PreviousMouseClickPoint;
            end

            obj.IsActive = true;
        end

        function onButtonMotion(obj, ~, ~)
        %onButtonMotion Call ButtonMotionFcn(shift) while dragging

            if obj.IsButtonDown
                if obj.IsHandlingMotion
                    return
                end
                obj.IsHandlingMotion = true;
                currentPoint = obj.getCurrentPointInPixels();
                shift = currentPoint - obj.PreviousPoint;

                % Clear the flag even if ButtonMotionFcn errors, so the
                % next motion is handled
                try
                    if ~isempty(obj.ButtonMotionFcn)
                        obj.ButtonMotionFcn(shift)
                    else
                        error('Not implemented')
                        % moveAxes(obj, shift) Possibly referring to method in
                        % uim.interface.pointertools.Pan?
                    end
                catch ME
                    obj.IsHandlingMotion = false;
                    rethrow(ME)
                end

                obj.PreviousPoint = currentPoint;
                obj.IsHandlingMotion = false;
            end
        end

        function onButtonUp(obj, ~, ~)
        %onButtonUp End the drag
            obj.IsButtonDown = false;
            obj.PreviousMouseClickPoint = [];
            obj.IsActive = false;
        end

        function dragYLimits(obj, location)
        %dragYLimits Stretch YLim by the vertical pointer distance
        %
        %   tool.dragYLimits(location) moves both ends of YLim outwards by
        %   the fraction dy/h of the current height, where dy is the
        %   vertical distance from PreviousMousePoint to the pointer and h
        %   is the axes height, both in pixels. Dragging up widens the
        %   limits and dragging down narrows them. The result is clipped
        %   to YLimOrig.
        %
        %   location is 'left' or 'right'. When it differs from the axes
        %   YAxisLocation, the method calls yyaxis(hAxes, location) first,
        %   which gives a plain axes a second y-axis.

            currentPoint = obj.getCurrentPointInPixels();
            axesPosition = getpixelposition(obj.Axes);

            currentYAxisLocation = obj.Axes.YAxisLocation;
            switchYAxis = ~strcmp(currentYAxisLocation, location);

            if switchYAxis
                yyaxis(obj.Axes, location)
            end

            deltaY = currentPoint(2) - obj.PreviousMousePoint(2);
            newYLim = uim.geometry.internal.stretchLimits(...
                obj.Axes.YLim, deltaY, axesPosition(4));
            obj.setNewYLims(newYLim)

% %             if switchYAxis % Switch back...
% %                 yyaxis(obj.ax, currentYAxisLocation)
% %                 currentYAxisLocation
% %             end
        end

        function dragXLimits(obj)
        %dragXLimits Stretch XLim by the horizontal pointer distance
        %
        %   tool.dragXLimits() moves both ends of XLim outwards by the
        %   fraction dx/w of the current width, where dx is the horizontal
        %   distance from PreviousMousePoint to the pointer and w is the
        %   axes width, both in pixels. Dragging right widens the limits
        %   and dragging left narrows them. The result is clipped to
        %   XLimOrig.

            currentPoint = obj.getCurrentPointInPixels();
            axesPosition = getpixelposition(obj.Axes);
            deltaX = currentPoint(1) - obj.PreviousMousePoint(1);
            newXLim = uim.geometry.internal.stretchLimits(...
                obj.Axes.XLim, deltaX, axesPosition(3));
            obj.setNewXLims(newXLim)
        end
    end

    methods (Access = private)

        function setNewXLims(obj, newLimits)
        % setNewXLims Set axes XLim, clamped to the original limits

            newLimits = uim.geometry.intersectRanges(newLimits, obj.XLimOrig);
            set(obj.Axes, 'XLim', newLimits);
        end

        function setNewYLims(obj, newLimits)
        % setNewYLims Set axes YLim, clamped to the original limits

            newLimits = uim.geometry.intersectRanges(newLimits, obj.YLimOrig);
            set(obj.Axes, 'YLim', newLimits);
        end
    end
end
