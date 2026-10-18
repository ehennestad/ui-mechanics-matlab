classdef DataCursor < uim.interface.PointerTool
%DataCursor Pointer tool that shows a crosshair following the pointer
%
%   tool = uim.interface.pointertools.DataCursor(hAxes) creates the tool
%   for hAxes. The crosshair lines span the axes limits at construction
%   (XLimOrig and YLimOrig). A PointerManager creates the tool for the
%   key "dataCursor".
%
%   activate shows the crosshair at the pointer, or at the centre of the
%   axes when the pointer is outside it. While the tool is active, every
%   pointer motion inside the axes moves the crosshair to the pointer
%   and then calls CursorMovedFcn. suspend and deactivate hide the
%   crosshair. Mouse presses do nothing else.
%
%   The crosshair is drawn with plot, so the axes must be held
%   (PointerManager holds it).
%
%   ExitMode is 'default': a 'previous' tool such as ZoomIn suspends it
%   while on, and it becomes current again when that tool turns off.
%
%   See also uim.interface.PointerManager

    % Todo:
    %   1) Implement different modes.
    %       I.e should it show data of a line? or an image? or just the
    %       coordinates of the axes...?
    %   2) Implement different plot styles.
    %   3) Should it work on mouseover, or only on button click?

    properties (Constant)
        ExitMode = 'default'; % On toggle-off, PointerManager makes the manager's DefaultPointerTool current
    end

    properties
        XLimOrig % [min, max] x extent of the horizontal line, taken from the axes at construction
        YLimOrig % [min, max] y extent of the vertical line, taken from the axes at construction
        CursorColor = ones(1,3)*0.5 % Crosshair color, an RGB triplet or color name

        % Fired on every cursor movement while the tool is active, after
        % the crosshair is updated. (src, evt) pass through from the
        % window motion event; read the position from the axes
        % CurrentPoint. Hosts use this to display information about the
        % data under the cursor.
        CursorMovedFcn = []
    end

    properties (Access = private)
        IsButtonDown = false
        Crosshair % Line handle for temporary lines of data cursor crosshair
    end

    methods

        function delete(obj)
            delete(obj.Crosshair(isgraphics(obj.Crosshair)))
        end

        function obj = DataCursor(hAxes)
        %DataCursor Create the tool for an axes
        %
        %   tool = uim.interface.pointertools.DataCursor(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function activate(obj)
        %activate Turn the tool on and show the crosshair
            activate@uim.interface.PointerTool(obj)
            obj.plotCrosshair()

            set(obj.Crosshair, 'Visible', 'on')
            obj.IsActive = true;
        end

        function suspend(obj)
        %suspend Put the tool on hold and hide the crosshair
            suspend@uim.interface.PointerTool(obj)
            set(obj.Crosshair, 'Visible', 'off')
        end

        function deactivate(obj)
        %deactivate Turn the tool off and hide the crosshair
            deactivate@uim.interface.PointerTool(obj)
            set(obj.Crosshair, 'Visible', 'off')
            obj.IsActive = false;
        end

        function setPointerSymbol(obj)
        %setPointerSymbol Set the figure pointer to a circle
            obj.Figure.Pointer = 'circle';
        end

        function onButtonDown(obj, ~, ~)
        %onButtonDown Record that the button is down
            obj.IsButtonDown = true;
        end

        function onButtonMotion(obj, src, evt)
        %onButtonMotion Move the crosshair to the pointer and call CursorMovedFcn

            currentPoint = obj.Axes.CurrentPoint(1, 1:2);

            if ~obj.isPointerInsideAxes(currentPoint); return; end
            if ~obj.IsActive; return; end

            obj.plotCrosshair(currentPoint)

            if ~isempty(obj.CursorMovedFcn)
                obj.CursorMovedFcn(src, evt)
            end
        end

        function onButtonUp(obj, ~, ~)
        %onButtonUp Record that the button is up
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
                % The black outline lines 3 and 4 are created first so
                % that the thinner coloured lines 1 and 2 are drawn on top
                obj.Crosshair = gobjects(4,1);
                obj.Crosshair(3) = plot(hAx, xdata1, ydata1);
                obj.Crosshair(4) = plot(hAx, xdata2, ydata2);
                obj.Crosshair(1) = plot(hAx, xdata1, ydata1);
                obj.Crosshair(2) = plot(hAx, xdata2, ydata2);
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
            % Lines 3 and 4 are the black outline under the coloured lines
            % 1 and 2; line 5 is the centre dot
            if numel(obj.Crosshair) < 5; return; end
            set(obj.Crosshair([1, 2, 5]), 'Color', obj.CursorColor)
        end
    end
end
