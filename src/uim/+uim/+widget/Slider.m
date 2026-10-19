classdef Slider < handle
%Slider A horizontal slider with a round knob, drawn in axes
%
%   slider = uim.widget.Slider(Name=Value) creates a slider. All options
%   are name-value pairs naming public properties; there is no
%   positional parent argument. Names are case-insensitive and may be
%   abbreviated; unrecognized names are ignored. Step and FontSize
%   cannot be set at construction.
%
%   The Parent option selects how the slider is drawn:
%     - A figure or panel (default: the current figure). The slider
%       creates its own hidden axes at Position, in Units, and the knob
%       moves in data units between Min and Max. The track and ticks
%       follow the axes size in pixels, whatever the Units are.
%     - An existing axes. The slider draws into it at Position, given
%       in that axes' data units, and computes its geometry as if one
%       data unit is one pixel. Use an axes whose limits match its
%       pixel size. Deleting the slider leaves the axes in place.
%
%   Pressing the track moves the value to the pressed point; dragging
%   the knob moves it continuously. Values from the pointer are rounded
%   to the nearest Min + k*Step and clamped to [Min, Max]. When a
%   user interaction changes Value, the slider calls
%   Callback(slider, newValue). Assigning Value programmatically moves
%   the knob without calling Callback; values outside [Min, Max] are
%   ignored. While the knob is pressed, a value label is shown above it
%   (see ShowLabel, TooltipExpression, TooltipPrecision, TooltipUnits).
%
%   Min and Max given at construction are applied together, before the
%   other options; Min must be below Max. Without a Value option, the
%   default Value of 0.5 is moved into [Min, Max].
%
%   Assigning Min at or above Max, or Max at or below Min, raises
%   uim:Slider:InvalidLimits.
%
%   Example:
%       hFigure = figure;
%       slider = uim.widget.Slider(Parent=hFigure, Units="pixels", ...
%           Position=[20, 20, 200, 20], Min=1, Max=10, Value=1, ...
%           NumSteps=9, Callback=@(src, value) disp(value));
%
%   See also uim.widget.RangeSlider, uim.widget.ScrollBar

    % Todo: adapt to uim.widgets.

    % Todo: Allow vertical orientation...

    properties (Dependent = true)
        Min                     % Minimum slider value (default 0); must stay below Max
        Max                     % Maximum slider value (default 1); must stay above Min
    end

    properties

        % Current value, within [Min, Max]. Assignments outside the range
        % are ignored.
        Value = 0.5

        % Number of equal steps from Min to Max; sets Step. The allowed
        % values are Min + k*Step for k = 0 to NumSteps, and a tick mark
        % is drawn at each of them, NumSteps + 1 in all.
        NumSteps (1,1) double {mustBeInteger, mustBePositive} = 100

        Parent = []                 % Figure, panel or axes to draw in (default: current figure); used at construction

        BarColor = ones(1,3)*0.75;                  % Color of the track and tick marks
        KnobEdgeColorInactive = ones(1,3)*0.7;      % Knob edge color while the knob is not pressed
        KnobEdgeColorActive = [0.1195    0.6095    0.5395]; % Knob edge color while the knob is pressed
        KnobFaceColorInactive = ones(1,3)*0.95;     % Knob fill color while the knob is not pressed
        KnobFaceColorActive = ones(1,3)*0.8;        % Knob fill color while the knob is pressed
        TextColor = ones(1,3)*0.2;                  % Color of the value label
        TextBackgroundColor = 'none';               % Not applied to any graphics object

        TickLength = 0;     % Length of tick marks in pixels; 0 at construction draws no ticks
        TickWidth = 1;      % Line width of tick marks in points; used when the ticks are created
        % Tick placement relative to the track: 'over', 'under', 'both'
        % or 'underx2' (case-insensitive)
        TickMode = 'both'

        ValueChangedFcn     % Not called by Slider; use Callback
        ValueChangingFcn    % Not called by Slider; use Callback
        Callback            % Called as Callback(slider, newValue) when a user interaction changes Value

        % [x, y, width, height]. With a figure or panel Parent, the
        % position of the slider's own axes in Units; with an axes
        % Parent, the slider's rectangle in that axes' data units.
        Position = [0, 0, 0.1, 0.3]
        Units = 'normalized'    % Units of Position for the slider's own axes; used at construction
        Padding = [0,9,3,9];    % Track inset in pixels, [left, bottom, right, top]; only left and right are used

        Visible = 'on'          % 'on' or 'off'
        ShowLabel = true;       % Show the value label while the knob is pressed
        TooltipPrecision = 2;   % Number of decimals in the value label when TooltipExpression is empty
        TooltipUnits = '';      % Text appended to the value label when TooltipExpression is empty
        TooltipExpression       % sprintf format applied to Value for the value label, e.g. 'Z = %d'

        Style = 'Slider'        % Not applied to any graphics object
        Tag = ''                % Free-form tag stored on the slider object
    end

    properties (Dependent = true)
        Step        % Value step size, (Max - Min)/NumSteps (read-only)
        FontSize    % Font size of the value label; NaN before the label exists
    end

    properties (Constant, Access = private)
        KnobDiameter = 15   % Pixels
    end

    properties (Access = private)
        % Values behind the Dependent Min and Max, so that each limit's
        % set method can check the new value against the other limit.
        Min_ = 0
        Max_ = 1

        Axes
        OwnsAxes = false;

        Track
        Knob
        ValueLabel
        Background
        Ticks = gobjects(0)

        WindowButtonUpListener
        WindowMouseMotionListener
        IsConstructed = false
    end

    methods % Structor

        function obj = Slider(varargin)
        %Slider Create a slider
        %
        %   slider = uim.widget.Slider(Name=Value) creates a slider. See
        %   the class help for the options and drawing modes.

            obj.parsevarargin(varargin)

            obj.createSlider()

            % Knob drags read CurrentPoint from motion listeners; in
            % java figures that requires a WindowButtonMotionFcn.
            uim.internal.ensurePointerMotionTracking(...
                ancestor(obj.Axes, 'figure'))

            obj.IsConstructed = true;
        end

        function delete(obj)
            if obj.OwnsAxes
                delete(obj.Axes)
            else
                delete(obj.Track)
                delete(obj.Knob)
                delete(obj.ValueLabel)
                delete(obj.Background)
                delete(obj.Ticks)
            end
        end
    end

    methods (Access = private) % Initialization
        function parsevarargin(obj, varargin)

            if isempty(varargin); return; end

            propNames = properties(obj);

            % Min and Max are Dependent only to have backing values; they
            % are still name-value options.
            dependentProps = setdiff(uim.utility.findProperties(obj, 'Dependent'), {'Min', 'Max'});
            propNames = setdiff(propNames, dependentProps);

            defaultValues = cellfun(@(name) obj.(name), propNames, 'uni', 0);
            def = cell2struct(defaultValues, propNames, 1);

            props = uim.utility.parseNameValue(def, varargin{1}{:});

            % set.Min and set.Max each check against the other limit,
            % which still has its default during option parsing, so the
            % limits are validated and assigned together here
            assert(props.Min < props.Max, "uim:Slider:InvalidLimits", ...
                'Slider lower limit must be smaller than slider upper limit')
            obj.Min_ = props.Min;
            obj.Max_ = props.Max;
            propNames = setdiff(propNames, {'Min', 'Max'});

            optionNames = string(varargin{1}(1:2:end));
            if ~any(strcmpi(optionNames, "Value"))
                props.Value = min(max(props.Value, props.Min), props.Max);
            end

            for i = 1:numel(propNames)
                obj.(propNames{i}) = props.(propNames{i});
            end
        end

        function createSlider(obj)

            if isempty(obj.Parent)
                obj.Parent = gcf;
            end

            if ~isa(obj.Parent, 'matlab.graphics.axis.Axes')
                obj.createAxes()
                obj.updateAxesLimits()
            else
                obj.Axes = obj.Parent;
            end

            % If using a caller-supplied axes, make sure hold is on for the
            % duration of construction so that each new graphics object
            % does not clear the ones already plotted (NextPlot default
            % behavior when hold is off). createAxes() already turns hold
            % on for a private axes that slidebar owns exclusively.
            if ~obj.OwnsAxes
                wasHoldOn = ishold(obj.Axes);
                hold(obj.Axes, 'on');
            end

            % Slider and especially the slider track is thin, and its easy
            % to miss when pressing it. Patch background so that
            % mousepresses are still captured by this widget on close miss.
            [xCoords, yCoords] = obj.getBackgroundCoordinates();
            obj.Background = patch(obj.Axes, xCoords, yCoords, 'w');
            obj.Background.FaceAlpha = 0; % Makes it hittable
            obj.Background.EdgeColor = 'none';
            obj.Background.PickableParts = 'all';

            % Start plotting ticks, so that they are behind everything else
            if obj.TickLength ~= 0
                obj.plotTicks()
            end

            % Plot the bar as a line
            [xCoords, yCoords] = obj.getBarCoordinates();
