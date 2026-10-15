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
            newYLim = uim.interface.internal.stretchLimits(...
                obj.Axes.YLim, deltaY, obj.Axes.Position(4));
            obj.setNewYLims(newYLim)

% %             if switchYAxis % Switch back...
% %                 yyaxis(obj.ax, currentYAxisLocation)
% %                 currentYAxisLocation
% %             end
        end

        function dragXLimits(obj)

            currentPoint = obj.Figure.CurrentPoint;
            deltaX = currentPoint(1) - obj.PreviousMousePoint(1);
            newXLim = uim.interface.internal.stretchLimits(...
                obj.Axes.XLim, deltaX, obj.Axes.Position(3));
            obj.setNewXLims(newXLim)
        end
    end

    methods (Access = private)

        function setNewXLims(obj, newLimits)
        % setNewXLims Set axes XLim, clamped to the original limits

            newLimits = uim.interface.internal.intersectRanges(newLimits, obj.XLimOrig);
            set(obj.Axes, 'XLim', newLimits);
        end

        function setNewYLims(obj, newLimits)
        % setNewYLims Set axes YLim, clamped to the original limits

            newLimits = uim.interface.internal.intersectRanges(newLimits, obj.YLimOrig);
            set(obj.Axes, 'YLim', newLimits);
        end
    end
end
