classdef ContrastSlider < uim.widget.RangeSlider
%ContrastSlider A range slider speaking contrast/CLim semantics
%
%   slider = uim.widget.ContrastSlider(hParent, Name, Value, ...)
%   creates a contrast slider in hParent (a figure, panel, axes or uim
%   canvas). It wraps RangeSlider with the push/notify contract used for
%   image contrast control:
%
%   The host pushes state in:
%       DataLimits - [min, max] full range of the data
%       Limits     - [low, high] current contrast (CLim) limits
%
%   User interactions notify the host through
%   LimitsChangedFcn(src, evt), where evt is a
%   uim.event.ValueChangedEventData whose OldValue/NewValue are
%   [low, high] pairs. The widget guarantees NewValue is strictly
%   increasing (the host never needs to guard against a collapsed
%   range before assigning it to CLim). Programmatic assignment to
%   Limits/DataLimits updates the display without firing the callback.
%
%   The auto button (shown while ShowAutoButton is 'on') fires
%   AutoRequestedFcn(src, evt): computing auto levels needs the image
%   data, so the host computes them and pushes the result back through
%   Limits (and applies its own CLim).
%
%   An intensity histogram can be drawn behind the track
%   (imcontrast-style) by pushing bin counts spanning DataLimits into
%   HistogramCounts, e.g.:
%       slider.HistogramCounts = sqrt(histcounts(im(:), ...
%           linspace(dataLimits(1), dataLimits(2), 129)));
%   The counts are normalized to their maximum; apply sqrt/log before
%   pushing to compress spiky histograms. Empty hides the histogram.
%
%   The histogram button (shown while ShowHistogramButton is 'on')
%   toggles HistogramVisible; toggling it ON fires
%   HistogramRequestedFcn(src, evt) so the host can compute counts
%   lazily. Recommended pattern for image streams: skip histogram
%   computation while HistogramVisible is 'off' (e.g. during frame
%   scrubbing), and refresh in HistogramRequestedFcn — counts are only
%   ever computed when someone is looking at them:
%       if strcmp(slider.HistogramVisible, 'on')
%           slider.HistogramCounts = ... % on frame change
%       end
%   Programmatic assignment to HistogramVisible updates the display
%   without firing the callback.
%
%   Example:
%       slider = uim.widget.ContrastSlider(hAxes, ...
%           'Location', 'northeast', ...
%           'DataLimits', [0, 255], 'Limits', [0, 255], ...
%           'LimitsChangedFcn', ...
%               @(src, evt) set(hAxes, 'CLim', evt.NewValue));
%
%   Note: this widget owns the inherited Callback property (it is the
%   internal notification channel from RangeSlider); use
%   LimitsChangedFcn.

    properties (Dependent)
        DataLimits (1,2) double  % [min, max] full range of the data
        Limits (1,2) double      % [low, high] current contrast limits
    end

    properties
        LimitsChangedFcn = []       % Fired when the user moves a knob. (src, uim.event.ValueChangedEventData with [low, high] values)
        AutoRequestedFcn = []       % Fired when the user presses the auto button. (src, uim.event.EventData)
        HistogramRequestedFcn = []  % Fired when the user toggles the histogram on. (src, uim.event.EventData)

        ShowAutoButton (1,:) char {mustBeMember(ShowAutoButton, {'on', 'off'})} = 'on'
        ShowHistogramButton (1,:) char {mustBeMember(ShowHistogramButton, {'on', 'off'})} = 'on'

        % Whether the pushed histogram is currently displayed. Toggled
        % by the histogram button; programmatic assignment is silent.
        HistogramVisible (1,:) char {mustBeMember(HistogramVisible, {'on', 'off'})} = 'on'

        % Bin counts spanning DataLimits uniformly, drawn as a faint
        % area behind the track (imcontrast-style). The host pushes any
        % nonnegative vector — it is normalized to its maximum, so
        % scaling policy (e.g. sqrt to compress peaks) is the host's.
        % Empty hides the histogram.
        HistogramCounts (1,:) double {mustBeNonnegative} = []
        HistogramColor = ones(1,3)*0.6
    end

    properties (Access = private, Transient)
        AutoButtonIcon           % uim.graphics.ImageVector
        AutoButtonHitArea = gobjects(0,1)
        HistogramButtonIcon      % uim.graphics.ImageVector
        HistogramButtonHitArea = gobjects(0,1)
        HistogramHandle = gobjects(0,1)
        LastNotifiedLimits (1,2) double = [0, 1]

        % RangeSlider invokes Callback from its value setters too, so
        % programmatic pushes must be explicitly silenced.
        SuppressNotification (1,1) logical = false
    end

    methods % Structors

        function obj = ContrastSlider(hParent, varargin)

            obj@uim.widget.RangeSlider(hParent, varargin{:})

            % The inherited Callback is the internal notification channel
            % from RangeSlider's knob/track interactions.
            obj.Callback = @obj.onRangeSliderChanged;
            obj.LastNotifiedLimits = obj.Limits;

            obj.plotHistogram()
            obj.plotGlyphButtons()
            obj.updateGlyphButtonVisibility()
        end

        function delete(obj)
            if ~isempty(obj.AutoButtonIcon) && isvalid(obj.AutoButtonIcon)
                delete(obj.AutoButtonIcon)
            end
            if ~isempty(obj.AutoButtonHitArea) && isvalid(obj.AutoButtonHitArea)
                delete(obj.AutoButtonHitArea)
            end
            if ~isempty(obj.HistogramButtonIcon) && isvalid(obj.HistogramButtonIcon)
                delete(obj.HistogramButtonIcon)
            end
            if ~isempty(obj.HistogramButtonHitArea) && isvalid(obj.HistogramButtonHitArea)
                delete(obj.HistogramButtonHitArea)
            end
            if ~isempty(obj.HistogramHandle) && isvalid(obj.HistogramHandle)
                delete(obj.HistogramHandle)
            end
        end
    end

    methods % Set/Get

        function set.DataLimits(obj, newValue)
            obj.applySilently(@() set(obj, ...
                'Min', newValue(1), 'Max', newValue(2)))
        end

        function limits = get.DataLimits(obj)
            limits = [obj.Min, obj.Max];
        end

        function set.Limits(obj, newValue)
            obj.applySilently(@() set(obj, ...
                'Low', newValue(1), 'High', newValue(2)))
        end

        function limits = get.Limits(obj)
            limits = [obj.Low, obj.High];
        end

        function set.ShowAutoButton(obj, newValue)
            obj.ShowAutoButton = newValue;
            obj.updateGlyphButtonVisibility()
        end

        function set.ShowHistogramButton(obj, newValue)
            obj.ShowHistogramButton = newValue;
            obj.updateGlyphButtonVisibility()
        end

        function set.HistogramVisible(obj, newValue)
            obj.HistogramVisible = newValue;
            obj.updateHistogramDisplay()
            obj.updateGlyphButtonVisibility()
        end

        function set.HistogramCounts(obj, newValue)
            obj.HistogramCounts = newValue;
            obj.updateHistogram()
        end

        function set.HistogramColor(obj, newValue)
            obj.HistogramColor = newValue;
            obj.updateHistogram()
        end
    end

    methods (Access = private)

        function applySilently(obj, applyFcn)
        %applySilently Run a push without notifying, then reset baseline

            obj.SuppressNotification = true;
            restoreFlag = onCleanup(@() obj.enableNotification());

            applyFcn()

            delete(restoreFlag)
            obj.LastNotifiedLimits = [obj.Low, obj.High];
        end

        function enableNotification(obj)
            if isvalid(obj)
                obj.SuppressNotification = false;
            end
        end

        function onRangeSliderChanged(obj, ~, evtData)
        %onRangeSliderChanged Clamp to an increasing range and notify

            if obj.SuppressNotification; return; end

            newLimits = [evtData.Low, evtData.High];

            % CLim must be strictly increasing; absorb collapsed ranges
            % here so hosts can assign NewValue to CLim unguarded.
            minSeparation = max(diff(obj.DataLimits)*1e-6, ...
                eps(newLimits(1)));
            if newLimits(2) <= newLimits(1) + minSeparation
                newLimits(2) = newLimits(1) + minSeparation;
            end

            if isequal(newLimits, obj.LastNotifiedLimits); return; end

            oldLimits = obj.LastNotifiedLimits;
            obj.LastNotifiedLimits = newLimits;

            if ~isempty(obj.LimitsChangedFcn)
                evt = uim.event.ValueChangedEventData(oldLimits, newLimits);
                obj.LimitsChangedFcn(obj, evt)
            end
        end

        function onAutoButtonPressed(obj)
            if ~isempty(obj.AutoRequestedFcn)
                obj.AutoRequestedFcn(obj, uim.event.EventData())
            end
        end

        function plotHistogram(obj)
        %plotHistogram Create the area patch drawn behind the track

            obj.HistogramHandle = patch(obj.CanvasAxes, nan, nan, ...
                obj.HistogramColor);
            obj.HistogramHandle.FaceAlpha = 0.35;
            obj.HistogramHandle.EdgeColor = 'none';
            obj.HistogramHandle.PickableParts = 'none';
            obj.HistogramHandle.HitTest = 'off';
            obj.HistogramHandle.Tag = 'ContrastSliderHistogram';

            % Stack the histogram just above the chip background, below
            % the track, ticks and knobs.
            uistack(obj.HistogramHandle, 'bottom')
            uistack(obj.Background, 'bottom')

            obj.updateHistogram()
        end

        function updateHistogram(obj)
        %updateHistogram Map the pushed counts into the track region

            if ~obj.IsConstructed || isempty(obj.HistogramHandle); return; end

            obj.updateHistogramDisplay()

            counts = obj.HistogramCounts;
            if isempty(counts) || ~any(counts)
                set(obj.HistogramHandle, 'XData', nan, 'YData', nan)
                return
            end

            % Bin centers spread uniformly across the track x-range.
            trackLeft = obj.Position(1) + obj.Padding(1);
            trackRight = obj.Position(1) + obj.Position(3) - obj.Padding(3);
            xCenters = linspace(trackLeft, trackRight, numel(counts));

            % Heights normalized to the padded widget height.
            baseline = obj.Position(2) + obj.Padding(2);
            maxHeight = obj.Position(4) - obj.Padding(2) - obj.Padding(4);
            heights = counts./max(counts) .* maxHeight;

            set(obj.HistogramHandle, ...
                'XData', [trackLeft, xCenters, trackRight], ...
                'YData', [baseline, baseline + heights, baseline], ...
                'FaceColor', obj.HistogramColor)
        end

        function updateHistogramDisplay(obj)
        %updateHistogramDisplay Apply widget and histogram visibility

            if isempty(obj.HistogramHandle) || ~isvalid(obj.HistogramHandle)
                return
            end

            if strcmp(obj.Visible, 'on') && strcmp(obj.HistogramVisible, 'on')
                obj.HistogramHandle.Visible = 'on';
            else
                obj.HistogramHandle.Visible = 'off';
            end
        end

        function onHistogramButtonPressed(obj)
        %onHistogramButtonPressed Toggle the histogram; request counts on show

            if strcmp(obj.HistogramVisible, 'on')
                obj.HistogramVisible = 'off';
            else
                obj.HistogramVisible = 'on';
                % Counts may be stale or absent (hosts typically skip
                % histogram computation while it is hidden); ask for
                % fresh ones.
                if ~isempty(obj.HistogramRequestedFcn)
                    obj.HistogramRequestedFcn(obj, uim.event.EventData())
                end
            end
        end

        function plotGlyphButtons(obj)
        %plotGlyphButtons Histogram and auto buttons in the right padding

            icons = uim.style.getDefaultIcons();

            [obj.HistogramButtonIcon, obj.HistogramButtonHitArea] = ...
                obj.createGlyphButton(icons.hist, ...
                'ContrastSliderHistogramButton', ...
                @(~, ~) obj.onHistogramButtonPressed());

            [obj.AutoButtonIcon, obj.AutoButtonHitArea] = ...
                obj.createGlyphButton(icons.auto, ...
                'ContrastSliderAutoButton', ...
                @(~, ~) obj.onAutoButtonPressed());

            obj.updateGlyphButtonLocations()
        end

        function [hIcon, hHitArea] = createGlyphButton(obj, iconData, tag, callback)

            hIcon = uim.graphics.ImageVector(obj.CanvasAxes, iconData);
            hIcon.flipud() % Icon vector data is stored upside down
            hIcon.PickableParts = 'none';
            hIcon.HitTest = 'off';
            hIcon.Width = 12;
            hIcon.Color = obj.TextColor;

            % Anchor at the bottom-left corner (like uim.control.Button
            % does): these are the reliable alignment code paths, and
            % they make the location math explicit.
            hIcon.HorizontalAlignment = 'left';
            hIcon.VerticalAlignment = 'bottom';

            % An invisible patch is the click target: it gives a larger,
            % rectangular hit area than the glyph outline itself.
            hHitArea = patch(obj.CanvasAxes, nan, nan, 'w');
            hHitArea.FaceAlpha = 0;
            hHitArea.EdgeColor = 'none';
            hHitArea.HitTest = 'on';
            hHitArea.PickableParts = 'all';
            hHitArea.Tag = tag;
            hHitArea.ButtonDownFcn = callback;
        end

        function updateGlyphButtonLocations(obj)

            if isempty(obj.AutoButtonHitArea); return; end

            % The reserved zone inside the right padding starts where
            % the high knob's overhang past the track end (KnobSize/2)
            % stops, and splits into one slot per button: histogram
            % first (nearest the track), auto outermost.
            zoneLeft = obj.Position(1) + obj.Position(3) ...
                - obj.Padding(3) + obj.KnobSize/2;
            zoneRight = obj.Position(1) + obj.Position(3);
            slotWidth = (zoneRight - zoneLeft)/2;
            centerY = obj.Position(2) + obj.Position(4)/2;

            obj.placeGlyphButton(obj.HistogramButtonIcon, ...
                obj.HistogramButtonHitArea, zoneLeft + slotWidth/2, centerY)
            obj.placeGlyphButton(obj.AutoButtonIcon, ...
                obj.AutoButtonHitArea, zoneLeft + 1.5*slotWidth, centerY)
        end

        function placeGlyphButton(~, hIcon, hHitArea, centerX, centerY)

            hitSize = [16, 16];
            iconSize = [hIcon.Width, hIcon.Height];
            hIcon.Position = [centerX, centerY] - iconSize/2;

            hHitArea.XData = centerX + [-1, 1, 1, -1]*hitSize(1)/2;
            hHitArea.YData = centerY + [-1, -1, 1, 1]*hitSize(2)/2;
        end

        function updateGlyphButtonVisibility(obj)

            if isempty(obj.AutoButtonHitArea); return; end

            obj.applyGlyphButtonVisibility(obj.AutoButtonIcon, ...
                obj.AutoButtonHitArea, obj.ShowAutoButton)
            obj.applyGlyphButtonVisibility(obj.HistogramButtonIcon, ...
                obj.HistogramButtonHitArea, obj.ShowHistogramButton)

            % Dim the histogram glyph while the histogram is hidden, so
            % the button reads as a toggle.
            if strcmp(obj.HistogramVisible, 'on')
                obj.HistogramButtonIcon.Color = obj.TextColor;
            else
                obj.HistogramButtonIcon.Color = obj.TextColor*0.55;
            end
        end

        function applyGlyphButtonVisibility(obj, hIcon, hHitArea, showFlag)

            isShown = strcmp(showFlag, 'on') && strcmp(obj.Visible, 'on');
            visibility = 'off';
            if isShown; visibility = 'on'; end

            hIcon.Visible = visibility;
            hHitArea.Visible = visibility;
            if isShown
                hHitArea.PickableParts = 'all';
            else
                hHitArea.PickableParts = 'none';
            end
        end
    end

    methods (Access = protected)

        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            updateLocation@uim.widget.RangeSlider(obj, mode)
            obj.updateGlyphButtonLocations()
            obj.updateHistogram()
        end

        function updateSize(obj, mode)
            if nargin < 2; mode = obj.SizeMode; end
            updateSize@uim.widget.RangeSlider(obj, mode)
            obj.updateGlyphButtonLocations()
            obj.updateHistogram()
        end
    end

    methods (Hidden, Access = protected)

        function onVisibleChanged(obj, varargin)
            onVisibleChanged@uim.widget.RangeSlider(obj, varargin{:})
            obj.updateGlyphButtonVisibility()
            obj.updateHistogramDisplay()
        end
    end

    methods (Static)

        function S = getTypeDefaults()
            S = uim.widget.RangeSlider.getTypeDefaults();
            % The knobs overhang the track ends by KnobSize/2 (7.5 px
            % by default), so the visual margin is the padding minus the
            % overhang. Left: 16 px pads to ~8 px of knob clearance.
            % Right: 62 px additionally reserves one slot per glyph
            % button (histogram, auto) in the part clearing the knob.
            % The chip is taller than a plain RangeSlider so the
            % histogram behind the track has room to read.
            S.Padding = [16, 6, 62, 6];
            S.Size = [200, 30];
        end
    end
end