%             obj.Track = plot(obj.Axes, xCoords, yCoords);
%             obj.Track.LineWidth = 3;
%             obj.Track.Color = obj.BarColor;

            obj.Track = patch(obj.Axes, xCoords, yCoords, obj.BarColor);

            obj.Track.HitTest = 'on';
            obj.Track.PickableParts = 'visible';
            obj.Track.FaceColor = obj.BarColor;
            obj.Track.EdgeColor = 'none';

            obj.Background.ButtonDownFcn = @(src, event) obj.moveSlider;
            obj.Track.ButtonDownFcn = @(src, event) obj.moveSlider;

            % Patch the slider knob using aspect ratio adjusted coords.
            [xCoords, yCoords] = obj.getKnobCoordinates();
            obj.Knob = patch(obj.Axes, xCoords, yCoords, ones(1,3)*0.5);
            obj.Knob.LineWidth = 1;
            obj.Knob.FaceColor = obj.KnobFaceColorInactive;
            obj.Knob.EdgeColor = obj.KnobEdgeColorInactive;
            obj.Knob.ButtonDownFcn = @(src, event) obj.activateSlider;
            obj.Knob.Clipping = 'off';

            % Create a text object for displaying the current value when
            % the slider is active.
            [xCoords, yCoords] = obj.getTextCoordinates();
            obj.ValueLabel = text(obj.Axes, xCoords, yCoords, '');
            obj.ValueLabel.VerticalAlignment = 'Bottom';
            obj.ValueLabel.HorizontalAlignment = 'Left';
            obj.ValueLabel.Color = obj.TextColor;
            obj.ValueLabel.FontSize = obj.FontSize;
            obj.updateValuetipString()

            % Set visibility of subcomponents.
            obj.Track.Visible = obj.Visible;
            obj.Knob.Visible = obj.Visible;
            obj.Background.Visible = obj.Visible;
            obj.ValueLabel.Visible = 'off';

            % Add listener on axes resize
            if obj.OwnsAxes
                addlistener(obj.Axes, 'Position', 'PostSet', ...
                    @(s,e) obj.onPositionChanged);
            end

            if ~obj.OwnsAxes && ~wasHoldOn
                hold(obj.Axes, 'off');
            end
        end

        function createAxes(obj)

            % Create an axes which will be the container for this widget.
            obj.Axes = axes('Parent', obj.Parent);
            hold(obj.Axes, 'on');
            obj.Axes.Visible = 'off';
            obj.Axes.Units = obj.Units;
            obj.Axes.Position = obj.Position;
            obj.Axes.HandleVisibility = 'off';
            obj.Axes.Tag = 'SlideBar Container';

            obj.Axes.YLim = [0,1];
            obj.Axes.XLim = [obj.Min, obj.Max];
            obj.OwnsAxes = true;

            uim.internal.disableAxesInteractivity(obj.Axes)
        end

        function plotTicks(obj)
            [x, y] = getTickCoordinates(obj);
            % line adds to the axes whatever its NextPlot is, so ticks
            % created after construction keep the other parts in a
            % caller's axes. It draws one line object per tick.
            obj.Ticks = line(obj.Axes, x, y, 'Color', obj.BarColor, 'LineWidth', obj.TickWidth);

            if obj.IsConstructed
                uistack(obj.Ticks, 'bottom')
            end
        end

        function redrawTicks(obj)
            if isempty(obj.Ticks); return; end
            [xCoords, yCoords] = getTickCoordinates(obj);
            numTicks = size(xCoords, 2);

            % Each tick is its own line object, so a new number of ticks
            % needs new lines
            if numel(obj.Ticks) ~= numTicks
                delete(obj.Ticks)
                obj.plotTicks()
                return
            end

            xCoords = mat2cell(xCoords', ones(numTicks, 1));
            yCoords = mat2cell(yCoords', ones(numTicks, 1));
            set(obj.Ticks, {'XData'}, xCoords, {'YData'}, yCoords)
        end
    end

    methods (Access = private) % Internal updating

        function [xCoords, yCoords] = getTextCoordinates(obj)
            if obj.OwnsAxes
                xCoords = obj.Value;
                yCoords = obj.Axes.YLim(2) .* 1.4; % Ad hoc offset.
            else
                [trackStart, trackLength] = obj.getTrackExtent();
                xCoords = uim.widget.internal.mapValueToPixel(...
                    obj.Value, [obj.Min, obj.Max], trackStart, trackLength);
                yCoords = obj.Position(2) + obj.Position(4) .* 0.9;
            end
        end

        function updateAxesLimits(obj)
        %updateAxesLimits Widen XLim so the knob stays fully visible at either end
        %
        %   The margin is one knob diameter, as a fraction of the axes
        %   width, of Max - Min. Every part of a slider in its own axes is
        %   converted between pixels and data units with these limits, so
        %   they are set before any geometry is computed.
            axPosition = getpixelposition(obj.Axes);
            valueRange = obj.Max - obj.Min;
            obj.Axes.XLim = [obj.Min, obj.Max] + ...
                [-1, 1] .* valueRange .* (obj.KnobDiameter / axPosition(3));
        end

        function [xCoords, yCoords] = getKnobCoordinates(obj)

            knobDiameter = obj.KnobDiameter;

            if obj.OwnsAxes

                axPosition = getpixelposition(obj.Axes);
                axesSizePixels = axPosition(3:4);

                % Scaling the radii per axis by the data units per pixel
                % keeps the knob round on screen whatever the axes limits
                % are.
                dataUnitsPerPixel = [uim.utility.range(obj.Axes.XLim), ...
                    uim.utility.range(obj.Axes.YLim)] ./ axesSizePixels;

                [xCoords, yCoords] = uim.widget.internal.knobOutline(...
                    [obj.Value, 0.5], knobDiameter/2 .* dataUnitsPerPixel);
            else
                [trackStart, trackLength] = obj.getTrackExtent();
                knobCenterX = uim.widget.internal.mapValueToPixel(...
                    obj.Value, [obj.Min, obj.Max], trackStart, trackLength);
                knobCenterY = obj.Position(2) + obj.Position(4)/2;

                [xCoords, yCoords] = uim.widget.internal.knobOutline(...
                    [knobCenterX, knobCenterY], knobDiameter/2);
            end
        end

        function [xCoords, yCoords] = getBarCoordinates(obj)
            if obj.OwnsAxes
                barWidth = 3;
                pixelPosition = obj.getPixelPosition();

                % The track spans the knob's travel, [Min, Max]. The
                % outline is made in pixels so the rounded ends keep their
                % shape, then stretched onto [Min, Max] because rectangle
                % rounds its width to whole pixels.
                valueRange = obj.Max - obj.Min;
                trackLength = valueRange / diff(obj.Axes.XLim) * pixelPosition(3);
                [edgeX, edgeY] = uim.shape.rectangle([trackLength, barWidth], barWidth/2);
                edgeY = edgeY + pixelPosition(4)/2 - barWidth/2;
                coords = uim.utility.px2du(obj.Axes, [edgeX', edgeY']);
                xCoords = obj.Min + edgeX ./ max(edgeX) .* valueRange;
                yCoords = coords(:,2)';

            else
                barLength = obj.Position(3)-sum(obj.Padding([1,3]));

                [xCoords, yCoords] = uim.shape.rectangle([barLength, 3], 1.5);
                xCoords = xCoords + obj.Position(1)+obj.Padding(1);
                yCoords = yCoords + obj.Position(2) + obj.Position(4) / 2 - 1;
            end
        end

        function [xCoords, yCoords] = getTickCoordinates(obj)

            pixelPosition = obj.getPixelPosition();
            yCenter = pixelPosition(2) + pixelPosition(4) / 2;

            % One tick per allowed value, Min + k*Step for k = 0 to
            % NumSteps. The ticks span the knob's travel with no edge
            % inset, so the outer ticks sit under the knob centre at Min
            % and Max.
            numTicks = obj.NumSteps + 1;

            if obj.OwnsAxes
                % The knob travels over [Min, Max] in data units. The tick
                % lengths are in pixels, so only y is converted.
                [xCoords, yCoords] = uim.widget.internal.tickMarkCoordinates(...
                    [obj.Min, obj.Max], yCenter, ...
                    obj.TickLength, obj.TickMode, numTicks, 0);
                pixelPoints = [zeros(numel(yCoords), 1), yCoords(:)];
                dataPoints = uim.utility.px2du(obj.Axes, pixelPoints);
                yCoords = reshape(dataPoints(:,2), size(yCoords));
            else
                [trackStart, trackLength] = obj.getTrackExtent();
                [xCoords, yCoords] = uim.widget.internal.tickMarkCoordinates(...
                    [trackStart, trackStart + trackLength], yCenter, ...
                    obj.TickLength, obj.TickMode, numTicks, 0);
            end
        end

        function [trackStart, trackLength] = getTrackExtent(obj)
        %getTrackExtent Pixel start and length of the knob's travel
            pixelPosition = obj.getPixelPosition();
            trackStart = pixelPosition(1) + obj.Padding(1);
            trackLength = pixelPosition(3) - sum(obj.Padding([1,3]));
        end

        function pixelPosition = getPixelPosition(obj)
        %getPixelPosition Slider rectangle in the pixels the geometry uses
        %
        %   In its own axes the slider is drawn from the axes origin, and
        %   Position may be in any Units, so the axes size in pixels is
        %   used. In a caller's axes Position is already in the pixel-like
        %   data units the geometry is computed in.
            if obj.OwnsAxes
                axesPosition = getpixelposition(obj.Axes);
                pixelPosition = [0, 0, axesPosition(3:4)];
            else
                pixelPosition = obj.Position;
            end
        end

        function [xCoords, yCoords] = getBackgroundCoordinates(obj)
            if obj.OwnsAxes
                xCoords = obj.Axes.XLim([1,1,2,2,1]);
                yCoords = obj.Axes.YLim([2,1,1,2,2]);
            else
                w = obj.Position(3); h = obj.Position(4);
                xCoords = obj.Position(1) + [0, 0, w, w, 0];
                yCoords = obj.Position(2) + [h, 0, 0, h, h];
            end
        end

        function updateValuetipString(obj)
            [xCoords, ~] = obj.getTextCoordinates();
            obj.ValueLabel.Position(1) = xCoords;

            if isempty(obj.TooltipExpression)
                formatStr = sprintf('%%.%df', obj.TooltipPrecision);
                tooltipStr = num2str(obj.Value, formatStr);
                if ~isempty(obj.TooltipUnits)
                    tooltipStr = sprintf('%s %s', tooltipStr, obj.TooltipUnits);
                end
            else
                tooltipStr = sprintf(obj.TooltipExpression, obj.Value);
            end

            obj.ValueLabel.String = tooltipStr;
        end

        function onPositionChanged(obj)

            if ~obj.IsConstructed; return; end

            if obj.OwnsAxes
                obj.updateAxesLimits()
            end

            [xCoords, yCoords] = obj.getTextCoordinates();
            obj.ValueLabel.Position(1:2) = [xCoords, yCoords];

            [xCoords, yCoords] = getKnobCoordinates(obj);
            set(obj.Knob, 'XData', xCoords, 'YData', yCoords)

            [xCoords, yCoords] = getBarCoordinates(obj);
            set(obj.Track, 'XData', xCoords, 'YData', yCoords)

            [xCoords, yCoords] = getBackgroundCoordinates(obj);
            set(obj.Background, 'XData', xCoords, 'YData', yCoords)

            if ~isempty(obj.Ticks)
                obj.redrawTicks()
            end
        end

        function onVisibleChanged(obj)

            obj.Knob.Visible = obj.Visible;
            obj.Track.Visible = obj.Visible;
            obj.Background.Visible = obj.Visible;

            switch obj.Visible
                case 'on'
                    obj.Background.PickableParts = 'all';
                case 'off'
                    obj.Background.PickableParts = 'none';
            end
        end

        function onStyleChanged(obj)

            if obj.IsConstructed
                obj.ValueLabel.Color = obj.TextColor;
            end
        end

        function onTickLengthSet(obj)
            if ~obj.IsConstructed; return; end

            if obj.TickLength ~= 0 && isempty(obj.Ticks)
                obj.plotTicks()
            elseif obj.TickLength ~= 0
                obj.redrawTicks()
            end
        end

        function onNumStepsSet(obj)
            if ~obj.IsConstructed; return; end
            obj.redrawTicks()
        end

        function onBarColorSet(obj)
            if ~isempty(obj.Track)
                obj.Track.FaceColor = obj.BarColor;
            end
        end

        function onKnobColorSet(obj)
            if ~isempty(obj.Knob)
                obj.Knob.EdgeColor = obj.KnobEdgeColorInactive;
                obj.Knob.FaceColor = obj.KnobFaceColorInactive;
            end
        end
    end

    methods % Set/Get

        function set.Position(obj, newPos)
            obj.Position = newPos;

            if ~isempty(obj.Axes) && obj.OwnsAxes
                obj.Axes.Position = newPos;
            end

            obj.onPositionChanged();
        end

        function set.Value(obj, newValue)

            if all(obj.isValueInRange(newValue)) && all(newValue ~= obj.Value)

                obj.Value = newValue;

                if ~isempty(obj.Knob)                                        %#ok<MCSUP>
                    [xCoords, ~] = obj.getKnobCoordinates();
                    obj.Knob.XData = xCoords;        %#ok<MCSUP>
                    obj.updateValuetipString()
                    % newValue
                end
            end
        end

        function tf = isValueInRange(obj, newValue)
        %isValueInRange Test whether values lie within [Min, Max]
        %
        %   tf = slider.isValueInRange(newValue) returns a logical array
        %   the size of newValue, true where Min <= newValue <= Max.

            tf = newValue >= obj.Min & newValue <= obj.Max;
        end

%         function set.Range(obj, newRange)
%             assert(newRange(1) < newRange(2), 'Slider lower limit must be smaller than slider upper limit')
%             obj.Min = newRange(1);
%             obj.Max = newRange(2);
%         end
%
%         function range = get.Range(obj)
%             range = [obj.Min, obj.Max];
%         end
%

        function set.Min(obj, newMin)
            assert(newMin < obj.Max_, "uim:Slider:InvalidLimits", ...
                'Slider lower limit must be smaller than slider upper limit')
            obj.Min_ = newMin;

            if ~isempty(obj.Axes) && obj.OwnsAxes
                obj.onPositionChanged();
            end
        end

        function minValue = get.Min(obj)
            minValue = obj.Min_;
        end

        function set.Max(obj, newMax)
            assert(newMax > obj.Min_, "uim:Slider:InvalidLimits", ...
                'Slider upper limit must be larger than slider lower limit')
            obj.Max_ = newMax;

            if ~isempty(obj.Axes) && obj.OwnsAxes
                obj.onPositionChanged();
            end
        end

        function maxValue = get.Max(obj)
            maxValue = obj.Max_;
        end

%         function set.Step(obj, newValue)
%             obj.Step = newValue;
%         end

        function stepSize = get.Step(obj)
            stepSize = (obj.Max-obj.Min) / obj.NumSteps;
        end

        function set.TextColor(obj, newValue)

            assert(isa(newValue, 'numeric') || isa(newValue, 'char'))
            obj.TextColor = newValue;
            obj.onStyleChanged()
        end

        function set.Visible(obj, newValue)
            newValue = validatestring(newValue, {'on', 'off'});
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end

        function set.FontSize(obj, newValue)
            if ~isempty(obj.ValueLabel)
                obj.ValueLabel.FontSize = newValue;
            end
        end

        function fontSize = get.FontSize(obj)
            if ~isempty(obj.ValueLabel)
                fontSize = obj.ValueLabel.FontSize;
            else
                fontSize = nan;
            end
        end
% %         function visible = get.Visible(obj)
% %             if isempty(obj.Track)
% %                 visible = 'off';
% %             else
% %                 visible = obj.Track.Visible;
% %             end
% %         end

        function set.KnobEdgeColorInactive(obj, newColor)
            obj.KnobEdgeColorInactive = newColor;
            obj.onKnobColorSet()
        end

        function set.KnobFaceColorInactive(obj, newColor)
            obj.KnobFaceColorInactive = newColor;
            obj.onKnobColorSet()
        end

        function set.BarColor(obj, newColor)
            obj.BarColor = newColor;
            obj.onBarColorSet()
        end

        function set.NumSteps(obj, newValue)
            obj.NumSteps = newValue;
            obj.onNumStepsSet()
        end

        function set.TickLength(obj, newValue)
            assert(isnumeric(newValue), 'TickLength must be a number')
            obj.TickLength = newValue;
            obj.onTickLengthSet()
        end
    end

    methods % Slider Interaction Callbacks

        function activateSlider(obj)
        %activateSlider Start a knob drag
        %
        %   slider.activateSlider() is the knob's ButtonDownFcn. It
        %   listens to pointer motion and release in the figure, shows
        %   the active knob colors and, when ShowLabel is true, the
        %   value label.

            hFigure = ancestor(obj.Parent, 'figure');
            el1 = listener(hFigure, 'WindowMouseRelease', @(s,e) obj.deactivateSlider);
            el2 = listener(hFigure, 'WindowMouseMotion', @obj.moveSlider);

            obj.WindowButtonUpListener = el1;
            obj.WindowMouseMotionListener = el2;

            obj.Knob.FaceColor = obj.KnobFaceColorActive;
            obj.Knob.EdgeColor = obj.KnobEdgeColorActive;

            if obj.ShowLabel
                obj.ValueLabel.Visible = 'on';
            end
        end

        function moveSlider(obj, ~, ~)
        %moveSlider Move the value to the pointer position
        %
        %   slider.moveSlider() reads the pointer position in the slider's
        %   axes, rounds the matching value to the nearest Min + k*Step and
        %   applies it through valueChangedCallback. It is the
        %   ButtonDownFcn of the track and background, and the motion
        %   callback during a knob drag.

            % CurrentPoint only follows the pointer while the figure has
            % a WindowButtonMotionFcn; the constructor guarantees one via
            % uim.internal.ensurePointerMotionTracking.
            mousePoint = get(obj.Axes, 'CurrentPoint');

            if obj.OwnsAxes
                newValue = mousePoint(1);
            else
                [trackStart, trackLength] = obj.getTrackExtent();
                newValue = uim.widget.internal.mapPixelToValue(...
                    mousePoint(1), [obj.Min, obj.Max], trackStart, trackLength);
            end

            newValue = uim.widget.internal.snapToStep(newValue, obj.Step, obj.Min);

            if ~isequal(newValue, obj.Value)
                obj.valueChangedCallback(newValue)
            end
        end

        function deactivateSlider(obj)
        %deactivateSlider End a knob drag
        %
        %   slider.deactivateSlider() removes the drag listeners, restores
        %   the inactive knob colors and hides the value label.

            delete(obj.WindowButtonUpListener)
            delete(obj.WindowMouseMotionListener)
            obj.WindowButtonUpListener = [];
            obj.WindowMouseMotionListener = [];

            obj.Knob.FaceColor = obj.KnobFaceColorInactive;
            obj.Knob.EdgeColor = obj.KnobEdgeColorInactive;

            if obj.ShowLabel
                obj.ValueLabel.Visible = 'off';
            end
        end

        function valueChangedCallback(obj, newValue)
        %valueChangedCallback Apply a value from user interaction
        %
        %   slider.valueChangedCallback(newValue) clamps newValue to
        %   [Min, Max]. If the result differs from Value, it assigns
        %   Value and calls Callback(slider, newValue).

            if newValue <= obj.Min; newValue = obj.Min; end
            if newValue >= obj.Max; newValue = obj.Max; end

            if newValue ~= obj.Value

                obj.Value = newValue;

                if ~isempty(obj.Callback)
                    obj.Callback(obj, newValue)
                end
            end
        end

        function onValueChanging(obj, newValue)
        %onValueChanging Apply a value from user interaction
        %
        %   slider.onValueChanging(newValue) behaves as
        %   valueChangedCallback: it clamps newValue to [Min, Max] and,
        %   if Value changes, calls Callback(slider, newValue).
            if newValue <= obj.Min; newValue = obj.Min; end
            if newValue >= obj.Max; newValue = obj.Max; end

            if newValue ~= obj.Value
                obj.Value = newValue;

                if ~isempty(obj.Callback)
                    obj.Callback(obj, newValue)
                end
            end
        end
    end
end
