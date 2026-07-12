classdef axisZoom < uim.interface.abstractPointer
%
%   Tool for changing limits of axis (XLim or YLim) by dragging the axis.

%   TODO:
%       [ ] Options for constraining zoom to original limits (implement)
%       [ ] Options for syncing two axis (if axes has dual axis along the
%           dimensions)

    properties (Constant)
        exitMode = 'previous';
    end

    properties
        xLimOrig
        yLimOrig

        constrainX = true;
        constrainY = true;

        CurrentAxis = ''

        previousPoint (1,2) double = [nan, nan] % Todo: Should be property of pointermanager, or at least super class...???
        isButtonDown (1,1) logical = false

        isMouseDown
        PreviousMouseClickPoint   % Point where mouse was last clicked
        PreviousMousePoint
    end

    methods

        function obj = axisZoom(hAxes)
            obj.hAxes = hAxes;
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;

            obj.hFigure = ancestor(hAxes, 'figure');
        end

        function setPointerSymbol(obj)
            switch obj.CurrentAxis
                case 'y'
                    obj.hFigure.Pointer = 'top';
                case 'x'
                    obj.hFigure.Pointer = 'left';
                otherwise
                    % Should be manages elsewhere
            end
        end

        function onButtonDown(obj, ~, evt)

            if evt.Button == 3; return; end

            if strcmp(obj.hFigure.SelectionType, 'normal')
                obj.isMouseDown = true;
                obj.PreviousMouseClickPoint = obj.hFigure.CurrentPoint;
                obj.PreviousMousePoint = obj.hFigure.CurrentPoint;
            end

            obj.isActive = true;
        end

        function onButtonMotion(obj, ~, ~)

            persistent isBusy
            if isempty(isBusy); isBusy = false; end

            if obj.isButtonDown
                if isBusy
                    return
                end
                isBusy = true;
                currentPoint = obj.hFigure.CurrentPoint;
                shift = currentPoint - obj.previousPoint;

                if ~isempty(obj.buttonMotionCallback)
                    obj.buttonMotionCallback(shift)
                else
                    isBusy = false;
                    error('Not implemented')
                    % moveAxes(obj, shift) Possibly referring to method in
                    % uim.interface.pointerTool.pan?
                end

                obj.previousPoint = currentPoint;
                isBusy = false;
            end
        end

        function onButtonUp(obj, ~, ~)
            obj.isMouseDown = false;
            obj.PreviousMouseClickPoint = [];
            obj.isActive = false;
        end

        function dragYLimits(obj, location)

            currentPoint = obj.hFigure.CurrentPoint;

            currentYAxisLocation = obj.hAxes.YAxisLocation;
            switchYAxis = ~strcmp(currentYAxisLocation, location);

            if switchYAxis
                yyaxis(obj.hAxes, location)
            end

            deltaY = currentPoint(2) - obj.PreviousMousePoint(2);
            deltaY = deltaY / obj.hAxes.Position(4);

            yLimRange = uim.utility.range(obj.hAxes.YLim);
            yLimDiff = yLimRange .* deltaY;

            newYLim = [obj.hAxes.YLim(1)-yLimDiff, obj.hAxes.YLim(2)+yLimDiff];
            obj.setNewYLims(newYLim)

% %             if switchYAxis % Switch back...
% %                 yyaxis(obj.ax, currentYAxisLocation)
% %                 currentYAxisLocation
% %             end
        end

        function dragXLimits(obj)

            currentPoint = obj.hFigure.CurrentPoint;
            deltaX = currentPoint(1) - obj.PreviousMousePoint(1);
            deltaX = deltaX / obj.hAxes.Position(3);

            xLimRange = uim.utility.range(obj.hAxes.XLim);
            xLimDiff = xLimRange .* deltaX;

            newXLim = [obj.hAxes.XLim(1)-xLimDiff, obj.hAxes.XLim(2)+xLimDiff];
            obj.setNewXLims(newXLim)
        end
    end

    methods (Access = private)

        function setNewXLims(obj, newLimits)
        % setNewXLims Set axes XLim, clamped to the original limits

            newLimits(1) = max([obj.xLimOrig(1), newLimits(1)]);
            newLimits(2) = min([obj.xLimOrig(2), newLimits(2)]);

            set(obj.hAxes, 'XLim', newLimits);
        end

        function setNewYLims(obj, newLimits)
        % setNewYLims Set axes YLim, clamped to the original limits

            newLimits(1) = max([obj.yLimOrig(1), newLimits(1)]);
            newLimits(2) = min([obj.yLimOrig(2), newLimits(2)]);

            set(obj.hAxes, 'YLim', newLimits);
        end
    end
end
