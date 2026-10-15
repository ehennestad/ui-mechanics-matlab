classdef ScrollBar < uim.Handle
%ScrollBar A scrollbar drawn in its own axes inside a panel
%
%   h = uim.widget.ScrollBar(hParent) creates a scrollbar in hParent, a
%   panel (or other container) reserved for the scrollbar. With the
%   default Position of [0, 0, 1, 1] in normalized Units, the scrollbar
%   fills the container, so the container's position sets its size and
%   location.
%
%   h = uim.widget.ScrollBar(hParent, Name=Value) also sets public
%   properties. Names must match the property names exactly; they are
%   assigned in the order given.
%
%   The orientation follows the shape of the scrollbar's axes at
%   construction: horizontal when it is wider than tall, vertical
%   otherwise. The scroll range runs from 0 to Maximum, and the bar
%   spans VisibleAmount of it. Value is the position of the bar's
%   leading edge; the bar is drawn within [0, Maximum - VisibleAmount]
%   even when Value lies outside that range. With the default Direction
%   'normal', a vertical bar starts at the top.
%
%   Dragging the bar or pressing the track moves it. Every change of
%   Value calls Callback(h, []), whether from interaction or from an
%   assignment (resetValue is the silent exception). When a drag ends,
%   or after a track press, StopMoveCallback(h, change) is called with
%   the movement as a fraction of Maximum. With EnableMouseScroll 'on',
%   the figure's scroll wheel also moves the bar. Assigning Visible or
%   VisibleAmount hides the bar when VisibleAmount is not smaller than
%   Maximum.
%
%   Assigning a Maximum that is not a positive scalar raises
%   uim:ScrollBar:InvalidMaximum; a Visible value that contains neither
%   'on' nor 'off' raises uim:ScrollBar:InvalidVisible.
%
%   Example:
%       hPanel = uipanel(figure, Units="pixels", Position=[10, 10, 20, 200]);
%       h = uim.widget.ScrollBar(hPanel, Maximum=10, VisibleAmount=2, ...
%           Callback=@(src, ~) disp(src.Value));
%
%   See also uim.widget.Slider
%
%   Written by Eivind Hennestad | Vervaeke Lab

    % Todo:
    %   [x] Fix scroller so that its not jumpy/jittery when reaching the
    %       end. Done. But it might still be glitchy when turning around...?
    %
    %   [x] Make sure bar stays in right position when the barlength is
    %       updated. Done. (Need to properly debug)
    %
    %   [ ] Redraw scrollbar when container resizes.
    %   [ ] Change /xlim(horz) or ylim/ver only when maximum changes...

    properties
        % 'horizontal' or 'vertical'. Set at construction from the axes
        % shape (horizontal when wider than tall); an assigned value is
        % overwritten there and should not be changed afterwards.
        Orientation = 'vertical' %Todo: Resolve automatically based on pos
        Direction = 'normal' % 'normal' (vertical bar starts at the top) or 'reverse'; used at construction
        Position = [0,0,1,1] % Position of the scrollbar's axes in its parent, in Units
        Units = 'normalized' % Units of Position; used at construction

