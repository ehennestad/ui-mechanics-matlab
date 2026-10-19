classdef PlaneSwitcher < uim.mixin.NameValueAssignable
%PlaneSwitcher Toggle button with a pop-up slider for choosing a z-plane
%
%   A plane switcher draws a bold "Z" text button. Clicking it shows or
%   hides a vertical uim.widget.Slider that runs from 1 to NumPlanes, and
%   moving the slider calls Callback with the new value.
%   uim.widget.PlaybackControl uses it to pick the plane of a volumetric
%   image stack.
%
%   switcher = uim.widget.PlaneSwitcher(parent) creates a switcher for
%   one plane. If parent is an axes, the button is drawn into it;
%   otherwise the switcher creates its own invisible pixel-unit axes in
%   parent, for example a figure or uipanel. With two or more planes the
%   slider is created at construction, hidden, in the parent of that
%   axes; with one plane there is nothing to switch and the button does
%   nothing.
%
%   switcher = uim.widget.PlaneSwitcher(parent, Name=Value) also sets
%   public properties, for example
%
%       switcher = uim.widget.PlaneSwitcher(hPanel, NumPlanes=5, ...
%           CurrentPlane=2, Callback=@(plane) disp(plane));
%
%   Changing NumPlanes updates the slider range. Changing Position(1:2)
%   moves the button, and Visible hides the button and the slider.
%   BackgroundColor and PlaneSwitcherToggleButtonSize have no effect on
%   the graphics.
%
%   See also uim.widget.PlaybackControl, uim.widget.Slider,
%   uim.widget.ChannelIndicator

    properties (Dependent)
        % Position - [x, y, width, height] in pixels. Normalized values
        % (width or height <= 1) are rejected. The button is drawn with
        % its right edge at the horizontal centre of the position. With an
        % internal axes, width and height set the axes size.
        Position (1,4) double
    end

    properties (Access = public)
        Visible matlab.lang.OnOffSwitchState = 'on' % Stored only; does not show or hide the switcher
        NumPlanes = 1 % Number of planes, the slider's maximum

        % CurrentPlane - Index of the current plane. Setting a scalar moves
        % the slider. While it holds more than one index, the slider is not
        % updated and the button does not open the slider.
        CurrentPlane = 1
    end

    properties % Appearance
        BackgroundColor = [0.94, 0.94, 0.94]; % Not used by the drawing

        % ForegroundColor - RGB triplet for the "Z" button and the slider
        % text. The button brightens by 0.15 per component while hovered.
        ForegroundColor = ones(1,3) * 0.6

        PlaneSwitcherToggleButtonSize = 12; % Not used by the drawing

        % Callback - Function called as Callback(value) when the user moves
        % the slider; value is the slider's Value
        Callback = []
    end

    properties (Access = protected)

        Figure % Window which figure is located in. % Make dependent...
        Axes

        IsAxesInternal

        PlaneSwitcherToggleButton = gobjects(0);
        PlaneSwitcherSlider = gobjects(0);
    end

    properties (Access = private) % Widget states and internals
        IsConstructed = false
        IsMouseOnButton = false
        IsMouseButtonPressed = false

        Position_ = [1, 1, 20, 20]; %Initial position

        WindowMouseMotionListener
        WindowMouseReleaseListener
        FrameChangedListener
    end

    methods % Structor

        function obj = PlaneSwitcher(hParent, varargin)
        %PlaneSwitcher Create a plane switcher
        %
        %   switcher = uim.widget.PlaneSwitcher(parent, Name=Value)
        %
        %   See the class help for the accepted parents and options.

            obj.Figure = ancestor(hParent, 'figure');
            % Draggable parts read CurrentPoint from motion listeners; in
            % java figures that requires a WindowButtonMotionFcn.
            uim.internal.ensurePointerMotionTracking(obj.Figure)

            obj.resolveParent(hParent)

            obj.parseInputs(varargin{:})

            obj.IsConstructed = true;

            obj.createWidgetComponents()
        end

        function delete(obj)
            delete(obj.PlaneSwitcherToggleButton)
            delete(obj.PlaneSwitcherSlider)
        end
    end

    methods % Set/Get

        function set.Position(obj, newPos)

            assert(isnumeric(newPos) && numel(newPos) == 4, 'Value must be a 4 element vector')
            assert(all(newPos(3:4) > 1), 'This widget does not support normalized position units')
            obj.Position_ = newPos;
        end

        function set.Position_(obj, newPosition)

            % Check if it was size and/or location that changed.
            isSizeChanged = any(newPosition(3:4) ~= obj.Position_(3:4));
            isLocationChanged = any(newPosition(1:2) ~= obj.Position_(1:2));

            obj.Position_ = newPosition;

            % Update size first
            if isSizeChanged
                obj.onSizeChanged()
            end

            % Update location second
            if isLocationChanged
                obj.onLocationChanged()
            end
        end

        function pos = get.Position(obj)
            pos = obj.Position_;
        end

        function set.Visible(obj, newValue)
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end

        function set.NumPlanes(obj, newValue)
            obj.NumPlanes = newValue;
            obj.onNumPlanesChanged()
        end

        function set.CurrentPlane(obj, newValue)
            obj.CurrentPlane = newValue;
            obj.onCurrentPlaneChanged()
        end
    end

    methods (Access = protected) % Widget creation & updates
        function resolveParent(obj, hParent)

            if isa(hParent, 'matlab.graphics.axis.Axes')
                obj.Axes = hParent;
                obj.IsAxesInternal = false;
            else
                obj.createAxes(hParent)
                obj.IsAxesInternal = true;
            end
        end

        function createAxes(obj, hParent)
            obj.Axes = uim.UIComponentCanvas.createComponentAxes(hParent);
        end

        function createWidgetComponents(obj)

            obj.drawPlaneSwitcherToggleButton()
            % A slider needs Min < Max, so it only exists for two or more
            % planes
            if obj.NumPlanes > 1
                obj.drawPlaneSwitcherSlidebar()
            end
        end

        function drawPlaneSwitcherToggleButton(obj)

            X = obj.Position(1) + obj.Position(3)/2;
            Y = 0;

            % Create button or update position.
            if isempty(obj.PlaneSwitcherToggleButton)
                h = text(obj.Axes, X, Y, 'Z');
                h.HorizontalAlignment = 'right';
                h.VerticalAlignment = 'middle';
                h.FontSize = 14;
                h.FontWeight = 'bold';
                h.Color = obj.ForegroundColor;
                h.Tag = 'PlaneSwitcherToggleButton';
                h.ButtonDownFcn = @(s, e) obj.onPlaneSwitcherToggleButtonPushed;

                obj.setPointerBehavior(h)

                obj.PlaneSwitcherToggleButton = h;

            else
                obj.PlaneSwitcherToggleButton.Position(1:2) = [X,Y];
            end
        end

        function drawPlaneSwitcherSlidebar(obj)

            args = {'Min', 1, 'Max', obj.NumPlanes, 'NumSteps', ...
                obj.NumPlanes-1};

            hSlider = uim.widget.Slider('Parent', obj.Axes.Parent, ...
                    'Position', [0, obj.Position(4)+10, 100, 10], ...
                    'Units', 'pixel', args{:}, 'Value', obj.CurrentPlane, ...
                    'TextColor', obj.ForegroundColor, 'Padding', [0,9,3,9], ...
                    'Callback', @obj.onPlaneSliderValueChanged, ...
                    'BarColor', ones(1,3)*0.45, 'TickLength', 0, ...
                    'TooltipExpression', 'Z = %d');

            obj.PlaneSwitcherSlider = hSlider;
            obj.PlaneSwitcherSlider.Visible = 'off';
            % Todo
        end
    end

    methods (Access = private) % User interaction callbacks

        function onPlaneSliderValueChanged(obj, src, ~)

            newPlaneIdx = src.Value;
            if ~isempty(obj.Callback)
                obj.Callback(newPlaneIdx)
            end
        end

        function onPlaneSwitcherToggleButtonPushed(obj)

            if obj.NumPlanes < 2; return; end

            if isempty(obj.PlaneSwitcherSlider)
                obj.drawPlaneSwitcherSlidebar()
                return
            end

            if numel(obj.CurrentPlane) > 1
                return
            end

            if strcmp(obj.PlaneSwitcherSlider.Visible, 'on')
                obj.PlaneSwitcherSlider.Visible = 'off';
            else
                obj.PlaneSwitcherSlider.Visible = 'on';
            end
        end
    end

    methods (Access = private) % Property set callbacks

        function onVisibleChanged(obj)

            if ~obj.IsConstructed; return; end

            obj.PlaneSwitcherToggleButton.Visible = obj.Visible;
            % The slider opens from the button, so it closes with it
            if ~obj.Visible && ~isempty(obj.PlaneSwitcherSlider)
                obj.PlaneSwitcherSlider.Visible = 'off';
            end
        end

        function onLocationChanged(obj)
            if ~obj.IsConstructed; return; end
            obj.drawPlaneSwitcherToggleButton()
        end

        function onSizeChanged(obj)

            if ~obj.IsConstructed; return; end

            if obj.IsAxesInternal
                obj.Axes.Position(3:4) = obj.Position_(3:4);

                axWidth = obj.Axes.Position(3);
                axHeight = obj.Axes.Position(4);

                newYLim = [-1, 1] .* (axHeight/2);
                if ~all( newYLim == obj.Axes.YLim  )
                    obj.Axes.YLim = newYLim;
                end

                newXLim = [1, axWidth];
                if ~all( newXLim == obj.Axes.XLim )
                    obj.Axes.XLim = newXLim;
                end
            else
                % Do nothing...
            end
        end

        function onNumPlanesChanged(obj)
            if ~obj.IsConstructed || isempty(obj.PlaneSwitcherSlider); return; end

            if obj.NumPlanes > 1
                obj.PlaneSwitcherSlider.Max = obj.NumPlanes;
                obj.PlaneSwitcherSlider.NumSteps = obj.NumPlanes - 1;
            else
                % One plane leaves nothing to switch
                delete(obj.PlaneSwitcherSlider)
                obj.PlaneSwitcherSlider = gobjects(0);
            end
        end

        function onCurrentPlaneChanged(obj)
            if ~obj.IsConstructed || isempty(obj.PlaneSwitcherSlider)
                return
            end

            if numel(obj.CurrentPlane) > 1
                return
            else
                obj.PlaneSwitcherSlider.Value = obj.CurrentPlane;
            end
        end
    end

    methods (Access = private)

        % % % Callbacks for mouseover effects

        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEntered(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExited(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.internal.setPointerBehavior(h, pointerBehavior)
        end

        function onMouseEntered(obj, h, varargin)
        %onMouseEntered Callback for mouse entering button

            obj.IsMouseOnButton = true;

            if isa(h, 'matlab.graphics.primitive.Text')
                obj.changeButtonAppearance()
            end

            obj.Figure.Pointer = 'hand';
        end

        function onMouseExited(obj, h, varargin)
        %onMouseEntered Callback for mouse leaving button

            obj.IsMouseOnButton = false;

            if isa(h, 'matlab.graphics.primitive.Text')
                obj.changeButtonAppearance()
            end

            if ~obj.IsMouseButtonPressed
                obj.Figure.Pointer = 'arrow';
            end
        end

        function changeButtonAppearance(obj)

            if obj.IsMouseOnButton          % Mouse on
                onColor = min( [obj.ForegroundColor+0.15; [1,1,1]] );
                obj.PlaneSwitcherToggleButton.Color = onColor;
            else                                        % Mouse off
                offColor = obj.ForegroundColor;
                obj.PlaneSwitcherToggleButton.Color = offColor;
            end
        end
    end

    % onNumPlanesChanged

    % onPlaneSwitcherToggleButtonPushed
end
