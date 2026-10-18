classdef RangeSlider < uim.abstract.Control & matlab.mixin.SetGet
%RangeSlider A horizontal slider with two knobs selecting a [Low, High] range
%
%   slider = uim.widget.RangeSlider(hParent) creates a range slider in
%   hParent: a uim container or uim.UIComponentCanvas, an axes (the
%   slider is drawn on an overlay canvas covering it), or a figure or
%   panel.
%
%   slider = uim.widget.RangeSlider(hParent, Name=Value) also sets
%   public properties, including the inherited layout properties such as
%   Position, Size, Location, Margin and Padding (in pixels). Min and Max
%   default to 0 and 1, Low and High to Min and Max. Name-value pairs
%   are applied together, so their order does not matter; the resulting
%   values must satisfy Min < Max and Min <= Low <= High <= Max.
%
%   The track runs along Position, inset by the left and right Padding.
%   Dragging a knob moves Low or High; pressing the track moves the
%   nearest knob to the pressed point. Values from the pointer are
%   rounded to the nearest multiple of (Max - Min)/NumTicks, clamped to
%   [Min, Max] and kept so that Low <= High. While a knob is pressed, a
%   value label is shown above it (see ShowLabel). The inherited Label
%   is drawn beside the track at LabelLocation.
%
%   Raising Min above Low, or lowering Max below High, moves the values
%   along with the limit. Invalid assignments raise:
%       uim:RangeSlider:InvalidLimits - Min >= Max
%       uim:RangeSlider:InvalidLow    - Low < Min or Low > High
%       uim:RangeSlider:InvalidHigh   - High > Max or High < Low
%
%   Callbacks receive (slider, evt), where evt is a struct with fields
%   Low and High:
%       ValueChangingFcn - on every change of Low or High, including
%                          programmatic assignments
%       Callback         - when a knob is released, when the track is
%                          pressed, and on changes of Low or High (also
%                          programmatic), at most CallbackRefreshRate
%                          times a second
%
%   Subclasses can override the protected notifyValueChanged method to
%   intercept Callback notifications; see uim.widget.ContrastSlider.
%
%   Example:
%       hFigure = figure;
%       slider = uim.widget.RangeSlider(hFigure, Min=0, Max=100, ...
%           Low=20, High=80, Position=[20, 20, 200, 30], ...
%           Callback=@(src, evt) disp([evt.Low, evt.High]));
%
%   See also uim.widget.ContrastSlider, uim.widget.Slider

    % Todo:
    %   [ ] add vertical orientation
    %   [ ] updateSize and updateLocation should happen automatically when
    %   position is set.

    properties (Constant)
        Type = 'RangeSlider' % Component type name
    end

    properties (Dependent)
        Min                 % Minimum possible slider value
        Max                 % Maximum possible slider value
        Low                 % Current low value of slider
        High                % Current high value of slider
    end

    properties
        % Number of value steps between Min and Max. Pointer values are
        % rounded to multiples of (Max - Min)/NumTicks; no tick marks
        % are drawn.
        NumTicks = 100

        % Side of the track where Label is drawn: 'left', 'right', 'top'
        % or 'bottom'. Read when the label is placed.
        LabelLocation = 'left'      % Todo: Add to superclass (a widget class)

        TrackWidth = 2              % Line width of the track in points; used at construction
        TrackColor = ones(1,3)*0.75; % Color of the track; used at construction
        KnobSize = 15               % Knob diameter in pixels; also the gap between the track and Label
        KnobMarkerStyle = 'round'   % Not used; knobs are always round. Todo: implement line/bar

        % Todo: move to uim.style definition....
        % Knob colors. The inactive colors apply at construction and when
        % a knob is released, the active colors while a knob is pressed.
        % Hovering sets the knob fill to light grey (0.95) and leaving
        % sets it to grey (0.8).
        KnobEdgeColorInactive = ones(1,3)*0.7; % Knob edge at construction and after release
        KnobEdgeColorActive = [0.1195    0.6095    0.5395]; % Knob edge while the knob is pressed
        KnobFaceColorInactive = ones(1,3)*0.8; % Knob fill at construction and after release
        KnobFaceColorActive = ones(1,3)*0.65; % Knob fill while the knob is pressed

        TickLength = 5 % Not used; the slider draws no tick marks

        TextColor = ones(1,3)*0.8;      % Color of Label and the value label; used at construction
        TextBackgroundColor = 'none';   % Not applied to any graphics object

        ShowLabel = true; % Show the value label above a knob while it is pressed

        ValueChangingFcn = [] % Called as ValueChangingFcn(slider, evt) on every change of Low or High

        % Maximum number of Callback calls per second caused by changes of
        % Low or High (default inf: every change). Useful when the
        % callback does heavy computation. The time of the last call is
        % shared by all RangeSlider objects.
        CallbackRefreshRate = inf
    end

    properties (Access = private, Transient = true)
        StepSize
        % Sentinels keep each dependent value temporarily unconstrained
        % while parseInputs assigns name-value pairs in property order.
        % initializeFiniteRange replaces omitted values with public defaults.
        Min_ (1,1) double = -inf
        Max_ (1,1) double = inf
        Low_ (1,1) double = -inf
        High_ (1,1) double = inf
    end

    properties (Access = private)
        Track
        Knob
        ValueLabel
        Ticks
        LabelHandle

        IsKnobPressed = false

        % tic value of the last rate-limited Callback notification; empty
        % until the first one, so the first change always notifies
        TicAtLastCallback = []

        WindowButtonUpListener
        WindowMouseMotionListener
    end

    methods % Structors

        function obj = RangeSlider(hParent, varargin)
        %RangeSlider Create a range slider
        %
        %   slider = uim.widget.RangeSlider(hParent, Name=Value). See the
        %   class help for the inputs.

            obj@uim.abstract.Control(hParent, varargin{:})

            % Knob drags read CurrentPoint from motion listeners; in
            % java figures that requires a WindowButtonMotionFcn.
            uim.internal.ensurePointerMotionTracking(...
                ancestor(obj.CanvasAxes, 'figure'))

            obj.initializeFiniteRange()

            obj.createSlider()
            obj.plotLabel()

            obj.IsConstructed = true;

            obj.onVisibleChanged()

            obj.Background.Tag = 'Range Slider Background';
        end

        function delete(obj)
            delete(obj.Track)
            delete(obj.Knob)
            delete(obj.ValueLabel)
            delete(obj.Ticks)
            delete(obj.LabelHandle)
        end
    end

    methods (Access = private) % Component construction

        function initializeFiniteRange(obj)
        %initializeFiniteRange Resolve construction sentinels after parsing.
            if ~isfinite(obj.Min_)
                obj.Min_ = 0;
            end
            if ~isfinite(obj.Max_)
                obj.Max_ = 1;
            end
            if ~isfinite(obj.Low_)
                obj.Low_ = obj.Min_;
            end
            if ~isfinite(obj.High_)
                obj.High_ = obj.Max_;
            end

            assert(obj.Min_ < obj.Max_, "uim:RangeSlider:InvalidLimits", ...
                'Slider lower limit must be smaller than slider upper limit')
            assert(obj.Low_ >= obj.Min_ && obj.Low_ <= obj.High_, "uim:RangeSlider:InvalidLow", ...
                'Slider lower value must be within the selected range')
            assert(obj.High_ <= obj.Max_, "uim:RangeSlider:InvalidHigh", ...
                'Slider upper value must be within the selected range')
        end

        function createSlider(obj)

            % Slider and especially the slider track is thin, and its easy
            % to miss when pressing it. Patch background so that
            % mousepresses are still captured by this widget on close miss.
            obj.Background.HitTest = 'on';
            obj.Background.PickableParts = 'all';

            obj.plotTrack()
            obj.plotKnobs()
            obj.plotText()
            %obj.plotTicks()

            % Set visibility of subcomponents.
            obj.Track.Visible = obj.Visible;
            set(obj.Knob, 'Visible', obj.Visible);
        end

        function plotLabel(obj)

            [xCoords, yCoords] = obj.getTrackCoordinates();

            if isempty(obj.LabelHandle)
                obj.LabelHandle = text(obj.CanvasAxes, 1, 1, obj.Label);
                obj.LabelHandle.Color = obj.TextColor;
                obj.LabelHandle.HitTest = 'off';
                obj.LabelHandle.PickableParts = 'none';
                obj.LabelHandle.Visible = obj.Visible;
            end

            switch obj.LabelLocation
                case 'left'
                    x = min(xCoords) - obj.KnobSize;
                    y = mean(yCoords);
                    hAlign = 'right';
                    vAlign = 'middle';
                case 'right'
                    x = max(xCoords) + obj.KnobSize;
                    y = mean(yCoords);
                    hAlign = 'left';
                    vAlign = 'middle';
                case 'top'
                    x = mean(xCoords);
                    y = max(yCoords) + obj.KnobSize;
                    hAlign = 'left';
                    vAlign = 'bottom';
                case 'bottom'
                    x = min(xCoords);
                    y = mean(yCoords) - obj.KnobSize;
                    hAlign = 'left';
                    vAlign = 'top';
            end

            obj.LabelHandle.Position(1:2) = [x, y];
            obj.LabelHandle.HorizontalAlignment = hAlign;
            obj.LabelHandle.VerticalAlignment = vAlign;
        end

        function plotTrack(obj)

            % Plot the track as a line
            [xCoords, yCoords] = obj.getTrackCoordinates();

            if isempty(obj.Track)
                obj.Track = plot(obj.CanvasAxes, xCoords, yCoords);

                obj.Track.LineWidth = obj.TrackWidth;
                obj.Track.HitTest = 'on';
                obj.Track.PickableParts = 'visible';
                obj.Track.Color = obj.TrackColor;
                obj.Track.Tag = 'Range Slider Track';

                obj.Background.ButtonDownFcn = @(src, event) obj.onSliderMoved(src);
                obj.Track.ButtonDownFcn = @(src, event) obj.onSliderMoved(src);
            else
                set(obj.Track, 'XData', xCoords, 'YData', yCoords)
            end
        end

        function plotTicks(obj)

            x1 = obj.Position(1)+obj.Padding(1);
            x2 = sum(obj.Position([1,3]))-obj.Padding(3);

            y1 = obj.Position(2) + obj.Padding(2);
            y2 = y1 + obj.TickLength;

            numTicks = 10;
            x = linspace(x1,x2,numTicks);
            x = repmat(x, 3, 1);
            x(3,:) = nan;

            y = repmat([y1;y2;nan], 1, numTicks);

            obj.Ticks = plot(obj.CanvasAxes,x,y, obj.TrackColor);
        end

        function plotKnobs(obj)

            % Patch the slider knob using aspect ratio adjusted coords.
            [xCoordsLow, yCoordsLow] = obj.getKnobCoordinates('low');
            [xCoordsHigh, yCoordsHigh] = obj.getKnobCoordinates('high');

            if isempty(obj.Knob)
                h1 = patch(obj.CanvasAxes, xCoordsLow, yCoordsLow, 'k');
                h2 = patch(obj.CanvasAxes, xCoordsHigh, yCoordsHigh, 'k');

                h1.Tag = 'Range Slider Low';
                h2.Tag = 'Range Slider High';

                obj.Knob = [h1, h2];

                set(obj.Knob, 'LineWidth', 1)
                set(obj.Knob, 'Clipping', 'off')

                set(obj.Knob, 'FaceColor', obj.KnobFaceColorInactive)
                set(obj.Knob, 'EdgeColor', obj.KnobEdgeColorInactive)
                set(obj.Knob, 'ButtonDownFcn', @obj.onSliderKnobPressed);

                setPointerBehavior(obj, obj.Knob(1))
                setPointerBehavior(obj, obj.Knob(2))

            else
                set(obj.Knob(1), 'XData', xCoordsLow, 'YData', yCoordsLow)
                set(obj.Knob(2), 'XData', xCoordsHigh, 'YData', yCoordsHigh)
            end
        end

        function plotText(obj, whichSlider)
            % Create a text object for displaying the current value when
            % the slider is active.

            if nargin < 2; whichSlider = 'low'; end

            [xCoords, yCoords] = obj.getTextCoordinates(whichSlider);

            if isempty(obj.ValueLabel)
                obj.ValueLabel = text(obj.CanvasAxes, xCoords, yCoords, '');
                obj.ValueLabel.VerticalAlignment = 'Bottom';
                obj.ValueLabel.HorizontalAlignment = 'left';
                obj.ValueLabel.Color = obj.TextColor;
                obj.ValueLabel.Visible = 'off';
            else
                obj.ValueLabel.Position(1:2) = [xCoords, yCoords];
            end
        end
    end

    methods (Hidden, Access = protected)

        function onVisibleChanged(obj, ~)

            if ~obj.IsConstructed; return; end

            % Set visibility of subcomponents.
            obj.Track.Visible = obj.Visible;
            set(obj.Knob, 'Visible', obj.Visible);
            obj.LabelHandle.Visible = obj.Visible;

            switch obj.Visible
                case 'on'
                    obj.Background.PickableParts = 'all';
                case 'off'
                    obj.Background.PickableParts = 'none';
            end
        end
    end

    methods (Access = protected)

        function updateLocation(obj, mode)
            if ~obj.IsConstructed; return; end

            if nargin < 2; mode = obj.PositionMode; end
            updateLocation@uim.abstract.Component(obj, mode)
            obj.plotTrack()
            obj.plotKnobs()
            obj.plotText()
            obj.plotLabel()
        end

        function updateSize(obj, mode)
            if ~obj.IsConstructed; return; end

            if nargin < 2; mode = obj.SizeMode; end
            updateSize@uim.abstract.Component(obj, mode)
            obj.plotTrack()
            obj.plotKnobs()
        end
    end

    methods (Access = private) % Internal updating

        function [xCoords, yCoords] = getTextCoordinates(obj, whichKnob)

            [trackStart, trackLength] = obj.getTrackExtent();
            xCoords = uim.widget.internal.mapValueToPixel(...
                obj.getKnobValue(whichKnob), obj.getValueLimits(), ...
                trackStart, trackLength);
            yCoords = obj.Position(2) + obj.Position(4) .* 0.85;
        end

        function [xCoords, yCoords] = getKnobCoordinates(obj, whichKnob)

            [trackStart, trackLength] = obj.getTrackExtent();
            knobCenterX = uim.widget.internal.mapValueToPixel(...
                obj.getKnobValue(whichKnob), obj.getValueLimits(), ...
                trackStart, trackLength);
            knobCenterY = obj.Position(2) + obj.Position(4)/2;

            [xCoords, yCoords] = uim.widget.internal.knobOutline(...
                [knobCenterX, knobCenterY], obj.KnobSize/2);
        end

        function [xCoords, yCoords] = getTrackCoordinates(obj)

            xCoords = [obj.Position(1)+obj.Padding(1); ...
                            sum(obj.Position([1,3]))-obj.Padding(3)];

            yCoords = ones(2,1) .* obj.Position(2) + obj.Position(4) / 2;
        end

        function [xCoords, yCoords] = getTickCoordinates(obj)

            [trackStart, trackLength] = obj.getTrackExtent();
            yCenter = obj.Position(2) + obj.Position(4) / 2;
            numTicks = 9;

            [xCoords, yCoords] = uim.widget.internal.tickMarkCoordinates(...
                [trackStart, trackStart + trackLength], yCenter, ...
                obj.TickLength, obj.TickMode, numTicks);
        end

        function [trackStart, trackLength] = getTrackExtent(obj)
        %getTrackExtent Pixel start and length of the knobs' travel
            trackStart = obj.Position(1) + obj.Padding(1);
            trackLength = obj.Position(3) - sum(obj.Padding([1,3]));
        end

        function limits = getValueLimits(obj)
        %getValueLimits [Min, Max] of the slider
            limits = [obj.Min, obj.Max];
        end

        function value = getKnobValue(obj, whichKnob)
        %getKnobValue Value of the 'low' or 'high' knob as a double
            switch lower(whichKnob)
                case 'low'
                    value = double(obj.Low);
                case 'high'
                    value = double(obj.High);
                otherwise
                    error("uim:RangeSlider:UnknownKnob", ...
                        "Knob must be 'low' or 'high'; got ""%s"".", whichKnob)
            end
        end

        function updateValuetipString(obj, whichKnob)
            [xCoords, ~] = obj.getTextCoordinates(whichKnob);
            obj.ValueLabel.Position(1) = xCoords;

            switch whichKnob
                case 'low'
                    value = obj.Low;
                case 'high'
                    value = obj.High;
            end

            if mod(obj.StepSize, 1) < 1e-6
                obj.ValueLabel.String = num2str(value, '%.d');
            else
                obj.ValueLabel.String = num2str(value, '%.2f');
            end
        end

        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEnterKnob(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExitKnob(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.internal.setPointerBehavior(h, pointerBehavior)
        end
    end

    methods % Slider Interaction Callbacks

        function onSliderKnobPressed(obj, src, ~)
        %onSliderKnobPressed Start dragging the pressed knob
        %
        %   slider.onSliderKnobPressed(src, evt) is the ButtonDownFcn of
        %   both knobs; src is the knob patch. It listens to pointer
        %   motion and release in the figure, shows the active knob colors
        %   and, when ShowLabel is true, the value label.

            obj.IsKnobPressed = true;

            hFigure = ancestor(obj.Parent, 'figure');
            el1 = listener( hFigure, 'WindowMouseRelease', ...
                                @(s,e) obj.onSliderKnobReleased(src) );
            el2 = listener( hFigure, 'WindowMouseMotion', ...
                                @(s,e) obj.onSliderMoved(src, e));

            obj.WindowButtonUpListener = el1;
            obj.WindowMouseMotionListener = el2;

            switch src.Tag
                case 'Range Slider Low'
                    obj.updateValuetipString('low')
                    ind = 1;
                case 'Range Slider High'
                    obj.updateValuetipString('high')
                    ind = 2;
            end

            % todo: use button scheme for changing this
            obj.Knob(ind).FaceColor = obj.KnobFaceColorActive;
            obj.Knob(ind).EdgeColor = obj.KnobEdgeColorActive;

            if obj.ShowLabel
                obj.ValueLabel.Visible = 'on';
            end
        end

        function onSliderMoved(obj, src, ~)
        %onSliderMoved Move a knob to the pointer position
        %
        %   slider.onSliderMoved(src, evt) moves the knob given by src
        %   (a knob patch) to the pointer, or, when src is the track or
        %   background, the knob nearest to the pointer. When src is the
        %   track, it also calls Callback.

            mousePoint = obj.CanvasAxes.CurrentPoint(1, 1:2);

            [trackStart, trackLength] = obj.getTrackExtent();
            newValue = uim.widget.internal.mapPixelToValue(...
                mousePoint(1), obj.getValueLimits(), trackStart, trackLength);
            newValue = uim.widget.internal.snapToStep(newValue, obj.StepSize);

            switch src.Tag
                case 'Range Slider Low'
                    obj.onValueChanging(newValue, 'low')
                    obj.updateValuetipString('low')
                case 'Range Slider High'
                    obj.onValueChanging(newValue, 'high')
                    obj.updateValuetipString('high')
                otherwise
                    % Move the knob closest to where the track was pressed
                    whichValue = uim.widget.internal.nearestRangeKnob(...
                        newValue, obj.Low, obj.High);

                    obj.onValueChanging(newValue, whichValue)
                    obj.updateValuetipString(whichValue)
            end

            % make sure the callback is executed if source is the track
            if strcmp(src.Tag, 'Range Slider Track')
                obj.notifyValueChanged()
            end
        end

        function onSliderKnobReleased(obj, src, ~)
        %onSliderKnobReleased End a knob drag and notify through Callback
        %
        %   slider.onSliderKnobReleased(src) removes the drag listeners,
        %   restores the inactive colors of knob src, hides the value
        %   label and calls Callback.

            obj.IsKnobPressed = false;

            delete(obj.WindowButtonUpListener)
            delete(obj.WindowMouseMotionListener)
            obj.WindowButtonUpListener = [];
            obj.WindowMouseMotionListener = [];

            switch src.Tag
                case 'Range Slider Low'
                    ind = 1;
                case 'Range Slider High'
                    ind = 2;
            end

            % todo: use button scheme for changing this
            obj.Knob(ind).FaceColor = obj.KnobFaceColorInactive;
            obj.Knob(ind).EdgeColor = obj.KnobEdgeColorInactive;

            if obj.ShowLabel
                obj.ValueLabel.Visible = 'off';
            end

            obj.notifyValueChanged()
        end

        function onValueChanging(obj, newValue, whichValue)
        %onValueChanging Assign a knob value, clamped to the valid range
        %
        %   slider.onValueChanging(newValue, whichValue) sets Low
        %   (whichValue 'low') or High ('high', case-insensitive) to
        %   newValue, clamped to [Min, Max] and to the other knob.

            % Keep value within limits and range...

            if newValue <= obj.Min; newValue = obj.Min; end
            if newValue >= obj.Max; newValue = obj.Max; end

            switch lower(whichValue)
                case 'low'
                    if newValue >= obj.High; newValue = obj.High; end
                    obj.Low = newValue;
                case 'high'
                    if newValue <= obj.Low; newValue = obj.Low; end
                    obj.High = newValue;
            end
        end

        function onValueChanged(obj, ~, ~)
        %onValueChanged Redraw the knobs and notify after Low or High changed
        %
        %   slider.onValueChanged() redraws the knobs, calls
        %   ValueChangingFcn and, subject to CallbackRefreshRate, the
        %   Callback notification. The Low and High set methods call it.

            if obj.IsConstructed
                obj.plotKnobs()

                if ~isempty(obj.ValueChangingFcn)
                    evtData = struct('Low', obj.Low, 'High', obj.High);
                    obj.ValueChangingFcn(obj, evtData)
                end

                if isempty(obj.TicAtLastCallback) || ...
                        toc(obj.TicAtLastCallback) > 1/obj.CallbackRefreshRate
                    obj.notifyValueChanged()
                    obj.TicAtLastCallback = tic;
                end
            end
        end

        function onMouseEnterKnob(obj, hSource)
        %onMouseEnterKnob Lighten a knob while the pointer rests on it

            if ~obj.IsKnobPressed
                hSource.FaceColor = ones(1,3) * 0.95;
            end
        end

        function onMouseExitKnob(obj, hSource)
        %onMouseExitKnob Restore a knob when the pointer leaves it

            if ~obj.IsKnobPressed
                hSource.FaceColor = ones(1,3) * 0.8;
            end
        end
    end

    methods (Access = protected) % Host notification

        function notifyValueChanged(obj)
        %notifyValueChanged Notify the host of a new Low/High pair
        %
        %   Invokes the public Callback with a (Low, High) event struct.
        %   It runs when a knob is released or the track is pressed, and,
        %   at most CallbackRefreshRate times a second, whenever Low or
        %   High changes, including programmatic assignments. Subclasses
        %   override this to intercept those notifications; they should
        %   call the superclass method so a host-assigned Callback keeps
        %   working.

            if ~isempty(obj.Callback)
                evtData = struct('Low', obj.Low, 'High', obj.High);
                obj.Callback(obj, evtData)
            end
        end
    end

    methods % Set/get methods

        function set.Min(obj, newMin)
            assert(newMin < obj.Max_, "uim:RangeSlider:InvalidLimits", ...
                'Slider lower limit must be smaller than slider upper limit')
            oldValues = [obj.Low_, obj.High_];
            obj.Min_ = newMin;
            obj.Low_ = max(obj.Low_, obj.Min_);
            obj.High_ = max(obj.High_, obj.Low_);

            if obj.IsConstructed
                if isequal(oldValues, [obj.Low_, obj.High_])
                    obj.plotKnobs()
                else
                    obj.onValueChanged()
                end
            end
        end

        function min = get.Min(obj)
            min = obj.Min_;
        end

        function set.Max(obj, newMax)
            assert(newMax > obj.Min_, "uim:RangeSlider:InvalidLimits", ...
                'Slider upper limit must be larger than slider lower limit')
            oldValues = [obj.Low_, obj.High_];
            obj.Max_ = newMax;
            obj.High_ = min(obj.High_, obj.Max_);
            obj.Low_ = min(obj.Low_, obj.High_);

            if obj.IsConstructed
                if isequal(oldValues, [obj.Low_, obj.High_])
                    obj.plotKnobs()
                else
                    obj.onValueChanged()
                end
            end
        end

        function max = get.Max(obj)
            max = obj.Max_;
        end

        function set.Low(obj, newLow)
            %newLow = obj.Min_;
            assert(newLow >= obj.Min_, "uim:RangeSlider:InvalidLow", ...
                'Slider lower value must be greater than slider lower limit')
            assert(newLow <= obj.High_, "uim:RangeSlider:InvalidLow", ...
                'Slider lower value must be smaller than slider upper value')

            if newLow ~= obj.Low_
                obj.Low_ = newLow;
                obj.onValueChanged()
            end
        end

        function low = get.Low(obj)
            low = obj.Low_;
        end

        function set.High(obj, newHigh)
            assert(newHigh <= obj.Max_, "uim:RangeSlider:InvalidHigh", ...
                'Slider upper value must be smaller than slider upper limit')
            assert(newHigh >= obj.Low_, "uim:RangeSlider:InvalidHigh", ...
                'Slider upper value must be larger than slider lower value')

            if newHigh ~= obj.High_
                obj.High_ = newHigh;
                obj.onValueChanged()
            end
        end

        function high = get.High(obj)
            high = obj.High_;
        end

% %         function set.NumTicks(obj, newValue)
% %
% %         end

        function stepSize = get.StepSize(obj)
            stepSize = (obj.Max-obj.Min) / obj.NumTicks;
        end
    end

    methods (Static)
        function S = getTypeDefaults()
        %getTypeDefaults Default property values for this component type
        %
        %   S = uim.widget.RangeSlider.getTypeDefaults() returns a struct
        %   of property values used at construction. A name-value pair for
        %   the same property replaces the default.
            S.IsFixedSize = [true, true]; % No floating!
        end
    end
end
