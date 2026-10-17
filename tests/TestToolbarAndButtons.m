classdef TestToolbarAndButtons < matlab.unittest.TestCase
%TestToolbarAndButtons Headless behaviour of Toolbar, Separator and Button

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % Toolbar

        function rightAlignedRunIncludesSpacing(testCase)
            [~, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            testCase.addTeardown(@deleteValid, toolbar);
            buttons = cell(1, 4);
            for k = 1:4
                buttons{k} = toolbar.addButton("Text", string(char('A' + k - 1)));
            end
            toolbar.Spacing = 8;
            toolbar.ComponentAlignment = "right";
            rightEdge = @(h) h.Position(1) + h.Position(3);

            % removeButton lays the buttons out again with repositionButtons
            toolbar.removeButton(buttons{1})

            testCase.verifyEqual(rightEdge(buttons{4}), rightEdge(toolbar) - toolbar.Padding(3), ...
                "AbsTol", 1e-9, "The last button ends at the padded right edge.");
            testCase.verifyEqual(buttons{3}.Position(1), rightEdge(buttons{2}) + 8, "AbsTol", 1e-9);
        end

        function buttonAddedAfterSpacingChangeFollowsTheLast(testCase)
            [~, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest", ...
                "BarExtensionMode", "expanded");
            testCase.addTeardown(@deleteValid, toolbar);
            toolbar.addButton("Text", "A");
            second = toolbar.addButton("Text", "B");

            toolbar.Spacing = 40;
            third = toolbar.addButton("Text", "C");

            testCase.verifyEqual(third.Position(1), second.Position(1) + second.Position(3) + 40, ...
                "AbsTol", 1e-9, "The new button is placed one Spacing after the last one.");
        end

        function separatorCanBeTheFirstItem(testCase)
            [~, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            testCase.addTeardown(@deleteValid, toolbar);

            separator = toolbar.addSeparator();
            button = toolbar.addButton("Text", "A");

            testCase.verifyEqual(toolbar.NumButtons, 2);
            testCase.verifyGreaterThan(button.Position(1), separator.Position(1));
        end

        function toolbarLaysOutButtonsAndSeparators(testCase)
            [~, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            testCase.addTeardown(@deleteValid, toolbar);

            first = toolbar.addButton("Text", "A", "Tag", "ButtonA");
            separator = toolbar.addSeparator();
            second = toolbar.addButton("Text", "B", "Tag", "ButtonB");

            testCase.verifyEqual(toolbar.NumButtons, 3);
            testCase.verifyClass(separator, "uim.decorator.Separator");
            testCase.verifyGreaterThan(second.Position(1), first.Position(1) + first.Position(3));
            testCase.verifyEqual(toolbar.getHandle("ButtonB"), second);
            testCase.verifyEqual(toolbar.Orientation, 'horizontal');

            gapBefore = second.Position(1) - (separator.Position(1) + separator.Position(3));
            toolbar.Spacing = toolbar.Spacing + 12;
            gapAfter = second.Position(1) - (separator.Position(1) + separator.Position(3));
            testCase.verifyEqual(gapAfter - gapBefore, 12, "AbsTol", 1e-9);

            rightEdge = @(h) h.Position(1) + h.Position(3);
            toolbar.ComponentAlignment = 'right';
            testCase.verifyLessThanOrEqual(rightEdge(second), rightEdge(toolbar) + 1e-9);
            toolbar.ComponentAlignment = 'center';
            toolbar.ComponentAlignment = 'left';
            testCase.verifyLessThan(first.Position(1), second.Position(1));
        end

        function toolbarStylingPropagatesToButtons(testCase)
            [~, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            testCase.addTeardown(@deleteValid, toolbar);
            button = toolbar.addButton("Text", "A");

            toolbar.DarkMode = 'off';
            testCase.verifyClass(button.Style, "uim.style.ButtonLightModeTranslucent");
            toolbar.DarkMode = 'on';
            testCase.verifyClass(button.Style, "uim.style.ButtonDarkMode");

            toolbar.Height = 44;
            testCase.verifyEqual(toolbar.Height, 44);
            testCase.verifyEqual(toolbar.Width, toolbar.Position(3));

            toolbar.BackgroundMode = 'full';
            toolbar.BackgroundMode = 'wrap';
            tightWidth = toolbar.Position(3);
            toolbar.BarExtensionMode = 'expanded';
            testCase.verifyGreaterThanOrEqual(toolbar.Position(3), tightWidth);

            toolbar.Visible = 'off';
            testCase.verifyEqual(char(button.Visible), 'off');
            toolbar.Visible = 'on';
            testCase.verifyEqual(char(button.Visible), 'on');
        end

        function canvasShowsAndHidesTooltips(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            testCase.addTeardown(@deleteValid, toolbar);
            button = toolbar.addButton("Text", "A");
            button.Tooltip = 'Run the thing';

            canvas.showTooltip('Run the thing', [100, 100])
            testCase.verifyNotEmpty(findall(hFigure, "Type", "text", "String", "Run the thing"));
            canvas.hideTooltip()
            hTooltip = findall(hFigure, "Type", "text", "String", "Run the thing");
            testCase.verifyTrue(isempty(hTooltip) || strcmp(hTooltip(1).Visible, 'off'));
        end
    end

    methods (Test) % Button

        function buttonTextFollowsAlignmentSettings(testCase)
            [~, canvas] = createCanvas(testCase);
            button = uim.control.Button(canvas, "Text", "Go", "Position", [10, 10, 120, 40], ...
                "Size", [120, 40], "PositionMode", "manual", "Padding", [3, 3, 3, 3]);
            testCase.addTeardown(@deleteValid, button);
            hText = findobj(canvas.Axes, "Type", "text", "String", "Go");
            testCase.assertNumElements(hText, 1);

            for horizontal = ["left", "center", "right"]
                for vertical = ["bottom", "middle", "top"]
                    button.HorizontalTextAlignment = char(horizontal);
                    button.VerticalTextAlignment = char(vertical);
                    expected = button.Position(1:2) + uim.control.internal.contentOffsetInBox(...
                        button.Position(3:4), hText.Extent(3:4), button.Padding, ...
                        horizontal, vertical);
                    testCase.verifyEqual(hText.Position(1:2), expected, "AbsTol", 1e-6, ...
                        sprintf("%s/%s", horizontal, vertical));
                end
            end

            button.FontSize = 20;
            testCase.verifyEqual(hText.FontSize, 20);
            button.Text = "Stop";
            testCase.verifyEqual(hText.String, 'Stop');
            testCase.verifyEqual(button.String, 'Stop');
            button.FontWeight = 'bold';
            testCase.verifyEqual(hText.FontWeight, 'bold');
        end

        function buttonIconFitsInsidePadding(testCase)
            [~, canvas] = createCanvas(testCase);
            icons = uim.style.getDefaultIcons();
            button = uim.control.Button(canvas, "Icon", icons.zoomIn, ...
                "Position", [10, 60, 40, 40], "Size", [40, 40], ...
                "PositionMode", "manual", "Padding", [4, 4, 4, 4]);
            testCase.addTeardown(@deleteValid, button);

            bbox = iconBoundingBox(canvas.Axes);
            inner = [button.Position(1:2) + 4, button.Position(3:4) - 8];
            testCase.verifyGreaterThanOrEqual(bbox(1:2), inner(1:2) - 1e-6);
            testCase.verifyLessThanOrEqual(bbox(1:2) + bbox(3:4), inner(1:2) + inner(3:4) + 1e-6);
            testCase.verifyEqual(max(bbox(3:4)), max(inner(3:4)), "AbsTol", 1e-6, ...
                "The icon fills the limiting inner dimension.");

            button.IconAlignment = 'right';
            button.IconSize = [12, 12];
            button.Icon = icons.zoomOut;
            bbox = iconBoundingBox(canvas.Axes);
            testCase.verifyEqual(max(bbox(3:4)), 12, "AbsTol", 1e-6);
            testCase.verifyEqual(bbox(1) + bbox(3), button.Position(1) + button.Position(3) - 4, ...
                "AbsTol", 1e-6, "Right-aligned icon touches the inner right edge.");
        end

        function buttonSymbolIconsAndIconTextSpacing(testCase)
            [~, canvas] = createCanvas(testCase);
            symbolButton = uim.control.Button(canvas, "Icon", "x", ...
                "Position", [10, 110, 30, 30], "Size", [30, 30], "PositionMode", "manual");
            testCase.addTeardown(@deleteValid, symbolButton);
            testCase.verifyNotEmpty(findobj(canvas.Axes, "Type", "line", "Marker", "x"));

            icons = uim.style.getDefaultIcons();
            comboButton = uim.control.Button(canvas, "Icon", icons.pan, "Text", "Pan", ...
                "Position", [60, 110, 120, 30], "Size", [120, 30], ...
                "PositionMode", "manual", "Padding", [3, 3, 3, 3]);
            testCase.addTeardown(@deleteValid, comboButton);
            hText = findobj(canvas.Axes, "Type", "text", "String", "Pan");
            bbox = iconBoundingBox(canvas.Axes);
            testCase.verifyGreaterThanOrEqual(hText.Position(1), bbox(1) + bbox(3), ...
                "Text starts after the icon.");
        end

        function buttonMechanicalActionsDriveValueAndCallback(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            button = uim.control.Button(canvas, "Text", "Go", "Position", [10, 10, 80, 30], ...
                "Size", [80, 30], "PositionMode", "manual", "Mode", "togglebutton", ...
                "MechanicalAction", "Switch when pressed");
            testCase.addTeardown(@deleteValid, button);
            button.Callback = @(~, ~) setappdata(hFigure, "Pressed", getappdata(hFigure, "Pressed") + 1);
            setappdata(hFigure, "Pressed", 0)

            hBackground = findPressablePatch(canvas.Axes);
            hBackground.ButtonDownFcn(hBackground, [])
            testCase.verifyTrue(logical(button.Value));
            testCase.verifyEqual(getappdata(hFigure, "Pressed"), 1);
            hBackground.ButtonDownFcn(hBackground, [])
            testCase.verifyFalse(logical(button.Value));

            button.Mode = 'pushbutton';
            hBackground.ButtonDownFcn(hBackground, [])
            testCase.verifyFalse(logical(button.Value), "A push button latches and releases.");
            testCase.verifyEqual(getappdata(hFigure, "Pressed"), 3);
        end

        function switchUntilReleasedWorksInBothModes(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            for mode = ["pushbutton", "togglebutton"]
                button = uim.control.Button(canvas, "Text", "Go", "Position", [10, 10, 80, 30], ...
                    "Size", [80, 30], "PositionMode", "manual", "Mode", mode, ...
                    "MechanicalAction", "Switch until released");
                testCase.addTeardown(@deleteValid, button);
                button.Callback = @(source, ~) setappdata(hFigure, "Values", ...
                    [getappdata(hFigure, "Values"), logical(source.Value)]);
                setappdata(hFigure, "Values", logical.empty)

                hBackground = findPressablePatch(canvas.Axes);
                hBackground.ButtonDownFcn(hBackground, [])
                testCase.verifyTrue(logical(button.Value), mode + ": Value is on while pressed.");
                releaseButton(button)

                testCase.verifyFalse(logical(button.Value), mode + ": Value is off after release.");
                testCase.verifyEqual(getappdata(hFigure, "Values"), [true, false], ...
                    mode + ": Callback runs on press and on release.");
                delete(button)
            end
        end

        function toggleReleasedOutsideKeepsItsValue(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            button = uim.control.Button(canvas, "Text", "Go", "Position", [10, 10, 80, 30], ...
                "Size", [80, 30], "PositionMode", "manual", "Mode", "togglebutton");
            testCase.addTeardown(@deleteValid, button);
            button.Callback = @(~, ~) setappdata(hFigure, "Pressed", getappdata(hFigure, "Pressed") + 1);
            setappdata(hFigure, "Pressed", 0)
            hBackground = findPressablePatch(canvas.Axes);

            % The pointer is not over the button (no enter event).
            hBackground.ButtonDownFcn(hBackground, [])
            releaseButton(button)
            testCase.verifyFalse(logical(button.Value), ...
                "A release outside the button does not toggle it.");
            testCase.verifyEqual(getappdata(hFigure, "Pressed"), 0);

            testCase.assumeTrue(exist("iptGetPointerBehavior", "file") > 0, ...
                "Hover needs the Image Processing Toolbox pointer manager.");
            behavior = iptGetPointerBehavior(hBackground);
            behavior.enterFcn(hFigure, [0, 0])
            hBackground.ButtonDownFcn(hBackground, [])
            releaseButton(button)
            testCase.verifyTrue(logical(button.Value), "A release over the button toggles it.");
            testCase.verifyEqual(getappdata(hFigure, "Pressed"), 1);
        end

        function buttonFollowsToggledPointerTool(testCase)
            [hFigure, canvas] = createCanvas(testCase);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [300, 300, 100, 80]);
            tool = uim.interface.pointertools.Pan(hAxes);
            button = uim.control.Button(canvas, "Text", "Pan", "Position", [10, 10, 80, 30], ...
                "Size", [80, 30], "PositionMode", "manual", "Mode", "togglebutton");
            testCase.addTeardown(@deleteValid, button);

            button.addToggleListener(tool, 'ToggledPointerTool')
            tool.activate()
            testCase.verifyTrue(logical(button.Value));
            tool.deactivate()
            testCase.verifyFalse(logical(button.Value));

            button.Value = true;
            testCase.verifyTrue(logical(button.Value));
            testCase.verifySize(button.Extent, [1, 4]);
        end
    end
end

function [hFigure, canvas] = createCanvas(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 500, 400]);
    testCase.addTeardown(@deleteValid, hFigure);
    hPanel = uipanel(hFigure, "Units", "normalized", "Position", [0, 0, 1, 1]);
    canvas = uim.UIComponentCanvas(hPanel);
end

function bbox = iconBoundingBox(hAxes)
%iconBoundingBox Bounding box of all vector-icon polygons in the axes
    polygons = findobj(hAxes, "Type", "polygon");
    vertices = cat(1, polygons.Shape);
    vertices = cat(1, vertices.Vertices);
    bbox = [min(vertices), max(vertices) - min(vertices)];
end

function hPatch = findPressablePatch(hAxes)
%findPressablePatch The button background is the patch wired to onMousePressed
    patches = findobj(hAxes, "Type", "patch");
    isPressable = arrayfun(@(h) isa(h.ButtonDownFcn, "function_handle") && ...
        contains(func2str(h.ButtonDownFcn), "onMousePressed"), patches);
    hPatch = patches(find(isPressable, 1));
end

function releaseButton(button)
%releaseButton Run the figure mouse-release listener a press installed
%
%   A hidden figure cannot raise WindowMouseRelease, and the listener is a
%   protected property, so it is read through struct().
    warningState = warning("off", "MATLAB:structOnObject");
    restoreWarning = onCleanup(@() warning(warningState));
    buttonState = struct(button);
    buttonState.MouseReleasedListener.Callback([], [])
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
