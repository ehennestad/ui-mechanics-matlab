classdef ZoomIn < uim.interface.PointerTool & uim.interface.Zoomable & ...
        uim.interface.pointertools.mixin.DraggableRectangle

    properties (Constant)
        ExitMode = 'previous';
    end

    properties % Tool specific
        ZoomInFcn
        RectangularZoomFcn
        RunDefault = false;
    end

    properties % Implement abstract properties from zoom
        ZoomFactor = 0.25
        XLimOrig
        YLimOrig
    end

    properties % Implement abstract properties hasDraggableRectangle
        AnchorPoint = [nan, nan]
        IsButtonDown = false
    end

    methods

        function obj = ZoomIn(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
            setptr(obj.Figure, 'glassplus');
        end

        function onButtonDown(obj, ~, evt)

            if evt.Button==3; return; end

            obj.IsButtonDown = true;
            obj.IsActive = true;

            obj.AnchorPoint = obj.Axes.CurrentPoint(1, 1:2);

            obj.plotRectangle()

            set(obj.Figure, 'Pointer', 'crosshair');
        end

        function onButtonMotion(obj, ~, ~)
            if obj.IsButtonDown
                obj.updateRectangle()
            end
        end

        function onButtonUp(obj, ~, ~)
            if ~obj.IsButtonDown; return; end % MouseDown happened before tool was activated

            obj.IsButtonDown = false;
            obj.IsActive = false;

            currentPoint = get(obj.Axes, 'CurrentPoint');
            currentPoint = currentPoint(1, 1:2);

            deltaErr = mean( [diff(obj.Axes.XLim),diff(obj.Axes.YLim) ] ) / 100;

            if all((abs(obj.AnchorPoint - currentPoint)) < deltaErr) % No movement
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