%         Minimum = 0               % Minimum scrollbar value (Default = 0) % Note not implemented yet
        Maximum = 1                 % Upper end of the scroll range, a positive scalar (default 1)
        Value = 0                   % Position of the bar's leading edge, in the units of Maximum (default 0)
        VisibleAmount = 0.5         % Length of the bar, in the units of Maximum; inf is treated as 0

        BarWidth = 6;               % Thickness of the bar in pixels; also its minimum length
        BarColor = ones(1,3)*0.65;  % Color of the bar
        TrackColor = ones(1,3)*0.4; % Color of the track which the bar slides on

        EnableMouseScroll matlab.lang.OnOffSwitchState = 'off' % Move the bar with the figure's scroll wheel
        Callback = []               % Called as Callback(h, []) whenever Value changes
        % Called as StopMoveCallback(h, change) after a drag or a track
        % press; change is the movement as a fraction of Maximum.
        StopMoveCallback = []
        Visible = 'on'              % 'on' or 'off'
    end % /properties

    properties (Access = private)
        Parent
        Axes
        Bar
        FigureCallbackStore
        IsInitialized = false

        ScrollHistory = zeros(5,1)
        MoveStartPosition = [];
        BarInitialCoords = [];

        IsCursorOnTrack = false
        IsCursorOnBar = false

        IsTrackVisible = false;
        ParentSizeChangedListener event.listener

        CallbacksEnabled = true
        MouseScrollListener event.listener

    end % /properties (private)

    properties (Dependent, Access = private)
        BarPosition
    end

    methods

        function obj = ScrollBar(parentContainer, varargin)
        %ScrollBar Create a scrollbar in a panel
        %
        %   h = uim.widget.ScrollBar(hParent, Name=Value). See the class
        %   help for the inputs.

            % make assertions, e.g. check that its a valid figure/panel.
            obj.Parent = parentContainer;

            % Assign name value pairs to object.
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end

            obj.createScrollbar;
            obj.setPointerBehavior()

            obj.ParentSizeChangedListener = listener(obj.Parent, ...
                'SizeChanged', @(s, e) obj.updateBarLength);

            obj.IsInitialized = true;
            obj.redraw()

            % Unwrap varargin

            % scrollerDirection: 'horizontal' | 'vertical'
            % scrollerWidthPixel
            % slider
            % track
            % chamfer...

        end % /ScrollBar

        function delete(obj)
            if isvalid(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
            end
        end

        function redraw(obj)
        %redraw Recompute the bar length and position, then draw
        %
        %   h.redraw() resizes the bar for the current axes size, Maximum
        %   and VisibleAmount, moves it to Value and calls drawnow.
            obj.updateBarLength()
            drawnow
        end % /redraw

        function set.Value(obj, newValue)
        %set.Value Set Value property and update bar position.

            if newValue ~= obj.Value
                obj.Value = newValue;
                obj.updateBarPosition()
                obj.onValueChanged()
            end

        end % /set.Value

        function set.Maximum(obj, newValue)
            assert(isnumeric(newValue) && isscalar(newValue) && newValue > 0, ...
                "uim:ScrollBar:InvalidMaximum", 'Maximum must be a positive scalar number')
            obj.Maximum = newValue;
            obj.redraw()
        end

        function set.VisibleAmount(obj, value)
        %set.VisibleAmount Set visibleAmount property and update barheight.

            if obj.VisibleAmount ~= value
                obj.VisibleAmount = value;
                obj.updateBarLength()
                obj.onVisibleChanged()
            end
        end % /set.VisibleAmount

        function set.TrackColor(obj, newValue)
            obj.TrackColor = newValue;
            obj.onStyleChanged()
        end

        function set.BarColor(obj, newValue)
            obj.BarColor = newValue;
            obj.onStyleChanged()
        end

        function set.Visible(obj, newValue)

            assert(contains(newValue, {'on', 'off'}), "uim:ScrollBar:InvalidVisible", ...
                'Visible must be ''on'' or ''off''')

            obj.Visible = newValue;
            obj.onVisibleChanged()
        end

        function set.Position(obj, newValue)
            obj.Position = newValue;
            obj.onPositionChanged()
        end

        function set.EnableMouseScroll(obj, newValue)
            obj.EnableMouseScroll = newValue;
            obj.onEnableMouseScrollValueChanged()
        end

        function showTrack(obj)
        %showTrack Show the track that the bar slides on
        %
        %   h.showTrack() shows the track, which is hidden by default.
            obj.Bar(1).Visible = 'on';
            obj.IsTrackVisible = true;
        end % /showTrack

        function hideTrack(obj)
        %hideTrack Hide the track that the bar slides on
        %
        %   h.hideTrack() hides the track.
            obj.Bar(1).Visible = 'off';
            obj.IsTrackVisible = false;
        end % /hideTrack

        function show(obj)
        %show Show the bar, and the track if it was shown with showTrack
        %
        %   h.show() shows the bar when VisibleAmount is smaller than
        %   Maximum, and hides bar and track otherwise. Assigning
        %   Visible='on' calls it.
            if obj.VisibleAmount < obj.Maximum
                if obj.IsTrackVisible
                    obj.Bar(1).Visible = 'on';
                end
                obj.Bar(2).Visible = 'on';
            else
                obj.Bar(1).Visible = 'off';
                obj.Bar(2).Visible = 'off';
            end
        end

        function hide(obj)
        %hide Hide the bar and the track
        %
        %   h.hide() hides the bar and the track. Assigning Visible='off'
        %   calls it.

            if obj.IsTrackVisible
                obj.Bar(1).Visible = 'off';
            end
            obj.Bar(2).Visible = 'off';
        end

        function setPointerBehavior(obj)
        %setPointerBehavior Highlight the bar while the pointer is on it
        %
        %   h.setPointerBehavior() registers pointer enter and exit
        %   callbacks on the bar that call highlightBar and lowlightBar.
        %   The constructor calls it.

            pointerBehavior.enterFcn    = @(s,e)obj.highlightBar;
            pointerBehavior.exitFcn     = @(s,e)obj.lowlightBar;
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.internal.setPointerBehavior(obj.Bar(2), pointerBehavior)
        end

        function highlightBar(obj)
        %highlightBar Show the bar in its highlighted state
        %
        %   h.highlightBar() raises the bar's FaceAlpha to 0.8.
            %obj.Bar(2).FaceColor = obj.BarColor*1.2;
            obj.Bar(2).FaceAlpha = 0.8;
        end % /highlightBar

        function lowlightBar(obj)
        %lowlightBar Show the bar in its normal state
        %
        %   h.lowlightBar() sets the bar to BarColor with FaceAlpha 0.6.
            obj.Bar(2).FaceColor = obj.BarColor;
            obj.Bar(2).FaceAlpha = 0.6;
        end % /lowlightBar

        function hittest(obj, h)
        %hittest Update appearance and pointer for the object under the pointer
        %
        %   h.hittest(hTarget) takes the graphics object hTarget under
        %   the pointer. On the track it sets the figure pointer to 'hand' and
        %   outlines the track; on the bar it highlights the bar. Leaving
        %   either undoes the change and restores the 'arrow' pointer.

            if isequal(h, obj.Bar(1))
                if ~obj.IsCursorOnTrack
                    obj.IsCursorOnTrack = true;
                    hFig = ancestor(obj.Bar(1), 'figure');
                    hFig.Pointer = 'hand';
                    obj.Bar(1).EdgeColor = obj.Bar(1).FaceColor*1.5;
                end

            else
                if obj.IsCursorOnTrack
                    obj.IsCursorOnTrack = false;
                    hFig = ancestor(obj.Bar(1), 'figure');
                    hFig.Pointer = 'arrow';
                    obj.Bar(1).EdgeColor = 'none';
                end
            end

            if isequal(h, obj.Bar(2))
                if ~obj.IsCursorOnBar
                    obj.highlightBar()
                    obj.IsCursorOnBar = true;
                    hFig = ancestor(obj.Bar(1), 'figure');
                    hFig.Pointer = 'hand';
                end
            else
                if obj.IsCursorOnBar
                    obj.lowlightBar()
                    obj.IsCursorOnBar = false;
                    if ~obj.IsCursorOnTrack
                        hFig = ancestor(obj.Bar(2), 'figure');
                        hFig.Pointer = 'arrow';
                    end
                end
            end
        end % /hittest

        function change = checkMoveLimits(obj, change, currentPosition)
        %checkMoveLimits Limit a bar movement so the bar stays on its track
        %
        %   change = h.checkMoveLimits(change, currentPosition) reduces
        %   change so that a bar with its leading edge at currentPosition
        %   ends within [0, Maximum - VisibleAmount].

            % Todo: Use obj.Minimum for the lower bound once implemented
            change = uim.widget.internal.clampScrollChange(...
                change, currentPosition, obj.Maximum, obj.VisibleAmount);
        end

        function startScrollbarMove(obj, src, ~)
        %startScrollbarMove Start dragging the bar
        %
        %   h.startScrollbarMove(src, evt) is the bar's ButtonDownFcn. It
        %   stores the pointer and bar positions and replaces the figure's
        %   WindowButtonMotionFcn and WindowButtonUpFcn with moveScrollbar
        %   and stopScrollbarMove; stopScrollbarMove restores them.

            hFig = ancestor(src, 'figure');

            obj.Bar(2).FaceColor = ones(1,3)*0.65;

            % Get current mouse position, and save it to obj
            mousePointAx = get(obj.Axes, 'CurrentPoint');

            switch lower(obj.Orientation)
                case 'horizontal'
                    obj.MoveStartPosition = mousePointAx(1, 1);
                    obj.BarInitialCoords = get(obj.Bar(2), 'XData');
                case 'vertical'
                    obj.MoveStartPosition = mousePointAx(1, 2);
                    obj.BarInitialCoords = get(obj.Bar(2), 'YData');
            end

            obj.FigureCallbackStore.WindowButtonMotionFcn = hFig.WindowButtonMotionFcn;
            obj.FigureCallbackStore.WindowButtonUpFcn = hFig.WindowButtonUpFcn;

            hFig.WindowButtonMotionFcn = @obj.moveScrollbar;
            hFig.WindowButtonUpFcn = @obj.stopScrollbarMove;
        end % /startScrollbarMove

        function moveScrollbar(obj, ~, event)
        %moveScrollbar Move the bar during a drag or a scroll-wheel turn
        %
        %   h.moveScrollbar(src, event) sets Value from the pointer when
        %   event is WindowMouseData, or steps it by Maximum/20 per scroll
        %   count when event is ScrollWheelData. The bar is kept on its
        %   track.

            % Todo: Make this more intuitive....

            if isa(event, 'matlab.ui.eventdata.WindowMouseData')

                newMousePointAx = get(obj.Axes, 'CurrentPoint');

                switch lower(obj.Orientation)
                    case 'horizontal'
                        newPosition = newMousePointAx(1, 1);
                    case 'vertical'
                        newPosition = newMousePointAx(1, 2);
                end

                change = newPosition - obj.MoveStartPosition;
                barInitialPosition = min(obj.BarInitialCoords);

            elseif isa(event, 'matlab.ui.eventdata.ScrollWheelData')

                switch lower(obj.Orientation)
                    case 'horizontal'
                        initialCoords = obj.Bar(2).XData;
                    case 'vertical'
                        initialCoords = obj.Bar(2).YData;
                end
                barInitialPosition = min(initialCoords);

                % Use the ScrollHistory to avoid "glitchy" scrolling. For small
                % movements on a mousepad, scroll values can come in as 0, 1, 1,
                % -1, 1, 1 even if fingers are moving in on direction.
                [isAccepted, obj.ScrollHistory] = ...
                    uim.widget.internal.acceptScrollStep(...
                    obj.ScrollHistory, event.VerticalScrollCount);
                if ~isAccepted; return; end

                % Todo: Scroll increment should be a property.
                change = event.VerticalScrollCount .* obj.Maximum ./ 20;
            end

            change = obj.checkMoveLimits(change, barInitialPosition);

            % Update scrollbar value
            newValue = barInitialPosition + change;

            if newValue ~= obj.Value
                obj.Value = newValue;
            end

        end % /moveScrollbar

        function stopScrollbarMove(obj, src, ~)
        %stopScrollbarMove End a bar drag
        %
        %   h.stopScrollbarMove(src, evt) restores the figure callbacks
        %   replaced by startScrollbarMove, resets the bar color and calls
        %   StopMoveCallback(h, change), where change is the movement since
        %   the drag started as a fraction of Maximum.

            hFig = ancestor(src, 'figure');

            % Restore original figure interactivity callbacks.
            hFig.WindowButtonMotionFcn = obj.FigureCallbackStore.WindowButtonMotionFcn;
            hFig.WindowButtonUpFcn = obj.FigureCallbackStore.WindowButtonUpFcn;

            % Reset the scrollbar color.
            obj.Bar(2).FaceColor = obj.BarColor;
            drawnow

            % Get shift of scroller
            newMousePointAx = get(obj.Axes, 'CurrentPoint');

            switch lower(obj.Orientation)
                case 'horizontal'
                    newPosition = newMousePointAx(1, 1);
                case 'vertical'
                    newPosition = newMousePointAx(1, 2);
            end

            change = newPosition - obj.MoveStartPosition;

            barInitialPosition = min(obj.BarInitialCoords);
            change = obj.checkMoveLimits(change, barInitialPosition);

            % Todo: Make change part of an eventdata object.
            if ~isempty(obj.StopMoveCallback)
                obj.StopMoveCallback(obj, change./obj.Maximum) % Todo: Change this, (e.g. add both change and maximum to eventdata... Update dependent apps)
            end

            obj.BarInitialCoords = [];

        end % /stopScrollbarMove

        function jumpToNewValue(obj, ~, ~)
        %jumpToNewValue Move the bar to a pressed point on the track
        %
        %   h.jumpToNewValue(src, evt) is the track's ButtonDownFcn. It
        %   moves the bar's leading edge to the pressed point, kept on the
        %   track, and calls StopMoveCallback(h, change), where change is
        %   the movement as a fraction of Maximum.

            % Get change of scroller
            newMousePointAx = get(obj.Axes, 'CurrentPoint');

            switch lower(obj.Orientation)
                case 'horizontal'
                    newPosition = newMousePointAx(1, 1);
                    currentPosition = min(obj.Bar(2).XData);
                case 'vertical'
                    newPosition = newMousePointAx(1, 2);
                    currentPosition = min(obj.Bar(2).YData);
            end

            change = newPosition - currentPosition;
            change = obj.checkMoveLimits(change, currentPosition);

            % Update scrollbar value
            newValue = currentPosition + change;
            obj.Value = newValue;

            % Todo: Make change part of an eventdata object.
            if ~isempty(obj.StopMoveCallback)
                obj.StopMoveCallback(obj, change./obj.Maximum)
            end

        end % /jumpToNewValue

        function resetValue(obj)
        %resetValue Set Value to 0 without calling Callback
        %
        %   h.resetValue()
            obj.CallbacksEnabled = false;
            obj.Value = 0;
            obj.CallbacksEnabled = true;
        end

    end % /methods

    methods

        function position = get.BarPosition(obj)

            if isempty(obj.BarInitialCoords)
                switch lower(obj.Orientation)
                    case 'horizontal'
                        scrollerData = obj.Bar(2).XData;
                    case 'vertical'
                        scrollerData = obj.Bar(2).YData;
                end
            else
                scrollerData = obj.BarInitialCoords;
            end

            position = min(scrollerData);
        end
    end

    methods (Access = private)

        function createScrollbar(obj)
        %createScrollbar Initialize the scrollbar graphical objects.

            if ~isvalid(obj.Parent); return; end

            % Create an axes object to plot the scrollbar in
            obj.Axes = axes('Parent', obj.Parent);
            obj.Axes.Units = obj.Units;
            obj.Axes.Position = obj.Position;
            obj.Axes.Tag = 'Scrollbar Axes';
            obj.Axes.HandleVisibility = 'off';

            % Set axes limits to "normalized" units.
            obj.Axes.Visible = 'off';
            hold(obj.Axes, 'on')
            obj.Axes.XLim = [0,1];
            obj.Axes.YLim = [0,1];

            uim.internal.disableAxesInteractivity(obj.Axes)

            switch obj.Direction
                case 'normal'
                    obj.Axes.YDir = 'reverse'; % Scroll from top to bottom
            end

            % Determine if scroller should be horizontal or vertical
            axPixelPos = getpixelposition(obj.Axes);
            AR = axPixelPos(3)/axPixelPos(4);
            if AR > 1
                obj.Orientation = 'horizontal';
            else
                obj.Orientation = 'vertical';
            end

            switch lower(obj.Orientation)
                case 'horizontal'
                    xDataTrack = [0,1,1,0];
                    yDataTrack = [0,0,1,1];
                    xDataBar = [0,0,0,0];
                    yDataBar = [0.35,0.35,0.65,0.65];
                case 'vertical'
                    xDataTrack = [0.3,0.3,0.7,0.7];
                    yDataTrack = [1,0,0,1];
                    xDataBar = [0.35,0.35,0.65,0.65];
                    yDataBar = [0,0,0,0];
            end

            % Plot the "scroller track" and the scrollerbar
            obj.Bar = gobjects(2,1);
            obj.Bar(1) = patch(xDataTrack, yDataTrack, obj.TrackColor);
            obj.Bar(2) = patch(xDataBar, yDataBar, obj.BarColor);
            obj.Bar(2).FaceAlpha = 0.6;
            set(obj.Bar, 'Parent', obj.Axes)
            set(obj.Bar, 'Visible', obj.Visible)

            % Tag scroller handles
            obj.Bar(1).Tag = 'Sidebar';
            obj.Bar(2).Tag = 'Scrollbar';

            % Assign methods for when scroller handles are pressed.
            obj.Bar(1).ButtonDownFcn = @obj.jumpToNewValue;
            obj.Bar(2).ButtonDownFcn = @obj.startScrollbarMove;

            obj.Bar(1).Visible = 'off';
            obj.Bar(2).Visible = obj.Visible;
            set(obj.Bar, 'EdgeColor', 'none')
            obj.updateBarLength()

        end % /createScrollbar

        function onMouseScrolled(obj, src, evt)
            obj.moveScrollbar(src, evt)
        end

        function onValueChanged(obj)
        %onValueChanged Execute callback on Value change (bar is moved).
            if ~isempty(obj.Callback)
                if obj.CallbacksEnabled
                    obj.Callback(obj, [])
                end
            end
        end % /onValueChanged

        function onPositionChanged(obj)
            if obj.IsInitialized
                if any( obj.Axes.Position(3:4) ~=  obj.Position(3:4))
                    obj.redraw()
                end
                obj.Axes.Position = obj.Position;
            end
        end

        function onVisibleChanged(obj)

            if obj.IsInitialized
                switch obj.Visible
                    case 'on'
                        obj.show()
                    case 'off'
                        obj.hide()
                end
            end
        end

        function onStyleChanged(obj)
            if obj.IsInitialized
                obj.Bar(1).FaceColor = obj.TrackColor;
                obj.Bar(2).FaceColor = obj.BarColor;
            end
        end

        function onEnableMouseScrollValueChanged(obj)

            if obj.EnableMouseScroll
                hFigure = ancestor(obj.Parent, 'figure');
                obj.MouseScrollListener = listener(hFigure, ...
                    'WindowScrollWheel', @obj.onMouseScrolled);
            else
                if ~isempty(obj.MouseScrollListener)
                    delete(obj.MouseScrollListener)
                    obj.MouseScrollListener = event.listener.empty;
                end
            end
        end

        function updateBarLength(obj)
        %updateBarLength Update scrollerbar height.

            if ~obj.IsInitialized; return; end

            axSize = getpixelposition(obj.Axes);
            axSize = axSize(3:4);

            if obj.VisibleAmount == inf
                obj.VisibleAmount = 0;
            end

            % Todo: Implement obj.Minimum
            newAxesLimits = [0, obj.Maximum]; % + [-1, 1] .* obj.VisibleAmount/2;

            switch lower(obj.Orientation)
                case 'horizontal'
                    isDim = [0, 1];
                    obj.Axes.XLim = newAxesLimits;
                case 'vertical'
                    isDim = [1, 0];
                    obj.Axes.YLim = newAxesLimits;
            end

            barSize = uim.widget.internal.scrollBarSize(axSize, ...
                obj.Orientation, obj.VisibleAmount, obj.Maximum, obj.BarWidth);

            obj.updateTrackLimits() % since axes limits was changed...

            % Get coordinates for scrollbar patch.
            [edgeX, edgeY] = uim.shape.rectangle(barSize, obj.BarWidth/2);
            coords = uim.utility.px2du(obj.Axes, [edgeX', edgeY']);

            % Correct so that minimum is at (0,0)
            coords = coords - min(coords);

            % Center on shortest dimension
            coords = coords + (1-uim.utility.range(coords(:, :)))/2 .* isDim;

            % Set new coordinates of scrollbar patch
            set(obj.Bar(2), 'XData', coords(:,1), 'YData', coords(:,2));
            obj.updateBarPosition()
            drawnow limitrate

        end % /updateBarLength

        function updateBarPosition(obj)
        %updateBarPosition Update scrollerbar position
        %
        % Mostly relevant if value is change from external source...

            if obj.IsInitialized

                if isempty(obj.BarInitialCoords)
                    switch lower(obj.Orientation)
                        case 'horizontal'
                            scrollerData = obj.Bar(2).XData;
                        case 'vertical'
                            scrollerData = obj.Bar(2).YData;
                    end
                else
                    scrollerData = obj.BarInitialCoords;
                end

                scrollerPos = min(scrollerData);

                % Get shift of scroller
                change = obj.Value - scrollerPos;

                % Make sure scroller stays within bar range
                change = obj.checkMoveLimits(change, scrollerPos);

                % Update the position of the scrollbar
                switch lower(obj.Orientation)
                    case 'horizontal'
                        obj.Bar(2).XData =  scrollerData + change;
                    case 'vertical'
                        obj.Bar(2).YData =  scrollerData + change;
                end
            end

        end % /updateBarPosition

        function updateTrackLimits(obj)

            switch lower(obj.Orientation)
                case 'horizontal'
                    xDataTrack = obj.Axes.XLim([1,2,2,1]);
                    obj.Bar(1).XData = xDataTrack;

                case 'vertical'
                    yDataTrack = obj.Axes.YLim([2,1,1,2]);
                    obj.Bar(1).YData = yDataTrack;
            end
        end

    end % /methods (private)

end % /classdef
