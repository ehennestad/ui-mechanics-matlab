classdef TestIndicatorWidgets < matlab.unittest.TestCase
%TestIndicatorWidgets Headless behaviour of PageIndicator, ChannelIndicator and PlaneSwitcher

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % PageIndicator

        function pageIndicatorChangesPagesWithinRange(testCase)
            [~, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {"One", "Two", "Three"});
            testCase.addTeardown(@deleteValid, pages);

            pages.changePage(2)
            testCase.verifyEqual(pages.CurrentPage, 2);
            pages.changePage('next')
            testCase.verifyEqual(pages.CurrentPage, 3);
            pages.changePage('next')
            testCase.verifyEqual(pages.CurrentPage, 3, "No page after the last.");
            pages.changePage('previous')
            testCase.verifyEqual(pages.CurrentPage, 2);
            pages.changePage(0)
            testCase.verifyEqual(pages.CurrentPage, 2, "Out-of-range pages are ignored.");
        end

        function pageIndicatorButtonsNotifyTheHost(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {"One", "Two", "Three"});
            testCase.addTeardown(@deleteValid, pages);
            pages.ChangePageFcn = @(~, evt) setappdata(hFigure, "Pages", ...
                [evt.OldPageNumber, evt.NewPageNumber]);

            buttons = pageButtons(canvas.Axes);
            testCase.assertNumElements(buttons, 3);
            buttons(3).ButtonDownFcn(buttons(3), [])
            testCase.verifyEqual(pages.CurrentPage, 3);
            testCase.verifyEqual(getappdata(hFigure, "Pages"), [1, 3]);

            pages.BlockChangePage = true;
            buttons(1).ButtonDownFcn(buttons(1), [])
            testCase.verifyEqual(pages.CurrentPage, 3, "The host may veto the change.");
            testCase.verifyEqual(getappdata(hFigure, "Pages"), [3, 1], ...
                "The host is still told what was requested.");
        end

        function pageIndicatorStylingUpdatesGraphics(testCase)
            [~, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {"One", "Two"});
            testCase.addTeardown(@deleteValid, pages);
            labels = pageLabels(canvas.Axes, ["One", "Two"]);
            lines = findobj(canvas.Axes, "Type", "line");

            pages.BarVisibility = 'off';
            testCase.verifyTrue(all(strcmp(get(lines, "Visible"), 'off')));
            pages.BarVisibility = 'on';

            pages.TextVisibility = 'off';
            testCase.verifyTrue(all(strcmp(get(labels, "Visible"), 'off')));
            pages.TextVisibility = 'hit';
            pages.TextVisibility = 'on';

            pages.HorizontalTextAlignment = 'left';
            testCase.verifyTrue(all(strcmp(get(labels, "HorizontalAlignment"), 'left')));
            pages.HorizontalTextAlignment = 'right';
            pages.HorizontalTextAlignment = 'center';

            pages.FontSize = 16;
            testCase.verifyTrue(all([labels.FontSize] == 16));
            pages.FontColor = [1, 0, 0];
            pages.IndicatorColor = [0, 1, 0];
            pages.BarColor = [0, 0, 1];
            buttons = pageButtons(canvas.Axes);
            testCase.verifyEqual(buttons(2).FaceColor, [0, 1, 0]);
            testCase.verifyEqual(buttons(1).FaceColor, [0, 0, 1], "The current page wears the bar colour.");

            xBefore = buttons(1).XData;
            pages.Position(1:2) = pages.Position(1:2) + [25, 0];
            testCase.verifyEqual(buttons(1).XData, xBefore + 25, "AbsTol", 1e-9);
        end
    end

    methods (Test) % PageIndicator fixes

        function pageIndicatorDotsFollowPositionY(testCase)
            [~, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {'One', 'Two'}, ...
                "Location", "north", "Size", [200, 40]);
            testCase.addTeardown(@deleteValid, pages);

            dots = pageButtons(canvas.Axes);
            testCase.verifyEqual(min(dots(1).YData), pages.Position(2), "AbsTol", 1e-6, ...
                "The dots start at Position(2).");
        end

        function pageIndicatorShowsCurrentPageGivenAtConstruction(testCase)
            [~, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {'One', 'Two'}, "CurrentPage", 2);
            testCase.addTeardown(@deleteValid, pages);

            dots = pageButtons(canvas.Axes);
            testCase.verifyEqual([dots.FaceColor], [pages.IndicatorColor, validatecolor(pages.BarColor)], ...
                "Dot 2 is filled.");
        end

        function pageIndicatorCurrentPageAssignmentUpdatesTheDisplay(testCase)
            [~, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {'One', 'Two'});
            testCase.addTeardown(@deleteValid, pages);

            pages.CurrentPage = 2;

            dots = pageButtons(canvas.Axes);
            testCase.verifyEqual([dots.FaceColor], [pages.IndicatorColor, validatecolor(pages.BarColor)]);
            labelOne = pageLabels(canvas.Axes, {'One'});
            labelTwo = pageLabels(canvas.Axes, {'Two'});
            testCase.verifyEqual(string([labelOne.Visible, labelTwo.Visible]), ["off", "on"], ...
                "The label of page 2 is shown.");
        end

        function pageIndicatorVisibleKeepsHiddenParts(testCase)
            [~, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {'One', 'Two'}, ...
                "TextVisibility", "off", "BarVisibility", "off");
            testCase.addTeardown(@deleteValid, pages);

            pages.Visible = 'off';
            pages.Visible = 'on';

            testCase.verifyEmpty(findobj(canvas.Axes, "Type", "line", "Visible", "on"), ...
                "The bar and ticks stay hidden.");
            testCase.verifyEmpty(findobj(canvas.Axes, "Type", "text", "Visible", "on"), ...
                "The labels stay hidden.");
        end

        function pageIndicatorVisibleOffHidesEveryPart(testCase)
            [~, canvas] = createCanvas(testCase);
            pages = uim.widget.PageIndicator(canvas, {'One', 'Two'});
            testCase.addTeardown(@deleteValid, pages);
            dots = pageButtons(canvas.Axes);

            pages.Visible = 'off';
            testCase.verifyEqual(string({dots.Visible}), ["off", "off"], "The dots are hidden.");
            testCase.verifyEmpty(findobj(canvas.Axes, "Type", "line", "Visible", "on"), ...
                "The bar and ticks are hidden.");
            testCase.verifyEmpty(findobj(pageLabels(canvas.Axes, {'One', 'Two'}), "Visible", "on"), ...
                "The labels are hidden.");

            pages.CurrentPage = 2;
            testCase.verifyEmpty(findobj(canvas.Axes, "Type", "line", "Visible", "on"), ...
                "A page change keeps the bar and ticks hidden.");
            testCase.verifyEmpty(findobj(pageLabels(canvas.Axes, {'One', 'Two'}), "Visible", "on"), ...
                "A page change keeps the labels hidden.");

            pages.Visible = 'on';
            testCase.verifyEqual(string({dots.Visible}), ["on", "on"], "The dots are shown again.");
        end
    end

    methods (Test) % ChannelIndicator

        function channelIndicatorTracksSelectionAndColours(testCase)
            [hFigure, hPanel] = createPanel(testCase);
            indicator = uim.widget.ChannelIndicator(hPanel, "NumChannels", 3);
            testCase.addTeardown(@deleteValid, indicator);
            indicator.Callback = @(channels) setappdata(hFigure, "Channels", channels);

            hIndicators = findall(hPanel, "Tag", "ChannelIndicator");
            testCase.assertNumElements(hIndicators, 3);

            indicator.CurrentChannels = [1, 3];
            offMarks = findall(hPanel, "Tag", "ButtonForeground", "Visible", "on");
            testCase.verifyNumElements(offMarks, 1, "Only the deselected channel shows its off mark.");

            % Pressing an indicator selects that channel and notifies the host
            hIndicators(1).ButtonDownFcn(hIndicators(1), [])
            testCase.verifyTrue(isappdata(hFigure, "Channels"));
            testCase.verifyEqual(indicator.CurrentChannels, getappdata(hFigure, "Channels"));

            % Indicators sit left to right in channel order.
            [~, channelOrder] = sort(arrayfun(@(h) mean(h.XData), hIndicators));
            indicatorsByChannel = hIndicators(channelOrder);
            thirdColourBefore = indicatorsByChannel(3).FaceColor;

            indicator.ChannelColors = {[0, 0, 1], [0, 1, 0]};
            testCase.verifyEqual(indicatorsByChannel(1).FaceColor, [0, 0, 1], ...
                "A shorter colour list updates the indicators it covers.");
            testCase.verifyEqual(indicatorsByChannel(2).FaceColor, [0, 1, 0]);
            testCase.verifyEqual(indicatorsByChannel(3).FaceColor, thirdColourBefore, ...
                "An indicator beyond the list keeps its colour.");

            indicator.selectChannel(2)
            indicator.ChangeDefaultsCallback = @(colours) setappdata(hFigure, "Defaults", colours);
            indicator.onChangeDefaultsMenuItemClicked([], [])
            testCase.verifyEqual(getappdata(hFigure, "Defaults"), indicator.ChannelColors);
        end

        function channelIndicatorResizesWithChannelCount(testCase)
            [~, hPanel] = createPanel(testCase);
            indicator = uim.widget.ChannelIndicator(hPanel, "NumChannels", 2);
            testCase.addTeardown(@deleteValid, indicator);
            widthBefore = indicator.Position(3);

            indicator.NumChannels = 5;
            testCase.verifyNumElements(findall(hPanel, "Tag", "ChannelIndicator"), 5);
            testCase.verifyGreaterThan(indicator.Position(3), widthBefore);

            indicator.Position(1:2) = [40, 30];
            testCase.verifyEqual(indicator.Position(1:2), [40, 30]);
            indicator.Visible = 'off';
            indicator.Visible = 'on';
            indicator.BackgroundColor = [0, 0, 0];
        end
    end

    methods (Test) % PlaneSwitcher

        function planeSwitcherTogglesItsSliderAndNotifies(testCase)
            [hFigure, hPanel] = createPanel(testCase);
            switcher = uim.widget.PlaneSwitcher(hPanel, "NumPlanes", 5, "CurrentPlane", 2);
            testCase.addTeardown(@deleteValid, switcher);
            switcher.Callback = @(plane) setappdata(hFigure, "Plane", plane);

            hSliderAxes = findall(hFigure, "Tag", "SlideBar Container");
            testCase.assertNumElements(hSliderAxes, 1);

            % The slider shows and hides its own graphics; the private axes
            % it draws into keeps its rulers off throughout.
            sliderParts = findobj(hSliderAxes, "Type", "patch");
            isShown = @() all(strcmp(get(sliderParts, "Visible"), 'on'));
            testCase.verifyFalse(isShown(), "The slider starts hidden.");

            toggleButton = findall(hPanel, "Tag", "PlaneSwitcherToggleButton");
            toggleButton.ButtonDownFcn(toggleButton, [])
            testCase.verifyTrue(isShown());
            toggleButton.ButtonDownFcn(toggleButton, [])
            testCase.verifyFalse(isShown());

            switcher.CurrentPlane = 4;
            knob = sliderKnob(hSliderAxes);
            testCase.verifyEqual((max(knob.XData) + min(knob.XData))/2, 4, "AbsTol", 1e-3);

            hBackground = sliderBackground(hSliderAxes);
            hBackground.ButtonDownFcn(hBackground, [])
            testCase.verifyTrue(isappdata(hFigure, "Plane"), "A slider press notifies the host.");
            plane = getappdata(hFigure, "Plane");
            testCase.verifyGreaterThanOrEqual(plane, 1);
            testCase.verifyLessThanOrEqual(plane, 5);

            switcher.Position(1:2) = [30, 20];
            switcher.Visible = 'off';
            switcher.NumPlanes = 6;
        end
    end
