classdef FrameMarker < uim.mixin.NameValueAssignable
%FrameMarker Draggable vertical line marking the current frame in a plot
%
%   marker = uim.widget.FrameMarker(hAxes, Name=Value) draws a vertical
%   line at x = Value in hAxes, with a downward triangle knob at its top
%   and an upward triangle knob at its bottom. The line spans y = 0 to
%   y = 1 in data units, so it reaches the edges of an axes with YLim
%   [0, 1]. Name-value arguments set the public properties of the same
%   name; other names are ignored.
%
%   Dragging either knob moves the line to the pointer x, clamped to
%   [Minimum, Maximum] and not rounded, and calls ValueChangedFcn on
%   every pointer move. Assigning Value moves the line without calling
%   ValueChangedFcn.
%
%   The parts are primitive lines with HandleVisibility "off", excluded
%   from data tips. Color, EdgeColor, LineWidth, MarkerSize and
%   MarkerSymbol set their appearance; a knob grows by 2 points and
%   lightens while the pointer is on it. Deleting the marker deletes its
%   lines.
%
%   Example:
%       hAxes = axes(figure, XLim=[1, 100], YLim=[0, 1]);
%       marker = uim.widget.FrameMarker(hAxes, Minimum=1, Maximum=100, ...
%           Value=20, ValueChangedFcn=@(src, evt) disp(evt.NewValue));
%       marker.Value = 50;

    % Todo
    % [ ] Create Interactive frame marker
    % [ ] Property to control axis , i.e x or y
    % [ ]

    properties
        Value = 1       % x position of the line in data units
        Minimum         % Lowest value a drag can set. Empty means no limit.
        Maximum         % Highest value a drag can set. Empty means no limit.

        % Called as fcn(src, evt) on every pointer move while a knob is
        % dragged. evt: uim.event.ValueChangedEventData (OldValue, NewValue)
        ValueChangedFcn
    end

    properties % Appearance
        Color = ones(1,3) * 0.4 % Colour of the line and the knobs
        EdgeColor = []          % Edge colour of the knobs; empty uses Color
        LineWidth = 1;          % Width of the line, in points
        MarkerSize = 10;        % Size of the knobs, in points
        % Marker of the top knob; the bottom knob uses the vertically
        % mirrored marker ('v' and '^' swap)
        MarkerSymbol = 'v'
    end

    properties (Access = public)
        Visible matlab.lang.OnOffSwitchState = 'on'     % Show ("on") or hide ("off") the line and knobs
    end

    properties (Access = private)
        ParentFigure
        Axes
        LineHandle
        TopButtonHandle
        BottomButtonHandle
    end

    properties (Access = private)
        IsButtonDown = false
        IsMouseOnButton = false
        IsConstructed = false
        WindowMouseMotionListener
        WindowMouseReleaseListener
    end

    properties (Access = private)
        YMin = 0
        YMax = 1
    end

    methods
        function obj = FrameMarker(hAxes, varargin)
        %FrameMarker Create a frame marker in an axes
        %
        %   marker = uim.widget.FrameMarker(hAxes, Name=Value)
            obj.Axes = hAxes;
            obj.ParentFigure = ancestor(hAxes, 'figure');
            % Knob drags read CurrentPoint from motion listeners; in
            % java figures that requires a WindowButtonMotionFcn.
            uim.internal.ensurePointerMotionTracking(obj.ParentFigure)
            obj.parseInputs(varargin{:})
            obj.drawFrameMarker()
            obj.IsConstructed = true;

            % drawFrameMarker lays the parts out at x = 1 and always
            % visible; apply the Value and Visible the caller asked for
            % (both setters skip drawing until IsConstructed is set).
            obj.updateFrameMarker()
            obj.onVisibleChanged()
        end
    end

    methods
        function delete(obj)
            obj.resetWindowMouseListeners()
            allHandles = [obj.LineHandle, obj.TopButtonHandle, obj.BottomButtonHandle];
            delete(allHandles(isgraphics(allHandles)))
        end
    end

    methods % Set/get
        function set.Color(obj, newValue)
            obj.Color = newValue;
            obj.onAppearanceChanged()
        end

        function set.EdgeColor(obj, newValue)
            obj.EdgeColor = newValue;
            obj.onAppearanceChanged()
        end

        function set.LineWidth(obj, newValue)
            obj.LineWidth = newValue;
            obj.onAppearanceChanged()
        end

        function set.MarkerSize(obj, newValue)
            obj.MarkerSize = newValue;
            obj.onAppearanceChanged()
        end

        function set.MarkerSymbol(obj, newValue)
            obj.MarkerSymbol = newValue;
            obj.onAppearanceChanged()
        end

        function set.Value(obj, newValue)
            obj.Value = newValue;
            obj.updateFrameMarker()
        end

        function set.Visible(obj, newValue)
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end
    end

    methods (Access = private)

        function drawFrameMarker(obj)

            % Keep hold on while creating the marker parts so a
            % caller-supplied axes with NextPlot 'replace' does not delete
            % the earlier parts as the later ones are plotted.
            wasHoldOn = ishold(obj.Axes);
            hold(obj.Axes, 'on')

            % Use primitive line objects (not plot/chart lines): the marker
            % lives in the caller's axes, and primitive lines carry no
            % DataTipTemplate, so clicking the draggable knobs can not pin
            % a data tip there.
            obj.LineHandle = line(obj.Axes, [1, 1], [0, 1], ...
                'LineStyle', '-', 'HitTest', 'off');

            obj.TopButtonHandle = line(obj.Axes, 1, 1, ...
                'LineStyle', 'none', 'HitTest', 'on');
            obj.TopButtonHandle.ButtonDownFcn = @obj.knobPressed;

            obj.BottomButtonHandle = line(obj.Axes, 1, 0, ...
                'LineStyle', 'none', 'HitTest', 'on');
            obj.BottomButtonHandle.ButtonDownFcn = @obj.knobPressed;

            if ~wasHoldOn
                hold(obj.Axes, 'off')
            end

            allHandles = [obj.LineHandle, obj.TopButtonHandle, obj.BottomButtonHandle];
            %obj.hlineCurrentFrame(2).LineStyle = '-';
            %obj.hlineCurrentFrame(2).MarkerEdgeColor = [0.2,0.2,0.2];

            set(allHandles, 'Tag', 'FrameMarker');
            set(allHandles, 'HandleVisibility', 'off')
            obj.applyAppearance()

            % The knobs keep HitTest on for dragging, so interactive
            % data tips are excluded per object.
            uim.internal.excludeFromDataTips(allHandles)

            obj.setPointerBehavior(obj.TopButtonHandle)
            obj.setPointerBehavior(obj.BottomButtonHandle)
        end

        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEnterSlider(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExitSlider(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.internal.setPointerBehavior(h, pointerBehavior)
        end

        function onVisibleChanged(obj)
        %onVisibleChanged Show or hide the marker line and both knobs

            if ~obj.IsConstructed; return; end

            allHandles = [obj.LineHandle, obj.TopButtonHandle, obj.BottomButtonHandle];
            set(allHandles(isvalid(allHandles)), 'Visible', obj.Visible)
        end

        function updateFrameMarker(obj, ~)
        % Update line indicating current frame in plot.

            if ~obj.IsConstructed; return; end

            xValue = obj.Value;

                %yLim = obj.ax.YAxis(1).Limits;

            allHandles = [obj.LineHandle, obj.TopButtonHandle, obj.BottomButtonHandle];

            yData = {[0,1], 1, 0};
            xData = {[xValue, xValue], xValue, xValue};
            set(allHandles, {'XData'}, xData', {'YData'}, yData')
        end

        function onAppearanceChanged(obj)
            if ~obj.IsConstructed; return; end
            obj.applyAppearance()
        end

        function applyAppearance(obj)
        %applyAppearance Apply the appearance properties to the line and knobs
            color = validatecolor(obj.Color);
            set(obj.LineHandle, 'Color', [color, 0.6], 'LineWidth', obj.LineWidth)

            knobs = [obj.TopButtonHandle, obj.BottomButtonHandle];
            if isempty(obj.EdgeColor)
                edgeColor = 'auto';
            else
                edgeColor = obj.EdgeColor;
            end
            set(knobs, 'Color', color, 'MarkerEdgeColor', edgeColor, ...
                'LineWidth', obj.LineWidth)
            obj.TopButtonHandle.Marker = obj.MarkerSymbol;
            obj.BottomButtonHandle.Marker = mirrorMarkerVertically(obj.MarkerSymbol);
            obj.setKnobHighlight(knobs, false)
        end

        function setKnobHighlight(obj, knobs, isHighlighted)
        %setKnobHighlight Show knobs as hovered (larger, lighter) or normal
            color = validatecolor(obj.Color);
            if isHighlighted
                set(knobs, 'MarkerFaceColor', color + (1 - color) / 6, ...
                    'MarkerSize', obj.MarkerSize + 2)
            else
                set(knobs, 'MarkerFaceColor', color, 'MarkerSize', obj.MarkerSize)
            end
        end

        function resetWindowMouseListeners(obj)

            if isvalid(obj) && ~isempty(obj.WindowMouseMotionListener)
                delete(obj.WindowMouseMotionListener)
                obj.WindowMouseMotionListener = [];
            end

            if isvalid(obj) && ~isempty(obj.WindowMouseReleaseListener)
                delete(obj.WindowMouseReleaseListener)
                obj.WindowMouseReleaseListener = [];
            end
        end
    end

    methods

        function onMouseEnterSlider(obj, h, varargin)
        %onMouseEnterSlider Enlarge a knob and show the hand pointer
        %
        %   marker.onMouseEnterSlider(h) is the pointer-enter callback the
        %   widget installs on each knob h.
            if isgraphics(h, 'patch')
                h.FaceColor = ones(1,3) * 0.8;
            elseif isgraphics(h, 'line') % Primitive or chart line
                obj.setKnobHighlight(h, true)
            end

            obj.IsMouseOnButton = true;
            obj.ParentFigure.Pointer = 'hand';
            drawnow
        end

        function onMouseExitSlider(obj, h, varargin)
        %onMouseExitSlider Restore a knob and the arrow pointer
        %
        %   marker.onMouseExitSlider(h) is the pointer-exit callback the
        %   widget installs on each knob h. During a drag it leaves the
        %   knob and the pointer as they are.
            if isgraphics(h, 'patch')
                h.FaceColor = ones(1,3) * 0.6;
            elseif isgraphics(h, 'line') % Primitive or chart line
                if ~obj.IsButtonDown
                    obj.setKnobHighlight(h, false)
                end
            end

            obj.IsMouseOnButton = false;
            if ~obj.IsButtonDown
                obj.ParentFigure.Pointer = 'arrow';
            end
        end

        % % % Callbacks for the scroller knob

        function knobPressed(obj, ~, ~)
        %knobPressed Start a drag of the marker
        %
        %   marker.knobPressed(src, evt) is the ButtonDownFcn of both
        %   knobs. It listens to pointer motion and release in the figure.

            el = listener(obj.ParentFigure, 'WindowMouseMotion', @obj.knobMoving);
            obj.WindowMouseMotionListener = el;

            el = listener(obj.ParentFigure, 'WindowMouseRelease', @obj.knobReleased);
            obj.WindowMouseReleaseListener = el;

            obj.IsButtonDown = true;
        end

        function knobMoving(obj, ~, ~)
        %knobMoving Move the marker to the pointer and notify the host
        %
        %   marker.knobMoving(src, evt) is the pointer-motion callback
        %   during a drag. It sets Value to the pointer x in the axes,
        %   clamped to [Minimum, Maximum], and calls ValueChangedFcn.

            if obj.IsButtonDown % Just in case???
                mousePoint = obj.Axes.CurrentPoint(1);
                xPoint = mousePoint(1);

                %newValue = round( obj.getSliderValue(xPoint) );
                newValue = xPoint;

                if newValue < obj.Minimum; newValue = obj.Minimum; end
                if newValue > obj.Maximum; newValue = obj.Maximum; end

                % Call guis changeFrame methods
                % is it better with event notification?

                oldValue = obj.Value;
                obj.Value = newValue;
                obj.updateFrameMarker()

                if ~isempty(obj.ValueChangedFcn)
                    evtData = uim.event.ValueChangedEventData(oldValue, newValue);
                    obj.ValueChangedFcn(obj, evtData)
                end
            end
        end

        function knobReleased(obj, ~, ~)
        %knobReleased End a drag of the marker
        %
        %   marker.knobReleased(src, evt) is the pointer-release callback
        %   during a drag. It removes the drag listeners and restores the
        %   size and color of both knobs.

            obj.IsButtonDown = false;

            obj.resetWindowMouseListeners()

            obj.setKnobHighlight([obj.TopButtonHandle, obj.BottomButtonHandle], false)

            if ~obj.IsMouseOnButton
                obj.ParentFigure.Pointer = 'arrow';
            end
        end
    end
end

function mirroredMarker = mirrorMarkerVertically(marker)
%mirrorMarkerVertically Marker that points the other way vertically
    switch marker
        case 'v'
            mirroredMarker = '^';
        case '^'
            mirroredMarker = 'v';
        otherwise
            mirroredMarker = marker;
    end
end
