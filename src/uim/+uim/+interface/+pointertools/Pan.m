classdef Pan < uim.interface.PointerTool

    properties (Constant)
        ExitMode = 'previous';
    end

    properties
        XLimOrig
        YLimOrig

        ConstrainX = true;
        ConstrainY = true;

        PreviousPoint (1,2) double = [nan, nan]
        IsButtonDown (1,1) logical = false
    end

    methods

        function obj = Pan(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
            setptr(obj.Figure, 'hand');
        end

        function onButtonDown(obj, ~, evt)

            if evt.Button == 3; return; end

            obj.IsButtonDown = true;
            obj.IsActive = true;

            obj.PreviousPoint = obj.Figure.CurrentPoint;
        end

        function onButtonMotion(obj, ~, ~)

            persistent isBusy
            if isempty(isBusy); isBusy=false; end

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
                    moveAxes(obj, shift)
                end

                %moveAxes(obj, shift)

                obj.PreviousPoint = currentPoint;
                isBusy = false;
            end
        end

        function onButtonUp(obj, ~, ~)
            obj.IsButtonDown = false;
            obj.IsActive = false;
        end

        function moveAxes(obj, shift)
        % Move image in ax according to shift

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
