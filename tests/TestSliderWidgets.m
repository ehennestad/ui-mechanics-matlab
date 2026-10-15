classdef TestSliderWidgets < matlab.unittest.TestCase
%TestSliderWidgets Headless behaviour of Slider, RangeSlider, ScrollBar, PlaybackControl
%
%   Knob and bar positions are read back from the tagged graphics
%   objects, and press callbacks are invoked directly since no pointer is
%   available in a hidden figure.

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % Slider

        function sliderInOwnAxesTracksValue(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            slider = uim.widget.Slider("Parent", hFigure, "Min", -1, "Max", 1, ...
                "Value", 0.5, "NumTicks", 20, "TickLength", 4);
            testCase.addTeardown(@deleteValid, slider);

            hAxes = findall(hFigure, "Tag", "SlideBar Container");
            testCase.verifyNumElements(hAxes, 1);
            testCase.verifyEqual(slider.Step, 0.1, "AbsTol", 1e-12);
            testCase.verifyNotEmpty(findobj(hAxes, "Type", "line"), "Ticks are drawn.");

            % The knob is a sampled polygon, so its centre is only exact
            % to the sampling resolution.
            knob = findKnob(hAxes);
            testCase.verifyEqual(patchCenter(knob), 0.5, "AbsTol", 1e-3, ...
                "In its own axes the knob sits at the value in data units.");

            slider.Value = -0.25;
            testCase.verifyEqual(patchCenter(knob), -0.25, "AbsTol", 1e-3);

            slider.Value = 5;
            testCase.verifyEqual(slider.Value, -0.25, "Out-of-range values are ignored.");

            slider.Max = 3;
            testCase.verifyEqual(slider.Step, 0.2, "AbsTol", 1e-12);
            testCase.verifyError(@() assign(slider, "Min", 4), ?MException);
            testCase.verifyError(@() assign(slider, "Max", -2), ?MException);
        end

        function sliderTrackPressMovesValueAndNotifies(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            slider = uim.widget.Slider("Parent", hFigure, "Min", -1, "Max", 1, ...
                "Value", 0.25, "NumTicks", 20);
            testCase.addTeardown(@deleteValid, slider);
            slider.Callback = @(~, value) setappdata(hFigure, "SliderValue", value);

            hAxes = findall(hFigure, "Tag", "SlideBar Container");
            knob = findKnob(hAxes);

            % Point at where the knob sits for 0.52, then press the track
            % from another value: the press moves the value there,
            % snapped to the 0.1 tick grid.
            slider.Value = 0.52;
            targetPoint = [patchCenter(knob), mean(knob.YData)];
            slider.Value = -0.5;
            hFigure.CurrentPoint = uim.utility.du2px(hAxes, targetPoint, true);

            hBackground = findBackground(hAxes);
            hBackground.ButtonDownFcn(hBackground, [])

            testCase.assertTrue(isappdata(hFigure, "SliderValue"), "Callback fired.");
            newValue = getappdata(hFigure, "SliderValue");
            testCase.verifyEqual(newValue, 0.5, "AbsTol", 1e-9);
            testCase.verifyEqual(slider.Value, newValue);
        end

        function sliderInCallerAxesUsesPixelTrack(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [10, 10, 300, 100], ...
                "XLim", [0, 300], "YLim", [0, 100]);
            slider = uim.widget.Slider("Parent", hAxes, "Position", [20, 40, 200, 30], ...
                "Min", 0, "Max", 100, "Value", 25);
            testCase.addTeardown(@deleteValid, slider);

            % Default Padding is [0, 9, 3, 9]: the track spans width - 3
            knob = findKnob(hAxes);
            testCase.verifyEqual(patchCenter(knob), 20 + 197*0.25, "AbsTol", 0.01);

            slider.Value = 100;
            testCase.verifyEqual(patchCenter(knob), 217, "AbsTol", 0.01);
            valueLabel = findobj(hAxes, "Type", "text");
            testCase.verifyEqual(valueLabel.Position(1), 217, "AbsTol", 0.01, ...
                "The value label follows the knob on the padded track.");

            slider.Visible = 'off';
            testCase.verifyEqual(knob.Visible, matlab.lang.OnOffSwitchState.off);

            delete(slider)
            testCase.verifyTrue(isvalid(hAxes), "A caller-supplied axes is left in place.");
            testCase.verifyEmpty(findobj(hAxes, "Type", "patch"));
        end

        function sliderInCallerAxesTrackPressMovesValue(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [10, 10, 300, 100], ...
                "XLim", [0, 300], "YLim", [0, 100]);
            slider = uim.widget.Slider("Parent", hAxes, "Position", [20, 40, 200, 30], ...
                "Min", 0, "Max", 100, "Value", 25);
            testCase.addTeardown(@deleteValid, slider);

            % The track starts at x = 20 and is 197 pixels long, so a
            % press three quarters along it selects 75.
            targetPoint = [20 + 197*0.75, 55];
            hFigure.CurrentPoint = uim.utility.du2px(hAxes, targetPoint, true);
            hBackground = findBackground(hAxes);
            hBackground.ButtonDownFcn(hBackground, [])

            testCase.verifyEqual(slider.Value, 75, "AbsTol", 0.5);
        end
    end

    methods (Test) % RangeSlider

        function rangeSliderKnobsFollowLowAndHigh(testCase)
            [~, canvas] = createCanvas(testCase);
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 100, ...
                "Low", 20, "High", 80);
            testCase.addTeardown(@deleteValid, slider);

            hLow = findobj(canvas.Axes, "Tag", "Range Slider Low");
            hHigh = findobj(canvas.Axes, "Tag", "Range Slider High");
            trackStart = slider.Position(1) + slider.Padding(1);
            trackLength = slider.Position(3) - sum(slider.Padding([1, 3]));

            testCase.verifyEqual(patchCenter(hLow), trackStart + 0.2*trackLength, "AbsTol", 0.01);
            testCase.verifyEqual(patchCenter(hHigh), trackStart + 0.8*trackLength, "AbsTol", 0.01);

            slider.Low = 50;
            testCase.verifyEqual(patchCenter(hLow), trackStart + 0.5*trackLength, "AbsTol", 0.01);
        end

        function rangeSliderLimitsClampValues(testCase)
            [~, canvas] = createCanvas(testCase);
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 100, ...
                "Low", 20, "High", 80);
            testCase.addTeardown(@deleteValid, slider);

            slider.Min = 30;
            testCase.verifyEqual(slider.Low, 30, "Raising Min drags Low along.");
            slider.Max = 70;
            testCase.verifyEqual(slider.High, 70, "Lowering Max drags High along.");
            slider.Min = 0;
            slider.Max = 10;
            testCase.verifyEqual([slider.Low, slider.High], [10, 10], ...
                "Lowering Max below Low collapses the range.");

            testCase.verifyError(@() assign(slider, "Low", 60), ?MException);
            testCase.verifyError(@() assign(slider, "High", 5), ?MException);
            testCase.verifyError(@() assign(slider, "Max", 0), ?MException, ...
                "Max must stay above Min.");
            testCase.verifyError(@() assign(slider, "Min", 200), ?MException);
            testCase.verifyError(@() assign(slider, "Max", -1), ?MException);
        end

        function rangeSliderTrackPressMovesNearestKnobAndNotifies(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 100, ...
                "Low", 20, "High", 80);
            testCase.addTeardown(@deleteValid, slider);
            slider.Callback = @(~, evt) setappdata(hFigure, "Range", [evt.Low, evt.High]);

            % Point at where the low knob sits for 30, then press the
            % track: the nearest knob (low) moves there.
            hLow = findobj(canvas.Axes, "Tag", "Range Slider Low");
            slider.Low = 30;
            targetPoint = [patchCenter(hLow), mean(hLow.YData)];
            slider.Low = 20;
            hFigure.CurrentPoint = uim.utility.du2px(canvas.Axes, targetPoint, true);

            hTrack = findobj(canvas.Axes, "Tag", "Range Slider Track");
            hTrack.ButtonDownFcn(hTrack, [])

            % The press goes through the figure's pointer position and is
            % snapped to a step of (Max - Min)/NumTicks, so allow one pixel
            % of track plus half a step.
            valueRange = slider.Max - slider.Min;
            trackLength = slider.Position(3) - sum(slider.Padding([1, 3]));
            tolerance = valueRange/trackLength + valueRange/slider.NumTicks/2;

            testCase.assertTrue(isappdata(hFigure, "Range"), "Callback fired.");
            reported = getappdata(hFigure, "Range");
            testCase.verifyEqual(reported, [30, 80], "AbsTol", tolerance);
            testCase.verifyEqual(reported, [slider.Low, slider.High]);
        end
    end

    methods (Test) % ScrollBar

        function verticalScrollBarFollowsValue(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 20, 200]);
            scrollBar = uim.widget.ScrollBar(hPanel, "Maximum", 10, "VisibleAmount", 2);
            testCase.addTeardown(@deleteValid, scrollBar);

            hAxes = findall(hFigure, "Tag", "Scrollbar Axes");
            testCase.verifyNumElements(hAxes, 1);
            hBar = findobj(hAxes, "Tag", "Scrollbar");

            testCase.verifyEqual(scrollBar.Orientation, 'vertical');
            testCase.verifyEqual(min(hBar.YData), 0, "AbsTol", 1e-9);
            testCase.verifyEqual(uim.utility.range(hBar.YData), 2, "AbsTol", 0.2, ...
                "The bar covers VisibleAmount of the Maximum.");

            scrollBar.Callback = @(~, ~) setappdata(hFigure, "ScrollCallback", true);
            scrollBar.Value = 4;
            testCase.verifyEqual(min(hBar.YData), 4, "AbsTol", 1e-9);
            testCase.verifyTrue(isappdata(hFigure, "ScrollCallback"));

            scrollBar.Value = 20;
            testCase.verifyEqual(min(hBar.YData), 8, "AbsTol", 1e-9, ...
                "The bar stops at Maximum - VisibleAmount.");

            rmappdata(hFigure, "ScrollCallback")
            scrollBar.resetValue()
            testCase.verifyEqual(scrollBar.Value, 0);
            testCase.verifyFalse(isappdata(hFigure, "ScrollCallback"), ...
                "resetValue is silent.");

            scrollBar.VisibleAmount = 5;
            testCase.verifyEqual(uim.utility.range(hBar.YData), 5, "AbsTol", 0.2);
        end

        function scrollBarVisibilityFollowsStateAndContent(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 20, 200]);
            scrollBar = uim.widget.ScrollBar(hPanel, "Maximum", 10, "VisibleAmount", 2);
            testCase.addTeardown(@deleteValid, scrollBar);
            hAxes = findall(hFigure, "Tag", "Scrollbar Axes");
            hBar = findobj(hAxes, "Tag", "Scrollbar");
            hTrack = findobj(hAxes, "Tag", "Sidebar");

            scrollBar.showTrack()
            testCase.verifyEqual(hTrack.Visible, matlab.lang.OnOffSwitchState.on);
            scrollBar.Visible = 'off';
            testCase.verifyEqual(hBar.Visible, matlab.lang.OnOffSwitchState.off);
            testCase.verifyEqual(hTrack.Visible, matlab.lang.OnOffSwitchState.off);
            scrollBar.Visible = 'on';
            testCase.verifyEqual(hBar.Visible, matlab.lang.OnOffSwitchState.on);
            scrollBar.hideTrack()
            testCase.verifyEqual(hTrack.Visible, matlab.lang.OnOffSwitchState.off);

            scrollBar.VisibleAmount = 10;
            scrollBar.Visible = 'on';
            testCase.verifyEqual(hBar.Visible, matlab.lang.OnOffSwitchState.off, ...
                "Nothing to scroll when everything is visible.");

            scrollBar.BarColor = [1, 0, 0];
            testCase.verifyEqual(hBar.FaceColor, [1, 0, 0]);
            testCase.verifyError(@() assign(scrollBar, "Visible", 'maybe'), ?MException);
            testCase.verifyError(@() assign(scrollBar, "Maximum", -1), ?MException);
        end

        function horizontalScrollBarUsesXAxis(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 200, 20]);
            scrollBar = uim.widget.ScrollBar(hPanel, "Maximum", 5, "VisibleAmount", 1);
            testCase.addTeardown(@deleteValid, scrollBar);
            hAxes = findall(hFigure, "Tag", "Scrollbar Axes");
            hBar = findobj(hAxes, "Tag", "Scrollbar");
            hTrack = findobj(hAxes, "Tag", "Sidebar");

            testCase.verifyEqual(scrollBar.Orientation, 'horizontal');
            testCase.verifyEqual(hTrack.XData(:)', [0, 5, 5, 0], ...
                "The track spans the x-limits along the scroll direction.");
            testCase.verifyEqual(hTrack.YData(:)', [0, 0, 1, 1]);

            scrollBar.Value = 3;
            testCase.verifyEqual(min(hBar.XData), 3, "AbsTol", 1e-9);
            testCase.verifyEqual(uim.utility.range(hBar.XData), 1, "AbsTol", 0.2);

            scrollBar.StopMoveCallback = @(~, change) setappdata(hFigure, "Jump", change);
            hTrack.ButtonDownFcn(hTrack, [])
            testCase.verifyTrue(isappdata(hFigure, "Jump"), "Track press jumps and notifies.");
            testCase.verifyGreaterThanOrEqual(min(hBar.XData), 0);
            testCase.verifyLessThanOrEqual(min(hBar.XData), 4 + 1e-9);

            scrollBar.EnableMouseScroll = 'on';
            scrollBar.EnableMouseScroll = 'off';
            scrollBar.Position = [0, 0, 0.5, 1];
            testCase.verifyEqual(hAxes.Position, [0, 0, 0.5, 1]);
        end
    end

    methods (Test) % PlaybackControl

        function playbackControlKnobFollowsPushedValues(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 500, 200]);
            widget = uim.widget.PlaybackControl(hFigure, "Position", [10, 10, 400, 30], ...
                "Minimum", 1, "Maximum", 50, "Value", 10);
            testCase.addTeardown(@deleteValid, widget);

            hSliderAxes = findall(hFigure, "Tag", "Playback Widget (Slider Axes)");
            knob = findobj(hSliderAxes, "Tag", "Button");
            trackLength = hSliderAxes.Position(3) - 2*widget.BarPadding;
            xFor = @(value) widget.BarPadding + trackLength*(value - 1)/(widget.Maximum - 1);

            testCase.verifyEqual(patchCenter(knob), xFor(10), "AbsTol", 0.01);
            widget.Value = 50;
            testCase.verifyEqual(patchCenter(knob), xFor(50), "AbsTol", 0.01);
            widget.Maximum = 100;
            testCase.verifyEqual(patchCenter(knob), xFor(50), "AbsTol", 0.01, ...
                "Raising Maximum moves the knob back along the track.");

            widget.Position = [10, 10, 300, 30];
            testCase.verifyEqual(widget.Position(3:4), [300, 30], "AbsTol", 1);

            widget.Visible = 'off';
            testCase.verifyEqual(knob.Visible, matlab.lang.OnOffSwitchState.off);
        end

        function playbackControlBarPressSelectsValueUnderPointer(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 500, 200]);
            widget = uim.widget.PlaybackControl(hFigure, "Position", [10, 10, 400, 30], ...
                "Minimum", 11, "Maximum", 50, "Value", 20);
            testCase.addTeardown(@deleteValid, widget);

            % The track maps Minimum to its start, so a press at the
            % pixel for 30 selects 30 even though Minimum is not 1.
            hSliderAxes = findall(hFigure, "Tag", "Playback Widget (Slider Axes)");
            hBar = findobj(hSliderAxes, "Tag", "Scrollbar");
            trackLength = hSliderAxes.Position(3) - 2*widget.BarPadding;
            xFor = @(value) widget.BarPadding + ...
                trackLength*(value - widget.Minimum)/(widget.Maximum - widget.Minimum);
            targetPoint = [xFor(30), mean(hBar.YData)];
            hFigure.CurrentPoint = uim.utility.du2px(hSliderAxes, targetPoint, true);

            hBar.ButtonDownFcn(hBar, [])
            testCase.verifyEqual(widget.Value, 30);
        end

        function playbackControlShowsSingleFrameRange(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 500, 200]);

            % A one-frame stack gives Minimum == Maximum; the knob then
            % sits at the start of the track.
            widget = uim.widget.PlaybackControl(hFigure, "Position", [10, 10, 400, 30], ...
                "Minimum", 1, "Maximum", 1, "Value", 1);
            testCase.addTeardown(@deleteValid, widget);

            hSliderAxes = findall(hFigure, "Tag", "Playback Widget (Slider Axes)");
            knob = findobj(hSliderAxes, "Tag", "Button");
            testCase.verifyEqual(patchCenter(knob), widget.BarPadding, "AbsTol", 0.01);

            widget.Maximum = 5;
            widget.Value = 5;
            trackLength = hSliderAxes.Position(3) - 2*widget.BarPadding;
            testCase.verifyEqual(patchCenter(knob), widget.BarPadding + trackLength, ...
                "AbsTol", 0.01, "The widget recovers once the range has extent.");
        end

        function playbackControlReflectsSpeedPlayStateAndRange(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 500, 200]);
            widget = uim.widget.PlaybackControl(hFigure, "Position", [10, 10, 400, 30], ...
                "Minimum", 1, "Maximum", 50, "Value", 10);
            testCase.addTeardown(@deleteValid, widget);
            hButtonAxes = findall(hFigure, "Tag", "Playback Widget (Button Axes)");
            hSliderAxes = findall(hFigure, "Tag", "Playback Widget (Slider Axes)");

            widget.PlaybackSpeed = 2;
            testCase.verifyNotEmpty(findobj(hButtonAxes, "Type", "text", "String", "2x"));
            widget.PlaybackSpeed = 0.5;
            testCase.verifyNotEmpty(findobj(hButtonAxes, "Type", "text", "String", "0.5x"));
            widget.PlaybackSpeed = 1;
            testCase.verifyEmpty(findobj(hButtonAxes, "Type", "text", "String", "2x"));

            widget.switchPlayPauseIcon('pause')
            testCase.verifyNotEmpty(findobj(hButtonAxes, "Tag", "Pause"));
            widget.switchPlayPauseIcon('play')
            testCase.verifyNotEmpty(findobj(hButtonAxes, "Tag", "Play"));

            numPatchesBefore = numel(findobj(hSliderAxes, "Type", "patch", "Visible", "on"));
            widget.RangeSelectorEnabled = 'on';
            widget.ActiveRange = [5, 20];
            numPatchesAfter = numel(findobj(hSliderAxes, "Type", "patch", "Visible", "on"));
            testCase.verifyEqual(numPatchesAfter, numPatchesBefore + 1, ...
                "Enabling the range selector shows the active-range bar.");
            widget.resetRangeSelector()
            testCase.verifyEqual(widget.ActiveRange, [1, 1]);
            testCase.verifyEqual(widget.RangeSelectorEnabled, matlab.lang.OnOffSwitchState.off);
        end

        function playbackControlHostsChannelAndPlaneSelectors(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 500, 200]);
            widget = uim.widget.PlaybackControl(hFigure, "Position", [10, 10, 400, 30], ...
                "Minimum", 1, "Maximum", 50, "Value", 10);
            testCase.addTeardown(@deleteValid, widget);

            testCase.verifyEmpty(widget.ChannelIndicatorWidget);
            widget.NumChannels = 3;
            testCase.verifyNotEmpty(widget.ChannelIndicatorWidget);
            widget.CurrentChannels = [1, 3];
            testCase.verifyEqual(widget.CurrentChannels, [1, 3]);
            % ChannelIndicator compares against its previous list, so a
            % replacement list must be at least as long as the default six.
            colors = {[1, 0, 0], [0, 1, 0], [0, 0, 1], 'c', 'm', 'y'};
            widget.ChannelColors = colors;
            testCase.verifyEqual(widget.ChannelColors, colors);

            widget.NumPlanes = 4;
            widget.CurrentPlane = 2;
            testCase.verifyEqual(widget.CurrentPlane, 2);

            widget.BackgroundColor = [0, 0, 0];
            hSliderAxes = findall(hFigure, "Tag", "Playback Widget (Slider Axes)");
            testCase.verifyEqual(hSliderAxes.Color, [0, 0, 0]);
        end
    end
end

function hFigure = createHiddenFigure(testCase, position)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", position);
    testCase.addTeardown(@deleteValid, hFigure);
end

function [hFigure, canvas] = createCanvas(testCase)
    hFigure = createHiddenFigure(testCase, [100, 100, 500, 400]);
    hPanel = uipanel(hFigure, "Units", "normalized", "Position", [0, 0, 1, 1]);
    canvas = uim.UIComponentCanvas(hPanel);
end

function knob = findKnob(hAxes)
%findKnob The slider knob is the only 200-vertex patch in the axes
    patches = findobj(hAxes, "Type", "patch");
    knob = patches(arrayfun(@(h) numel(h.XData) == 200, patches));
end

function hBackground = findBackground(hAxes)
%findBackground The hittable background is the only 5-vertex patch
    patches = findobj(hAxes, "Type", "patch");
    hBackground = patches(arrayfun(@(h) numel(h.XData) == 5, patches));
end

function center = patchCenter(hPatch)
    center = (max(hPatch.XData) + min(hPatch.XData))/2;
end

function assign(object, propertyName, value)
    object.(propertyName) = value;
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
