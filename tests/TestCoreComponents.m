classdef TestCoreComponents < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test)
        function utilityServicesAreSelfContained(testCase)
            defaults = struct("Alpha", 1, "Name", "default");
            options = uim.utility.parseNameValue(defaults, ...
                "Alpha", 3, "Name", "standalone");

            testCase.verifyEqual(options.Alpha, 3);
            testCase.verifyEqual(options.Name, "standalone");
            testCase.verifyEqual(uim.utility.range([2, 5, 11]), 9);

            eventData = uim.event.EventData("Index", 4);
            testCase.verifyEqual(eventData.Index, 4);
        end

        function axesControlsRunInClassicFigure(testCase)
            hFigure = figure("Visible", "off", "Position", [100, 100, 500, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Units", "normalized", ...
                "Position", [0, 0, 1, 1]);
            canvas = uim.UIComponentCanvas(hPanel);

            toolbar = uim.widget.Toolbar(canvas, "Location", "northwest");
            button = toolbar.addButton("Text", "Run", "Tag", "RunButton");
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 10, ...
                "Low", 2, "High", 8);
            pages = uim.widget.PageIndicator(canvas, {"One", "Two"});
            pointerManager = uim.interface.PointerManager(hFigure, canvas.Axes, ...
                {"zoomIn", "zoomOut", "pan", "dataCursor"});
            testCase.addTeardown(@deleteValid, pointerManager);

            testCase.verifyClass(canvas.Axes, "matlab.graphics.axis.Axes");
            testCase.verifyClass(button, "uim.control.Button");
            testCase.verifyEqual(slider.Low, 2);
            testCase.verifyEqual(slider.High, 8);
            testCase.verifyEqual(pages.CurrentPage, 1);
            testCase.verifyEqual(numel(fieldnames(pointerManager.Pointers)), 4);
        end

        function axesControlsRunInUiFigure(testCase)
            hFigure = uifigure("Visible", "off", "Position", [100, 100, 500, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Position", [1, 1, 500, 400]);
            canvas = uim.UIComponentCanvas(hPanel);
            toolbar = uim.widget.Toolbar(canvas);
            button = toolbar.addButton("Text", "Run");

            testCase.verifyClass(canvas.Axes, "matlab.graphics.axis.Axes");
            testCase.verifyClass(button, "uim.control.Button");
        end

        function tabContentBoundsWorkAcrossFigureBackends(testCase)
            classicFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, classicFigure);
            classicTab = uitab(uitabgroup(classicFigure));

            webFigure = uifigure("Visible", "off");
            testCase.addTeardown(@deleteValid, webFigure);
            webTab = uitab(uitabgroup(webFigure));

            classicPosition = uim.utility.getContentPixelPosition(classicTab);
            webPosition = uim.utility.getContentPixelPosition(webTab);

            testCase.verifyGreaterThan(classicPosition(3:4), [0, 0]);
            testCase.verifyGreaterThan(webPosition(3:4), [0, 0]);
        end

        function childOfPrivateCanvasContainerSharesItsAxes(testCase)
            hFigure = figure("Visible", "off", "Position", [100, 100, 500, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Units", "normalized", ...
                "Position", [0, 0, 1, 1]);

            toolbar = uim.widget.Toolbar(hPanel, "Location", "northeast", ...
                "CanvasMode", "private");
            button = toolbar.addButton("Text", "Run");

            testCase.verifyEqual(button.Canvas, toolbar.Canvas);
            testCase.verifyClass(button.Canvas, "matlab.graphics.axis.Axes");
        end

        function axisZoomDragsAndClampsAxisLimits(testCase)
            hFigure = figure("Visible", "off", "Units", "pixels", ...
                "Position", [100, 100, 400, 300]);
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes("Parent", hFigure, "Units", "pixels", ...
                "Position", [50, 50, 300, 200], "XLim", [0, 10], "YLim", [0, 5]);

            pointerTool = uim.interface.pointertools.AxisZoom(hAxes);
            testCase.verifyEqual(pointerTool.XLimOrig, [0, 10]);
            testCase.verifyEqual(pointerTool.YLimOrig, [0, 5]);

            % Dragging right from a zoomed-in view widens XLim (zoom out).
            hAxes.XLim = [3, 7];
            pointerTool.PreviousMousePoint = [150, 150];
            hFigure.CurrentPoint = [180, 150];
            pointerTool.dragXLimits();
            testCase.verifyGreaterThan(diff(hAxes.XLim), diff([3, 7]));

            % Dragging left narrows XLim (zoom in).
            hAxes.XLim = [3, 7];
            pointerTool.PreviousMousePoint = [180, 150];
            hFigure.CurrentPoint = [150, 150];
            pointerTool.dragXLimits();
            testCase.verifyLessThan(diff(hAxes.XLim), diff([3, 7]));

            % Limits never expand past the axes' original limits.
            hAxes.XLim = [0, 10];
            pointerTool.PreviousMousePoint = [150, 150];
            hFigure.CurrentPoint = [5000, 150];
            pointerTool.dragXLimits();
            testCase.verifyEqual(hAxes.XLim, [0, 10]);

            % dragYLimits mirrors the same behavior on the Y axis.
            hAxes.YLim = [1, 4];
            pointerTool.PreviousMousePoint = [150, 150];
            hFigure.CurrentPoint = [150, 180];
            pointerTool.dragYLimits("left");
            testCase.verifyGreaterThan(diff(hAxes.YLim), diff([1, 4]));
        end

        function slidebarRendersTicksInAxesMode(testCase)
            % Mirrors the construction pattern PlaneSwitcher.m actually uses
            % (a non-axes Parent, which makes slidebar create its own
            % private pixel-unit axes internally), but with ticks enabled.
            hFigure = figure("Visible", "off", "Position", [100, 100, 400, 300]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);

            slider = uim.widget.Slider("Parent", hPanel, "Units", "pixel", ...
                "Position", [10, 10, 200, 20], "Min", 0, "Max", 10, "TickLength", 5);

            hAxes = findall(hPanel, "Type", "axes");
            tickLines = findall(hAxes, "Type", "line");

            testCase.verifyEqual(numel(tickLines), 9);
            for i = 1:numel(tickLines)
                xData = get(tickLines(i), "XData");
                yData = get(tickLines(i), "YData");
                testCase.verifyTrue(all(isfinite(xData(~isnan(xData)))));
                testCase.verifyTrue(all(isfinite(yData(~isnan(yData)))));
            end

            % Resizing should redraw ticks without error.
            slider.Position = [10, 10, 150, 20];
            tickLines = findall(hAxes, "Type", "line");
            testCase.verifyEqual(numel(tickLines), 9);
        end

        function slidebarWithTicksRendersInCallerSuppliedAxes(testCase)
            % When the caller passes an existing axes directly as Parent,
            % construction must not clear graphics already plotted (the
            % background patch) via the axes' default hold-off behavior.
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes("Parent", hFigure, "XLim", [0, 10], "YLim", [0, 1]);
            wasHoldOn = ishold(hAxes);

            slider = uim.widget.Slider("Parent", hAxes, "Min", 0, "Max", 10, ...
                "TickLength", 0.05, "Position", [1, 0.2, 8, 0.6]);

            testCase.verifyClass(slider, "uim.widget.Slider");
            tickLines = findall(hAxes, "Type", "line");
            testCase.verifyEqual(numel(tickLines), 9);

            % Hold state should be restored to what it was before construction.
            testCase.verifyEqual(ishold(hAxes), wasHoldOn);
        end

        function imageAndRoiGraphicsRun(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);

            tileAxes = uim.graphics.TiledImageAxes(hPanel, ...
                "GridSize", [2, 2], "ImageSize", [16, 16]);
            testCase.verifyEqual(tileAxes.NumTiles, 4);

            hAxes = axes(hPanel);
            imageData = uint8(255 * ones(40, 40, 3));
            imageData(10:30, 10:30, :) = 0;
            hPatch = uim.graphics.patchLineDrawing(hAxes, imageData, ...
                "SmoothIter", 0, "cropImage", false, "plotType", "patch");

            testCase.verifyNotEmpty(hPatch);
            testCase.verifyTrue(all(isgraphics(hPatch)));
        end

        function rangeSliderHasFiniteDefaults(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            slider = uim.widget.RangeSlider(canvas);

            testCase.verifyEqual([slider.Min, slider.Low, slider.High, slider.Max], ...
                [0, 0, 1, 1]);
        end

        function rangeSliderClampsValuesWhenLimitsChange(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));
            slider = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 10, ...
                "Low", 2, "High", 8);

            slider.Min = 9;
            testCase.verifyEqual([slider.Low, slider.High], [9, 9]);

            slider.Min = 0;
            slider.Low = 2;
            slider.High = 8;
            slider.Max = 1;
            testCase.verifyEqual([slider.Low, slider.High], [1, 1]);
        end

        function pageIndicatorHonorsHiddenTextAfterPageChange(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));
            pages = uim.widget.PageIndicator(canvas, {"One", "Two"}, ...
                "TextVisibility", "off");

            pages.changePage(2);
            labels = findall(canvas.Axes, "Type", "text");
            labelStrings = string({labels.String});
            secondLabel = labels(labelStrings == "Two");

            testCase.verifyEqual(char(secondLabel.Visible), 'off');
        end

        function privateToolbarRendersAllSymbolButtons(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);
            toolbar = uim.widget.Toolbar(hPanel, "CanvasMode", "private");

            xButton = toolbar.addButton("Icon", "x");
            oButton = toolbar.addButton("Icon", "o");

            testCase.verifyClass(xButton, "uim.control.Button");
            testCase.verifyClass(oButton, "uim.control.Button");
        end

        function canvasAppliesConstructionOptions(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);

            canvas = uim.UIComponentCanvas(hFigure, "Tag", "My Canvas");

            testCase.verifyEqual(canvas.Tag, 'My Canvas');
            testCase.verifyEqual(canvas.Axes.Tag, 'My Canvas Axes');
        end

        function canvasEnforcesOneCanvasPerParent(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(hFigure);

            testCase.verifyError(@() uim.UIComponentCanvas(hFigure), ...
                "uim:UIComponentCanvas:DuplicateCanvas");

            testCase.verifySameHandle(...
                uim.UIComponentCanvas.getOrCreate(hFigure), canvas);

            delete(canvas)
            newCanvas = uim.UIComponentCanvas.getOrCreate(hFigure);
            testCase.verifyTrue(isvalid(newCanvas));
            testCase.verifyNotSameHandle(newCanvas, canvas);
        end

        function canvasRestoresAndPreservesAxesCreationCallbacks(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            originalCallback = @(~, ~) [];
            set(hFigure, "DefaultAxesCreateFcn", originalCallback);

            canvas = uim.UIComponentCanvas(hFigure);
            delete(canvas);
            testCase.verifyEqual(func2str(get(hFigure, "DefaultAxesCreateFcn")), ...
                func2str(originalCallback));

            canvas = uim.UIComponentCanvas(hFigure);
            replacementCallback = @(~, ~) [];
            set(hFigure, "DefaultAxesCreateFcn", replacementCallback);
            delete(canvas);
            testCase.verifyEqual(func2str(get(hFigure, "DefaultAxesCreateFcn")), ...
                func2str(replacementCallback));
        end

        function canvasReparentsAndCleansUpParentOwnership(testCase)
            firstFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, firstFigure);
            secondFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, secondFigure);
            canvas = uim.UIComponentCanvas(firstFigure);

            canvas.reparent(secondFigure);

            testCase.verifyEqual(canvas.Parent, secondFigure);
            testCase.verifyEqual(canvas.Axes.Parent, secondFigure);
            testCase.verifyFalse(isappdata(firstFigure, "UIComponentCanvas"));
            testCase.verifyEqual(getappdata(secondFigure, "UIComponentCanvas"), canvas);

            delete(secondFigure);
            testCase.verifyFalse(isvalid(canvas));
        end

        function canvasChainsPriorAxesCreationCallback(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);
            setappdata(hPanel, "PriorAxesCreateFcnArguments", {});
            priorCallback = @(src, ~, value) setappdata(hPanel, ...
                "PriorAxesCreateFcnArguments", {src, value});
            set(hPanel, "DefaultAxesCreateFcn", {priorCallback, true});
            canvas = uim.UIComponentCanvas(hPanel);

            siblingAxes = axes(hPanel);

            callbackArguments = getappdata(hPanel, "PriorAxesCreateFcnArguments");
            testCase.verifyEqual(callbackArguments{1}, siblingAxes);
            testCase.verifyTrue(callbackArguments{2});
            delete(canvas);
            restoredCallback = get(hPanel, "DefaultAxesCreateFcn");
            testCase.verifyEqual(func2str(restoredCallback{1}), ...
                func2str(priorCallback));
            testCase.verifyTrue(restoredCallback{2});
        end

        function pointerManagerRestoresOnlyItsOwnMotionCallback(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure);

            manager = uim.interface.PointerManager(hFigure, hAxes);
            delete(manager);
            testCase.verifyEmpty(hFigure.WindowButtonMotionFcn);

            manager = uim.interface.PointerManager(hFigure, hAxes);
            replacementCallback = @(~, ~) [];
            hFigure.WindowButtonMotionFcn = replacementCallback;
            delete(manager);

            testCase.verifyEqual(func2str(hFigure.WindowButtonMotionFcn), ...
                func2str(replacementCallback));
        end

        function coordinateConversionsRespectLocalAndRecursivePixelFrames(testCase)
            hFigure = figure("Visible", "off", "Position", [100, 100, 500, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [100, 80, 350, 250]);
            hAxes = axes(hPanel, "Units", "pixels", "Position", [50, 40, 300, 200], ...
                "XLim", [2, 8], "YLim", [10, 20], "XDir", "reverse", "YDir", "reverse");
            dataPoints = [2, 10; 5, 15; 8, 20];

            localPixelPoints = uim.utility.du2px(hAxes, dataPoints);
            actualDataPoints = uim.utility.px2du(hAxes, localPixelPoints);
            testCase.verifyEqual(actualDataPoints, dataPoints, "AbsTol", 1e-10);

            recursivePixelPoints = uim.utility.du2px(hAxes, dataPoints, true);
            actualDataPoints = uim.utility.px2du(hAxes, recursivePixelPoints, true);
            testCase.verifyEqual(actualDataPoints, dataPoints, "AbsTol", 1e-10);
        end

        function channelIndicatorSupportsInternalAxesAndFourChannels(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            parentApp = struct("Figure", hFigure);
            hPanel = uipanel(hFigure);

            indicator = uim.widget.ChannelIndicator(parentApp, hPanel, "NumChannels", 4);

            testCase.verifyEqual(indicator.NumChannels, 4);
            testCase.verifyEqual(numel(findall(hPanel, "Tag", "ChannelIndicator")), 4);
        end

        function zoomLimitSettersOperateOnTheirAxes(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "XLim", [0, 10], "YLim", [0, 5]);
            pointerTool = uim.interface.pointertools.ZoomIn(hAxes);

            pointerTool.setNewXLims([2, 8]);
            pointerTool.setNewYLims([1, 4]);

            testCase.verifyEqual(hAxes.XLim, [2, 8]);
            testCase.verifyEqual(hAxes.YLim, [1, 4]);
        end
    end
end

function deleteValid(object)
    arguments
        object
    end

    if ~isempty(object) && all(isvalid(object))
        delete(object)
    end
end