end

function [hFigure, canvas] = createCanvas(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 500, 400]);
    testCase.addTeardown(@deleteValid, hFigure);
    hPanel = uipanel(hFigure, "Units", "normalized", "Position", [0, 0, 1, 1]);
    canvas = uim.UIComponentCanvas(hPanel);
end

function [hFigure, hPanel] = createPanel(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 500, 400]);
    testCase.addTeardown(@deleteValid, hFigure);
    hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 300, 60]);
end

function buttons = pageButtons(hAxes)
%pageButtons Page indicator dots are the patches wired to onPageButtonPressed
    patches = findobj(hAxes, "Type", "patch");
    isButton = arrayfun(@(h) isa(h.ButtonDownFcn, "function_handle") && ...
        contains(func2str(h.ButtonDownFcn), "onPageButtonPressed"), patches);
    buttons = flipud(patches(isButton)); % findobj lists newest first
end

function labels = pageLabels(hAxes, pageNames)
%pageLabels Text objects showing the page names (excludes the canvas tooltip)
    hTexts = findobj(hAxes, "Type", "text");
    labels = hTexts(arrayfun(@(h) any(strcmp(string(h.String), pageNames)), hTexts));
end

function knob = sliderKnob(hAxes)
    patches = findobj(hAxes, "Type", "patch");
    knob = patches(arrayfun(@(h) numel(h.XData) == 200, patches));
end

function hBackground = sliderBackground(hAxes)
    patches = findobj(hAxes, "Type", "patch");
    hBackground = patches(arrayfun(@(h) numel(h.XData) == 5, patches));
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
