classdef Pan < uim.interface.PointerTool
%Pan Pointer tool that moves the view by dragging
%
%   tool = uim.interface.pointertools.Pan(hAxes) creates the tool for
%   hAxes. The axes limits at construction become XLimOrig and YLimOrig,
%   the bounds for panning, so set the limits to the full view first. A
%   PointerManager creates the tool for the key "pan".
%
%   Dragging with the left button moves the axes limits so the content
%   follows the pointer. The pointer movement is read from the figure
%   CurrentPoint, in the figure's Units, and converted with the axes
%   size in pixels, so the content follows the pointer only when the
%   figure Units are pixels. With ConstrainX (ConstrainY) true, a step
%   that would bring the x (y) limits to or past XLimOrig (YLimOrig) is
%   skipped on that axis. Right-button presses are ignored.
%
%   A host can take over the drag by setting ButtonMotionFcn, which is
%   called as ButtonMotionFcn(shift) on each motion with the pointer
%   movement [dx, dy] since the last motion, in figure units. The tool
%   then does not move the limits.
%
%   ExitMode is 'previous'.
%
%   See also uim.interface.PointerManager, uim.interface.pointertools.ZoomIn

    properties (Constant)
        ExitMode = 'previous'; % On toggle-off, PointerManager makes the suspended previous tool current
    end

    properties
        XLimOrig % [min, max] x bounds for panning, taken from the axes at construction
        YLimOrig % [min, max] y bounds for panning, taken from the axes at construction

        ConstrainX = true; % If true, keep the x limits strictly inside XLimOrig
        ConstrainY = true; % If true, keep the y limits strictly inside YLimOrig

        PreviousPoint (1,2) double = [nan, nan] % Figure CurrentPoint at the last press or motion
        IsButtonDown (1,1) logical = false % True between a left press and its release
    end

    properties (Access = private)
        % True while onButtonMotion handles a motion; motion events that
        % arrive meanwhile are dropped
        IsHandlingMotion (1,1) logical = false
    end

    methods

        function obj = Pan(hAxes)
        %Pan Create the tool for an axes
        %
        %   tool = uim.interface.pointertools.Pan(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
        %setPointerSymbol Set the figure pointer to a hand
            setptr(obj.Figure, 'hand');
        end

        function onButtonDown(obj, ~, evt)
        %onButtonDown Start a drag at the pointer

            if evt.Button == 3; return; end

            obj.IsButtonDown = true;
            obj.IsActive = true;

            obj.PreviousPoint = obj.Figure.CurrentPoint;
        end

        function onButtonMotion(obj, ~, ~)
        %onButtonMotion Move the view, or call ButtonMotionFcn, while dragging

            if obj.IsButtonDown
                if obj.IsHandlingMotion
                    return
                end
                obj.IsHandlingMotion = true;
                currentPoint = obj.Figure.CurrentPoint;
                shift = currentPoint - obj.PreviousPoint;

                % Clear the flag even if ButtonMotionFcn errors, so the
                % next motion is handled
                try
                    if ~isempty(obj.ButtonMotionFcn)
                        obj.ButtonMotionFcn(shift)
                    else
                        moveAxes(obj, shift)
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
            obj.IsActive = false;
        end

        function moveAxes(obj, shift)
        %moveAxes Move the axes limits by a pointer movement
        %
        %   tool.moveAxes(shift) moves the limits so the content follows a
        %   pointer movement shift = [dx, dy] in pixels, honouring
        %   ConstrainX and ConstrainY.

            axPos = getpixelposition(obj.Axes);

            [xLim, yLim] = uim.geometry.internal.panLimits(...
                obj.Axes.XLim, obj.Axes.YLim, shift, axPos(3:4), obj.Axes.YDir);

            % Dont move outside of image boundaries..
            if ~obj.ConstrainX || ...
                    uim.geometry.internal.isRangeStrictlyInside(xLim, obj.XLimOrig)
                set(obj.Axes, 'XLim', xLim);
            end

            if ~obj.ConstrainY || ...
                    uim.geometry.internal.isRangeStrictlyInside(yLim, obj.YLimOrig)
                set(obj.Axes, 'YLim', yLim);
            end
        end
    end
end
