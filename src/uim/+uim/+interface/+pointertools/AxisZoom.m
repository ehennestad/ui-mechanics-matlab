classdef AxisZoom < uim.interface.PointerTool
%
%   Tool for changing limits of axis (XLim or YLim) by dragging the axis.

%   TODO:
%       [ ] Options for constraining zoom to original limits (implement)
%       [ ] Options for syncing two axis (if axes has dual axis along the
%           dimensions)

    properties (Constant)
        ExitMode = 'previous';
    end

    properties
        XLimOrig
        YLimOrig

        ConstrainX = true;
        ConstrainY = true;

        CurrentAxis = ''

        PreviousPoint (1,2) double = [nan, nan] % Todo: Should be property of pointermanager, or at least super class...???
        IsButtonDown (1,1) logical = false

        PreviousMouseClickPoint   % Point where mouse was last clicked
        PreviousMousePoint
    end

    methods

        function obj = AxisZoom(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
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

            if evt.Button == 3; return; end

            if strcmp(obj.Figure.SelectionType, 'normal')
                obj.IsButtonDown = true;
                obj.PreviousMouseClickPoint = obj.Figure.CurrentPoint;
                obj.PreviousMousePoint = obj.Figure.CurrentPoint;
            end

            obj.IsActive = true;
        end

        function onButtonMotion(obj, ~, ~)

            persistent isBusy
            if isempty(isBusy); isBusy = false; end

            if obj.IsButtonDown
                if isBusy
                    return
                end
                isBusy = true;
                currentPoint = obj.Figure.CurrentPoint;
                shift = currentPoint - obj.PreviousPoint;

                if ~isempty(obj.ButtonMotionFcn)
                    obj.ButtonMotionFcn(shift)
                else
                    isBusy = false;
                    error('Not implemented')
                    % moveAxes(obj, shift) Possibly referring to method in
                    % uim.interface.pointertools.Pan?
                end

                obj.PreviousPoint = currentPoint;
                isBusy = false;
            end
        end

        function onButtonUp(obj, ~, ~)
            obj.IsButtonDown = false;
            obj.PreviousMouseClickPoint = [];
            obj.IsActive = false;
        end

        function dragYLimits(obj, location)

            currentPoint = obj.Figure.CurrentPoint;

            currentYAxisLocation = obj.Axes.YAxisLocation;
            switchYAxis = ~strcmp(currentYAxisLocation, location);

            if switchYAxis
                yyaxis(obj.Axes, location)
            end

            deltaY = currentPoint(2) - obj.PreviousMousePoint(2);
            deltaY = deltaY / obj.Axes.Position(4);

            yLimRange = uim.utility.range(obj.Axes.YLim);
            yLimDiff = yLimRange .* deltaY;

            newYLim = [obj.Axes.YLim(1)-yLimDiff, obj.Axes.YLim(2)+yLimDiff];
            obj.setNewYLims(newYLim)

% %             if switchYAxis % Switch back...
% %                 yyaxis(obj.ax, currentYAxisLocation)
% %                 currentYAxisLocation
% %             end
        end

        function dragXLimits(obj)

            currentPoint = obj.Figure.CurrentPoint;
            deltaX = currentPoint(1) - obj.PreviousMousePoint(1);
            deltaX = deltaX / obj.Axes.Position(3);

            xLimRange = uim.utility.range(obj.Axes.XLim);
            xLimDiff = xLimRange .* deltaX;

            newXLim = [obj.Axes.XLim(1)-xLimDiff, obj.Axes.XLim(2)+xLimDiff];
            obj.setNewXLims(newXLim)
        end
    end

    methods (Access = private)

        function setNewXLims(obj, newLimits)
        % setNewXLims Set axes XLim, clamped to the original limits

            newLimits(1) = max([obj.XLimOrig(1), newLimits(1)]);
            newLimits(2) = min([obj.XLimOrig(2), newLimits(2)]);

            set(obj.Axes, 'XLim', newLimits);
        end

        function setNewYLims(obj, newLimits)
        % setNewYLims Set axes YLim, clamped to the original limits

            newLimits(1) = max([obj.YLimOrig(1), newLimits(1)]);
            newLimits(2) = min([obj.YLimOrig(2), newLimits(2)]);

            set(obj.Axes, 'YLim', newLimits);
        end
    end
end
