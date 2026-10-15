classdef TestSliderDetails < matlab.unittest.TestCase
%TestSliderDetails Labels, ticks, hover and styling across the slider family

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % RangeSlider

        function rangeSliderPlacesItsLabelOnEverySide(testCase)
            [~, canvas] = createCanvas(testCase);
            position = [40, 40, 200, 30];

            locations = ["left", "right", "top", "bottom"];
            labelPositions = zeros(numel(locations), 2);
            for i = 1:numel(locations)
                slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 10, ...
                    "Position", position, "Size", position(3:4), "PositionMode", "manual", ...
                    "Label", 'Range', "LabelLocation", char(locations(i)));
                testCase.addTeardown(@deleteValid, slider);
                hLabel = findobj(canvas.Axes, "Type", "text", "String", "Range");
                testCase.assertNumElements(hLabel, 1);
                labelPositions(i, :) = hLabel.Position(1:2);
                delete(slider)
            end

            testCase.verifyLessThan(labelPositions(1, 1), labelPositions(2, 1), ...
                "A left label sits left of a right one.");
            testCase.verifyGreaterThan(labelPositions(3, 2), labelPositions(4, 2), ...
                "A top label sits above a bottom one.");
        end

        function rangeSliderKnobPressHighlightsAndShowsTheValue(testCase)
            [~, canvas] = createCanvas(testCase);
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 100, ...
                "Low", 20, "High", 80);
            testCase.addTeardown(@deleteValid, slider);

            hLow = findobj(canvas.Axes, "Tag", "Range Slider Low");
            hHigh = findobj(canvas.Axes, "Tag", "Range Slider High");

            hLow.ButtonDownFcn(hLow, [])
            hValueLabel = valueLabel(canvas.Axes);
            testCase.assertNumElements(hValueLabel, 1);
            testCase.verifyEqual(hLow.FaceColor, slider.KnobFaceColorActive);
            testCase.verifyEqual(char(hValueLabel.Visible), 'on');
            testCase.verifyEqual(hValueLabel.String, '20', ...
                "An integer step size prints without decimals.");

            hHigh.ButtonDownFcn(hHigh, [])
            testCase.verifyEqual(hHigh.FaceColor, slider.KnobFaceColorActive);
            testCase.verifyEqual(hValueLabel.String, '80');
        end

        function rangeSliderKnobHoverChangesAppearance(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 100, ...
                "Low", 20, "High", 80);
            testCase.addTeardown(@deleteValid, slider);
            hLow = findobj(canvas.Axes, "Tag", "Range Slider Low");

            behavior = iptGetPointerBehavior(hLow);
            testCase.assertNotEmpty(behavior);
            behavior.enterFcn(hFigure, [0, 0])
            testCase.verifyEqual(hLow.FaceColor, ones(1, 3)*0.95, ...
                "Hovering lightens the knob.");
            behavior.exitFcn(hFigure, [0, 0])
            testCase.verifyEqual(hLow.FaceColor, ones(1, 3)*0.8);
        end

        function rangeSliderReportsValuesWhileChanging(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 100, ...
                "Low", 20, "High", 80);
            testCase.addTeardown(@deleteValid, slider);
            slider.ValueChangingFcn = @(~, evt) setappdata(hFigure, "Changing", ...
                [evt.Low, evt.High]);

            slider.Low = 30;
            testCase.verifyEqual(getappdata(hFigure, "Changing"), [30, 80]);
            slider.High = 60;
            testCase.verifyEqual(getappdata(hFigure, "Changing"), [30, 60]);
        end

        function rangeSliderFractionalStepPrintsDecimals(testCase)
            [~, canvas] = createCanvas(testCase);
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 1, ...
                "Low", 0.25, "High", 0.75, "NumTicks", 3);
            testCase.addTeardown(@deleteValid, slider);

            hLow = findobj(canvas.Axes, "Tag", "Range Slider Low");
            hLow.ButtonDownFcn(hLow, [])
            testCase.verifyEqual(valueLabel(canvas.Axes).String, '0.25');
        end
    end

    methods (Test) % Slider

        function sliderDrawsAndRedrawsTicks(testCase)
            hFigure = createHiddenFigure(testCase);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [20, 20, 320, 120], ...
                "XLim", [0, 320], "YLim", [0, 120]);
            slider = uim.widget.Slider("Parent", hAxes, "Position", [20, 40, 200, 30], ...
                "Min", 0, "Max", 10, "Value", 5, "NumTicks", 8, "TickLength", 6);
            testCase.addTeardown(@deleteValid, slider);

            hTicks = findobj(hAxes, "Type", "line");
            testCase.assertNumElements(hTicks, 9, "One line object per tick.");
            xBefore = [hTicks.XData];
            yBefore = [hTicks.YData];

            slider.TickLength = 12;
            testCase.verifyEqual([hTicks.XData], xBefore, ...
                "A longer tick keeps its horizontal placement.");
            testCase.verifyNotEqual([hTicks.YData], yBefore, ...
                "... and grows vertically.");

            slider.TickMode = 'over';
            slider.Position = [20, 40, 280, 30];
            testCase.verifyNotEqual([hTicks.XData], xBefore, ...
                "Widening the slider spreads the ticks.");
        end

        function sliderTooltipUsesTheConfiguredExpression(testCase)
            hFigure = createHiddenFigure(testCase);
            slider = uim.widget.Slider("Parent", hFigure, "Min", 1, "Max", 10, ...
                "Value", 4, "NumTicks", 9, "TooltipExpression", 'Z = %d');
            testCase.addTeardown(@deleteValid, slider);
            hAxes = findall(hFigure, "Tag", "SlideBar Container");
            hLabel = findobj(hAxes, "Type", "text");

            testCase.assertNumElements(hLabel, 1);
            testCase.verifyEqual(hLabel.String, 'Z = 4');
            slider.Value = 7;
            testCase.verifyEqual(hLabel.String, 'Z = 7');
        end

        function sliderTooltipFallsBackToUnitsAndPrecision(testCase)
            hFigure = createHiddenFigure(testCase);
            slider = uim.widget.Slider("Parent", hFigure, "Min", 0, "Max", 1, ...
                "Value", 0.5, "NumTicks", 100, "TooltipUnits", ' mm', ...
                "TooltipPrecision", 3);
            testCase.addTeardown(@deleteValid, slider);
            hLabel = findobj(findall(hFigure, "Tag", "SlideBar Container"), "Type", "text");

            testCase.verifyTrue(contains(hLabel.String, 'mm'));
            testCase.verifyTrue(contains(hLabel.String, '0.5'));
        end

        function sliderStylingReachesItsParts(testCase)
            hFigure = createHiddenFigure(testCase);
            slider = uim.widget.Slider("Parent", hFigure, "Min", 0, "Max", 10, "Value", 5);
            testCase.addTeardown(@deleteValid, slider);
            hAxes = findall(hFigure, "Tag", "SlideBar Container");

            slider.BarColor = [1, 0, 0];
            track = findobj(hAxes, "Type", "patch", "FaceColor", [1, 0, 0]);
            testCase.verifyNumElements(track, 1);

            slider.TextColor = [0, 1, 0];
            testCase.verifyEqual(findobj(hAxes, "Type", "text").Color, [0, 1, 0]);

            slider.KnobFaceColorInactive = [0, 0, 1];
            slider.KnobEdgeColorInactive = [1, 1, 0];
            knob = findobj(hAxes, "Type", "patch", "FaceColor", [0, 0, 1]);
            testCase.verifyNumElements(knob, 1);
            testCase.verifyEqual(knob.EdgeColor, [1, 1, 0]);

            slider.FontSize = 14;
            testCase.verifyEqual(slider.FontSize, 14);
        end
    end

    methods (Test) % ScrollBar and Button details

        function reversedScrollBarFlipsItsAxis(testCase)
            hFigure = createHiddenFigure(testCase);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 20, 200]);
            scrollBar = uim.widget.ScrollBar(hPanel, "Maximum", 10, ...
                "VisibleAmount", 2, "Direction", "reverse");
            testCase.addTeardown(@deleteValid, scrollBar);

            hAxes = findall(hFigure, "Tag", "Scrollbar Axes");
            testCase.verifyEqual(char(hAxes.YDir), 'normal', ...
                "Only the default direction flips the axis.");
            testCase.verifyEqual(scrollBar.Orientation, 'vertical');
        end

        function mouseScrollCanBeEnabledAndDisabled(testCase)
            hFigure = createHiddenFigure(testCase);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 20, 200]);
            scrollBar = uim.widget.ScrollBar(hPanel, "Maximum", 10, "VisibleAmount", 2);
            testCase.addTeardown(@deleteValid, scrollBar);

            scrollBar.EnableMouseScroll = 'on';
            testCase.verifyEqual(char(scrollBar.EnableMouseScroll), 'on');
            scrollBar.EnableMouseScroll = 'off';
            scrollBar.EnableMouseScroll = 'off';
            testCase.verifyEqual(char(scrollBar.EnableMouseScroll), 'off');

            scrollBar.TrackColor = [0, 1, 0];
            hTrack = findobj(findall(hFigure, "Tag", "Scrollbar Axes"), "Tag", "Sidebar");
            testCase.verifyEqual(hTrack.FaceColor, [0, 1, 0]);
        end

        function buttonSymbolsCoverEveryGlyph(testCase)
            [~, canvas] = createCanvas(testCase);
            symbols = {'x', 'o', '>'};
            for i = 1:numel(symbols)
                button = uim.control.Button(canvas, "Icon", symbols{i}, ...
                    "Position", [10, 10 + 40*i, 30, 30], "Size", [30, 30], ...
                    "PositionMode", "manual");
                testCase.addTeardown(@deleteValid, button);
                testCase.verifyNotEmpty(findobj(canvas.Axes, "Type", "line", ...
                    "Marker", symbols{i}), sprintf("symbol %s", symbols{i}));
            end
        end

        function autoWrappedButtonGrowsToFitItsText(testCase)
            [~, canvas] = createCanvas(testCase);
            narrow = uim.control.Button(canvas, "Text", "A", "AutoWrapText", true, ...
                "Position", [10, 10, 30, 30], "Size", [30, 30], "PositionMode", "manual");
            testCase.addTeardown(@deleteValid, narrow);
            wide = uim.control.Button(canvas, "Text", "A much longer caption", ...
                "AutoWrapText", true, "Position", [10, 60, 30, 30], "Size", [30, 30], ...
                "PositionMode", "manual");
            testCase.addTeardown(@deleteValid, wide);

            testCase.verifyGreaterThan(wide.Position(3), narrow.Position(3), ...
                "A longer caption widens the button.");
        end
    end
end

function hFigure = createHiddenFigure(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 500, 400]);
    testCase.addTeardown(@deleteValid, hFigure);
end

function [hFigure, canvas] = createCanvas(testCase)
    hFigure = createHiddenFigure(testCase);
    hPanel = uipanel(hFigure, "Units", "normalized", "Position", [0, 0, 1, 1]);
    canvas = uim.UIComponentCanvas(hPanel);
end

function hLabel = valueLabel(hAxes)
%valueLabel The range slider's floating value tip (the canvas tooltip is separate)
    hTexts = findobj(hAxes, "Type", "text");
    hLabel = hTexts(arrayfun(@(h) ~isempty(regexp(h.String, '^[\d.]+$', 'once')), hTexts));
    if numel(hLabel) > 1; hLabel = hLabel(1); end
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
