classdef TestDecoratorsAndMarkers < matlab.unittest.TestCase
%TestDecoratorsAndMarkers Line decorator, frame marker, tooltips and small utilities

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % uim.decorator.Line

        function lineDecoratorDrawsAcrossItsPosition(testCase)
            [~, canvas] = createCanvas(testCase);
            decorator = uim.decorator.Line(canvas, "Position", [10, 20, 90, 20], ...
                "Size", [80, 1], "PositionMode", "manual");
            testCase.addTeardown(@deleteValid, decorator);

            hLine = findobj(canvas.Axes, "Type", "line");
            testCase.assertNumElements(hLine, 1);
            testCase.verifyEqual(hLine.XData, decorator.Position([1, 3]), ...
                "Without explicit data the endpoints come from the position vector.");
            testCase.verifyEqual(hLine.YData, decorator.Position([2, 4]));
            testCase.verifyEqual(char(hLine.HitTest), 'off');
        end

        function lineDecoratorHonoursExplicitDataAndVisibility(testCase)
            [~, canvas] = createCanvas(testCase);
            decorator = uim.decorator.Line(canvas, "Position", [10, 20, 90, 20], ...
                "Size", [80, 1], "PositionMode", "manual", ...
                "XData", [5, 25], "YData", [30, 30], "Color", [1, 0, 0], "LineWidth", 2);
            testCase.addTeardown(@deleteValid, decorator);
            hLine = findobj(canvas.Axes, "Type", "line");

            testCase.verifyEqual(hLine.XData, [5, 25]);
            testCase.verifyEqual(hLine.Color, [1, 0, 0]);
            testCase.verifyEqual(hLine.LineWidth, 2);

            decorator.Visible = 'off';
            testCase.verifyEqual(char(hLine.Visible), 'off');
            decorator.Visible = 'on';
            testCase.verifyEqual(char(hLine.Visible), 'on');
        end
    end

    methods (Test) % uim.decorator.Image

        function imageDataReadsBackAsAssigned(testCase)
            [~, canvas] = createCanvas(testCase);
            imageData = uint8(reshape(1:12, 3, 4));
            alphaData = reshape(linspace(0, 1, 12), 3, 4);

            img = uim.decorator.Image(canvas, CData=imageData, Alpha=alphaData, ...
                Position=[10, 10, 40, 30], PositionMode="manual");
            testCase.addTeardown(@deleteValid, img);

            testCase.verifyEqual(img.CData, imageData);
            testCase.verifyEqual(img.Alpha, alphaData);
            img.CData = img.CData;
            hImage = findobj(canvas.Axes, "Type", "image");
            testCase.verifyEqual(hImage.CData, flipud(imageData), ...
                "Reassigning CData does not flip the drawn image.");
        end

        function imageFitsInsideAWideComponent(testCase)
            [~, canvas] = createCanvas(testCase);
            img = uim.decorator.Image(canvas, CData=zeros(100, 100, "uint8"), ...
                Position=[10, 10, 200, 100], Size=[200, 100], PositionMode="manual");
            testCase.addTeardown(@deleteValid, img);

            hImage = findobj(canvas.Axes, "Type", "image");
            drawnSize = [diff(hImage.XData), diff(hImage.YData)];
            testCase.verifyEqual(drawnSize, [100, 100], "AbsTol", 1e-9, ...
                "A square image fills the height of a 200-by-100 component.");
        end

        function imageRejectsAlphaOfAnotherSize(testCase)
            [~, canvas] = createCanvas(testCase);
            img = uim.decorator.Image(canvas, CData=zeros(3, 4, "uint8"));
            testCase.addTeardown(@deleteValid, img);

            testCase.verifyError(@() assignProperty(img, "Alpha", ones(4, 3)), "uim:Image:InvalidAlpha");
            img.Alpha = 0.5;
            testCase.verifyEqual(img.Alpha, 0.5);
        end
    end

    methods (Test) % uim.widget.FrameMarker

        function frameMarkerStartsHiddenWhenAsked(testCase)
            [~, hAxes] = createDataAxes(testCase);
            marker = uim.widget.FrameMarker(hAxes, "Minimum", 1, "Maximum", 100, ...
                "Value", 20, "Visible", "off");
            testCase.addTeardown(@deleteValid, marker);

            handles = findall(hAxes, "Tag", "FrameMarker");
            testCase.assertNumElements(handles, 3);
            testCase.verifyTrue(all(strcmp(get(handles, "Visible"), 'off')));
            testCase.verifyTrue(all(arrayfun(@(h) all(h.XData == 20), handles)));
        end

        function frameMarkerFollowsItsValue(testCase)
            [~, hAxes] = createDataAxes(testCase);
            marker = uim.widget.FrameMarker(hAxes, "Minimum", 1, "Maximum", 100, "Value", 20);
            testCase.addTeardown(@deleteValid, marker);

            handles = findall(hAxes, "Tag", "FrameMarker");
            testCase.assertNumElements(handles, 3, "A line and two knobs.");
            testCase.verifyTrue(all(arrayfun(@(h) all(h.XData == 20), handles)));

            marker.Value = 55;
            testCase.verifyTrue(all(arrayfun(@(h) all(h.XData == 55), handles)));

            marker.Visible = 'off';
            testCase.verifyTrue(all(strcmp(get(handles, "Visible"), 'off')));
            marker.Visible = 'on';
        end

        function draggingTheMarkerClampsAndNotifies(testCase)
            [hFigure, hAxes] = createDataAxes(testCase);
            marker = uim.widget.FrameMarker(hAxes, "Minimum", 10, "Maximum", 90, "Value", 20);
            testCase.addTeardown(@deleteValid, marker);
            marker.ValueChangedFcn = @(~, evt) setappdata(hFigure, "Frame", evt.NewValue);

            knob = findall(hAxes, "Tag", "FrameMarker", "Marker", "v");
            testCase.assertNumElements(knob, 1);

            knob.ButtonDownFcn(knob, [])
            marker.knobMoving([], [])
            testCase.verifyTrue(isappdata(hFigure, "Frame"));
            testCase.verifyGreaterThanOrEqual(marker.Value, 10, "The value is clamped.");
            testCase.verifyLessThanOrEqual(marker.Value, 90);

            marker.knobReleased([], [])
            testCase.verifyEqual(knob.MarkerSize, 10, "Release restores the knob size.");
        end

        function hoveringTheMarkerEnlargesTheKnob(testCase)
            [hFigure, hAxes] = createDataAxes(testCase);
            marker = uim.widget.FrameMarker(hAxes, "Minimum", 1, "Maximum", 100, "Value", 20);
            testCase.addTeardown(@deleteValid, marker);
            knob = findall(hAxes, "Tag", "FrameMarker", "Marker", "v");

            marker.onMouseEnterSlider(knob)
            testCase.verifyEqual(knob.MarkerSize, 12);
            testCase.verifyEqual(hFigure.Pointer, 'hand');

            marker.onMouseExitSlider(knob)
            testCase.verifyEqual(knob.MarkerSize, 10);
            testCase.verifyEqual(hFigure.Pointer, 'arrow');
        end
    end

    methods (Test) % Control tooltips and hover

        function hoveringAControlShowsItsTooltip(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            testCase.addTeardown(@deleteValid, toolbar);
            button = toolbar.addButton("Text", "A", "Tooltip", "Do the thing");

            behavior = buttonPointerBehavior(canvas.Axes);
            testCase.assertNotEmpty(behavior, "Controls install hover behaviour.");

            behavior.enterFcn(hFigure, [0, 0])
            hTooltip = findall(hFigure, "Type", "text", "String", "Do the thing");
            testCase.assertNumElements(hTooltip, 1);
            testCase.verifyEqual(char(hTooltip.Visible), 'on');

            % Changing the text while hovering refreshes what is shown
            button.Tooltip = 'Do something else';
            testCase.verifyNotEmpty(findall(hFigure, "Type", "text", ...
                "String", "Do something else"));

            behavior.exitFcn(hFigure, [0, 0])
            hTooltip = findall(hFigure, "Type", "text", "String", "Do something else");
            testCase.verifyTrue(isempty(hTooltip) || strcmp(hTooltip.Visible, 'off'), ...
                "Leaving the control hides its tooltip.");
            testCase.verifyTrue(isvalid(button));
        end

        function tooltipPositionTracksTheControl(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            testCase.addTeardown(@deleteValid, toolbar);
            button = toolbar.addButton("Text", "A", "Tooltip", "Tip");

            behavior = buttonPointerBehavior(canvas.Axes);
            behavior.enterFcn(hFigure, [0, 0])
            hTooltip = findall(hFigure, "Type", "text", "String", "Tip");
            testCase.assertNumElements(hTooltip, 1);
            positionBefore = hTooltip.Position(1);

            toolbar.Position(1:2) = toolbar.Position(1:2) + [40, 0];
            behavior.enterFcn(hFigure, [0, 0])
            testCase.verifyEqual(hTooltip.Position(1), positionBefore + 40, "AbsTol", 1e-6, ...
                "The tooltip follows the control it belongs to.");
            testCase.verifyTrue(isvalid(button));
        end
    end

    methods (Test) % Channel colour menu

        function channelColourMenuAppliesNamedColours(testCase)
            [~, hPanel] = createPanel(testCase);
            indicator = uim.widget.ChannelIndicator(hPanel, "NumChannels", 2);
            testCase.addTeardown(@deleteValid, indicator);

            hIndicators = findall(hPanel, "Tag", "ChannelIndicator");
            menu = hIndicators(1).ContextMenu;
            testCase.assertNotEmpty(menu, "Indicators carry a colour context menu.");

            items = string({menu.Children.Text});
            testCase.verifyTrue(all(ismember(["Red", "Green", "Blue", "Cyan", ...
                "Magenta", "Yellow", "Select Color...", "Enter Wavelength...", ...
                "Make Current Colors Default"], items)));
            testCase.verifyTrue(all(arrayfun(@(m) ~isempty(m.MenuSelectedFcn), menu.Children)), ...
                "Every menu item is wired up.");

            % Applying a colour needs the channel recorded by a right-click,
            % and SelectionType cannot be driven from a test, so the
            % colour-application path is exercised through the public
            % ChannelColors property instead.
            indicator.ChannelColors = {[0, 1, 0], [1, 0, 1], 'b', 'c', 'm', 'y'};
            testCase.verifyEqual(hIndicators(end).FaceColor, [0, 1, 0]);
        end
    end

    methods (Test) % uim.decorator.Box

        function boxDecoratorDrawsAndResizesItsBackground(testCase)
            [~, canvas] = createCanvas(testCase);
            box = uim.decorator.Box(canvas, "Position", [20, 30, 120, 60], ...
                "Size", [120, 60], "PositionMode", "manual", ...
                "BackgroundColor", [0.2, 0.2, 0.2], "BackgroundAlpha", 0.5);
            testCase.addTeardown(@deleteValid, box);

            hBackground = findobj(canvas.Axes, "Type", "patch", ...
                "FaceColor", [0.2, 0.2, 0.2]);
            testCase.assertNumElements(hBackground, 1);
            testCase.verifyEqual(hBackground.FaceAlpha, 0.5);

            widthBefore = max(hBackground.XData) - min(hBackground.XData);
            box.Size = [200, 60];
            widthAfter = max(hBackground.XData) - min(hBackground.XData);
            testCase.verifyGreaterThan(widthAfter, widthBefore, ...
                "Resizing the box redraws its background.");
        end
    end

    methods (Test) % Small utilities

        function toolboxRootIsTheSourceFolder(testCase)
            rootDir = uim.toolboxdir();
            testCase.verifyTrue(isfolder(rootDir));
            testCase.verifyTrue(isfolder(fullfile(rootDir, "uim", "+uim")), ...
                "The package sits under the reported root.");
        end

        function labelToggleSwapsTheTwoTexts(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            menu = uimenu(hFigure, "Text", "Show grid");

            uim.utility.toggleUicontrolLabel(menu, 'Show', 'Hide')
            testCase.verifyEqual(menu.Text, 'Hide grid');
            uim.utility.toggleUicontrolLabel(menu, 'Show', 'Hide')
            testCase.verifyEqual(menu.Text, 'Show grid');

            uim.utility.toggleUicontrolLabel([], 'Show', 'Hide')

            menu.Text = 'Something else';
            testCase.verifyError(...
                @() uim.utility.toggleUicontrolLabel(menu, 'Show', 'Hide'), ...
                "uim:toggleUicontrolLabel:LabelNotFound");
        end
    end
end

function behavior = buttonPointerBehavior(hAxes)
%buttonPointerBehavior Hover behaviour installed on a control's background
    patches = findobj(hAxes, "Type", "patch");
    behavior = [];
    for i = 1:numel(patches)
        candidate = iptGetPointerBehavior(patches(i));
        if ~isempty(candidate) && ~isempty(candidate.enterFcn)
            behavior = candidate;
            return
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

function [hFigure, hAxes] = createDataAxes(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 500, 300]);
    testCase.addTeardown(@deleteValid, hFigure);
    hAxes = axes(hFigure, "Units", "pixels", "Position", [40, 40, 400, 200], ...
        "XLim", [1, 100], "YLim", [0, 1]);
    hold(hAxes, "on")
end

function assignProperty(object, propertyName, value)
    object.(propertyName) = value;
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
