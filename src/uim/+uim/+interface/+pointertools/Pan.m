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

            % Get ax position in figure coordinates
            axPos = getpixelposition(obj.Axes);

            if strcmp(obj.Axes.YDir, 'reverse')
                shift(2) = -1 * shift(2);
            end

            % Get current axes limits
            xlim = obj.Axes.XLim;
            ylim = obj.Axes.YLim;

            % Convert mouse shift to image shift
            imshift = shift ./ axPos(3:4) .* [diff(xlim), diff(ylim)];
            xlim = xlim - imshift(1);
            ylim = ylim - imshift(2);

            % Dont move outside of image boundaries..
            if xlim(1) > obj.XLimOrig(1) && xlim(2) < obj.XLimOrig(2)
                set(obj.Axes, 'XLim', xlim);
%                 plotZoomRegion(obj, xlim, obj.Axes.YLim)
            elseif ~obj.ConstrainX
                set(obj.Axes, 'XLim', xlim);
            end

            if ylim(1) > obj.YLimOrig(1) && ylim(2) < obj.YLimOrig(2)
                set(obj.Axes, 'YLim', ylim);
            elseif ~obj.ConstrainY
                set(obj.Axes, 'YLim', ylim);
%                 plotZoomRegion(obj, obj.Axes.XLim, ylim)
            end
        end
    end
end
