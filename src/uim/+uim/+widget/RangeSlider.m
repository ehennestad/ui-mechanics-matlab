classdef RangeSlider < uim.abstract.Control & matlab.mixin.SetGet

    % Todo:
    %   [ ] add vertical orientation
    %   [ ] updateSize and updateLocation should happen automatically when
    %   position is set.

    properties (Constant)
        Type = 'RangeSlider'
    end

    properties (Dependent)
        Min                 % Minimum possible slider value
        Max                 % Maximum possible slider value
        Low                 % Current low value of slider
        High                % Current high value of slider
    end

    properties
        NumTicks = 100

        LabelLocation = 'left'      % Todo: Add to superclass (a widget class)

        TrackWidth = 2              % Width of the slider track
        TrackColor = ones(1,3)*0.75;
        KnobSize = 15
        KnobMarkerStyle = 'round'   % Only round available should implement line/bar

        % Todo: move to uim.style definition....
        KnobEdgeColorInactive = ones(1,3)*0.7;
        KnobEdgeColorActive = [0.1195    0.6095    0.5395]; % ones(1,3)*0.3; %;
        KnobFaceColorInactive = ones(1,3)*0.8;
        KnobFaceColorActive = ones(1,3)*0.65;

        TickLength = 5 % Length of tick marks

        TextColor = ones(1,3)*0.8;
        TextBackgroundColor = 'none';

        ShowLabel = true; % Show value label

        ValueChangingFcn = []

        CallbackRefreshRate = inf % allowed number of updates per second. Useful for applications that do heavy computations.
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

        WindowButtonUpListener
        WindowMouseMotionListener
    end

    methods % Structors

        function obj = RangeSlider(hParent, varargin)

            obj@uim.abstract.Control(hParent, varargin{:})

            % Knob drags read CurrentPoint from motion listeners; in
            % java figures that requires a WindowButtonMotionFcn.
            uim.utility.ensurePointerMotionTracking(...
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

            assert(obj.Min_ < obj.Max_, ...
                'Slider lower limit must be smaller than slider upper limit')
            assert(obj.Low_ >= obj.Min_ && obj.Low_ <= obj.High_, ...
                'Slider lower value must be within the selected range')
            assert(obj.High_ <= obj.Max_, ...
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

            if nargin < 2; mode = obj.PositionMode; end
            updateSize@uim.abstract.Component(obj, mode)
            obj.plotTrack()
            obj.plotKnobs()
        end
    end

    methods (Access = private) % Internal updating

        function [xCoords, yCoords] = getTextCoordinates(obj, whichKnob)

            xRangeSlider = obj.Max - obj.Min;

            switch lower(whichKnob)
                case 'low'
                    xRelativePosition = (obj.Low - obj.Min) ./ xRangeSlider;
                case 'high'
                    xRelativePosition = (obj.High - obj.Min) ./ xRangeSlider;
            end

            xRangeAxes = obj.Position(3) - sum( obj.Padding([1,3]) );
            xCoords = obj.Position(1) + obj.Padding(1) + ...
                xRangeAxes .* xRelativePosition;
            yCoords = obj.Position(2) + obj.Position(4) .* 0.85;
        end

        function [xCoords, yCoords] = getKnobCoordinates(obj, whichKnob)

            sliderSize = obj.KnobSize;
            theta = linspace(0, 2*pi, 200);

            rho = ones(size(theta)) .* 0.5 .* sliderSize;
            [xCoords, yCoords] = pol2cart(theta, rho);

            xRange = obj.Max - obj.Min;

            switch lower(whichKnob)
                case 'low'
                    xRelativePosition = (obj.Low - obj.Min) ./ xRange;
                case 'high'
                    xRelativePosition = (obj.High - obj.Min) ./ xRange;
            end

            xRelativePosition = double(xRelativePosition);

            xCoords = xCoords + obj.Position(1) + obj.Padding(1) + ...
                (obj.Position(3)-sum(obj.Padding([1,3]))) .* xRelativePosition;
            yCoords = yCoords + obj.Position(2) + obj.Position(4)/2;
        end

        function [xCoords, yCoords] = getTrackCoordinates(obj)

            xCoords = [obj.Position(1)+obj.Padding(1); ...
                            sum(obj.Position([1,3]))-obj.Padding(3)];

            yCoords = ones(2,1) .* obj.Position(2) + obj.Position(4) / 2;
        end

        function [xCoords, yCoords] = getTickCoordinates(obj)

            % Todo....

            x1 = obj.Position(1)+obj.Padding(1);
            x2 = sum(obj.Position([1,3]))-obj.Padding(3);

            % Correct for linewidth
            x1 = x1+2;
            x2 = x2-2;

            y1 = obj.Position(2) + obj.Position(4) / 2;
            y2 = y1 - obj.TickLength;

            if strcmp(obj.TickMode, 'both')
               y1 = y1+obj.TickLength/2;
               y2 = y2+obj.TickLength/2;
            elseif strcmp(obj.TickMode, 'over')
                y1 = y1+obj.TickLength;
                y2 = y2+obj.TickLength;
            elseif strcmp(obj.TickMode, 'underx2')
                y1 = y1-obj.TickLength;
                y2 = y2-obj.TickLength;
            end

            numTicks = 9;
            xCoords = linspace(x1,x2,numTicks);
            xCoords = repmat(xCoords, 3, 1);
            xCoords(3,:) = nan;

            yCoords = repmat([y1;y2;nan], 1, numTicks);
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

            uim.utility.setPointerBehavior(h, pointerBehavior)
        end
    end

    methods % Slider Interaction Callbacks

        function onSliderKnobPressed(obj, src, ~)

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

            mousePoint = obj.CanvasAxes.CurrentPoint(1, 1:2);

            % Calculate value based on position in axes and relative range
            % of axes.
            xRange = obj.Max-obj.Min;

            newValue = (mousePoint(1) - obj.Position(1) - obj.Padding(1)) / ...
                (obj.Position(3)-sum(obj.Padding([1,3]))) .* xRange + obj.Min;

            % Round to nearest point...
            newValue = round(newValue/obj.StepSize) * obj.StepSize;

            switch src.Tag
                case 'Range Slider Low'
                    obj.onValueChanging(newValue, 'low')
                    obj.updateValuetipString('low')
                case 'Range Slider High'
                    obj.onValueChanging(newValue, 'high')
                    obj.updateValuetipString('high')
                otherwise
                    % Move the knob which is closest to where the track was
                    % pressed
                    if newValue <= obj.Low
                        whichValue = 'low';
                    elseif newValue >= obj.High
                        whichValue = 'high';
                    else
                        if abs(newValue-obj.Low) > abs(newValue-obj.High)
                            whichValue = 'high';
                        else
                            whichValue = 'low';
                        end
                    end

                    obj.onValueChanging(newValue, whichValue)
                    obj.updateValuetipString(whichValue)
            end

            % make sure the callback is executed if source is the track
            if strcmp(src.Tag, 'Range Slider Track')
                if ~isempty(obj.Callback)
                    evtData = struct('Low', obj.Low, 'High', obj.High);
                    obj.Callback(obj, evtData)
                end
            end
        end

        function onSliderKnobReleased(obj, src, ~)

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

            if ~isempty(obj.Callback)
                evtData = struct('Low', obj.Low, 'High', obj.High);
                obj.Callback(obj, evtData)
            end
        end

        function onValueChanging(obj, newValue, whichValue)

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

            persistent ticAtLastUpdate
            if isempty(ticAtLastUpdate); ticAtLastUpdate = tic; end

            if obj.IsConstructed
                obj.plotKnobs()

                if ~isempty(obj.ValueChangingFcn)
                    evtData = struct('Low', obj.Low, 'High', obj.High);
                    obj.ValueChangingFcn(obj, evtData)
                end

                if ~isempty(obj.Callback) && toc(ticAtLastUpdate) > 1/obj.CallbackRefreshRate
                    evtData = struct('Low', obj.Low, 'High', obj.High);
                    obj.Callback(obj, evtData)
                    ticAtLastUpdate = tic;
                end
            end
        end

        function onMouseEnterKnob(obj, hSource, ~)

            if ~obj.IsKnobPressed
                hSource.FaceColor = ones(1,3) * 0.95;
            end
        end

        function onMouseExitKnob(obj, hSource, ~)
            if ~obj.IsKnobPressed
                hSource.FaceColor = ones(1,3) * 0.8;
            end
        end
    end

    methods % Set/get methods

        function set.Min(obj, newMin)
            assert(newMin < obj.Max_, 'Slider lower limit must be smaller than slider upper limit')
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
            assert(newMax > obj.Min_, 'Slider upper limit must be larger than slider lower limit')
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
            assert(newLow >= obj.Min_, 'Slider lower value must be greater than slider lower limit')
            assert(newLow <= obj.High_, 'Slider lower value must be smaller than slider upper value')

            if newLow ~= obj.Low_
                obj.Low_ = newLow;
                obj.onValueChanged()
            end
        end

        function low = get.Low(obj)
            low = obj.Low_;
        end

        function set.High(obj, newHigh)
            assert(newHigh <= obj.Max_, 'Slider upper value must be smaller than slider upper limit')
            assert(newHigh >= obj.Low_, 'Slider upper value must be larger than slider lower value')

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
            S.IsFixedSize = [true, true]; % No floating!
        end
    end
end
