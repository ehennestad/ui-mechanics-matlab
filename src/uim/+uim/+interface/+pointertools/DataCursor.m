classdef DataCursor < uim.interface.PointerTool

    % Todo:
    %   1) Implement different modes.
    %       I.e should it show data of a line? or an image? or just the
    %       coordinates of the axes...?
    %   2) Implement different plot styles.
    %   3) Should it work on mouseover, or only on button click?

    properties (Constant)
        ExitMode = 'default';
    end

    properties
        XLimOrig
        YLimOrig
        CursorColor = ones(1,3)*0.5
    end

    properties (Access = private)
        IsButtonDown = false
        Crosshair % Line handle for temporary lines of data cursor crosshair
    end

    methods

        function obj = DataCursor(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function activate(obj)
            activate@uim.interface.PointerTool(obj)
            obj.plotCrosshair()

            set(obj.Crosshair, 'Visible', 'on')
            obj.IsActive = true;
        end

        function suspend(obj)
            suspend@uim.interface.PointerTool(obj)
            set(obj.Crosshair, 'Visible', 'off')
        end

        function deactivate(obj)
            deactivate@uim.interface.PointerTool(obj)
            set(obj.Crosshair, 'Visible', 'off')
            obj.IsActive = false;
        end

        function setPointerSymbol(obj)
            obj.Figure.Pointer = 'circle';
        end

        function onButtonDown(obj, ~, ~)
            obj.IsButtonDown = true;
        end

        function onButtonMotion(obj, src, evt)

            currentPoint = obj.Axes.CurrentPoint(1, 1:2);

            if ~obj.isPointerInsideAxes(currentPoint); return; end
            if ~obj.IsActive; return; end

            obj.plotCrosshair(currentPoint)

            if ~isempty(obj.ButtonMotionFcn)
            	obj.ButtonMotionFcn(src, evt)
            end
        end

        function onButtonUp(obj, ~, ~)
            obj.IsButtonDown = false;
        end

        function set.CursorColor(obj, newColor)
            obj.CursorColor = newColor;
            obj.updateCursorColor()
        end
    end

    methods (Access = private)

        function plotCrosshair(obj, center)

            hAx = obj.Axes;

            if nargin < 2 && ~obj.isPointerInsideAxes()
                y0 = mean(hAx.YLim);
                x0 = mean(hAx.XLim);
            elseif nargin < 2 && obj.isPointerInsideAxes()
                point = hAx.CurrentPoint(1,1:2);
                x0 = point(1);
                y0 = point(2);
            else
                x0 = center(1);%+1*ps/10;
                y0 = center(2);%+0;
            end

            xdata1 = obj.XLimOrig;
            ydata1 = ones(size(xdata1))*y0;

            ydata2 = obj.YLimOrig;
            xdata2 = ones(size(ydata2))*x0;

            % Plot Line
            if isempty(obj.Crosshair)
                obj.Crosshair = gobjects(4,1);
                obj.Crosshair(1) = plot(hAx, xdata1, ydata1);
                obj.Crosshair(2) = plot(hAx, xdata2, ydata2);
                obj.Crosshair(3) = plot(hAx, xdata1, ydata1);
                obj.Crosshair(4) = plot(hAx, xdata2, ydata2);
                set( obj.Crosshair(1:2), 'Color', obj.CursorColor)
                set( obj.Crosshair(1:2), 'LineWidth', 0.5)
                set( obj.Crosshair(3:4), 'Color', [0,0,0])
                set( obj.Crosshair(3:4), 'LineWidth', 1)

                set(obj.Crosshair, 'LineStyle', '--')
                set(obj.Crosshair, 'HitTest', 'off', 'PickableParts', 'none')

                obj.Crosshair(5) = plot(obj.Axes, x0, y0, '.', 'MarkerSize', 20);
                obj.Crosshair(5).Color =  obj.CursorColor;

            else
%                 set(obj.Crosshair, {'XData'}, {xdata1,xdata2}', ...
%                                     {'YData'}, {ydata1,ydata2}' )
                set(obj.Crosshair(1:4), {'XData'}, {xdata1,xdata2,xdata1,xdata2}', ...
                                    {'YData'}, {ydata1,ydata2,ydata1,ydata2}' )
                set(obj.Crosshair(5), 'XData', x0, 'YData', y0)
            end
        end

        function updateCursorColor(obj)
            set( obj.Crosshair, 'Color', obj.CursorColor)
        end
    end
end
