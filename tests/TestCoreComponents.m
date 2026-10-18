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

        function rangeSliderRateLimitsCallbackPerInstance(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));
            sliderA = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 10, ...
                "CallbackRefreshRate", 1);
            sliderB = uim.widget.RangeSlider(canvas, "Min", 0, "Max", 10, ...
                "CallbackRefreshRate", 1);
            sliderA.Callback = @(~, evt) setappdata(hFigure, "LowA", evt.Low);
            sliderB.Callback = @(~, evt) setappdata(hFigure, "LowB", evt.Low);

            sliderA.Low = 2;
            sliderB.Low = 3;

            testCase.verifyEqual(getappdata(hFigure, "LowA"), 2, ...
                "The first change of a slider notifies.");
            testCase.verifyEqual(getappdata(hFigure, "LowB"), 3, ...
                "A change on one slider does not delay another slider.");

            sliderA.Low = 4;
            testCase.verifyEqual(getappdata(hFigure, "LowA"), 2, ...
                "A second change within 1 s is not notified at a rate of 1.");
        end

        function contrastSliderResetsLimitsOutsideNewDataLimits(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));
            slider = uim.widget.ContrastSlider(canvas, "DataLimits", [0, 255], "Limits", [0, 255]);
            testCase.addTeardown(@deleteValid, slider);

            slider.DataLimits = [300, 400];
            testCase.verifyEqual(slider.Limits, [300, 400], ...
                "Limits outside the new range are reset to the full range.");

            slider.Limits = [320, 350];
            slider.DataLimits = [310, 420];
            testCase.verifyEqual(slider.Limits, [320, 350], ...
                "Limits inside the new range are kept.");
        end
                
        function marginChangeKeepsAManualSize(testCase)
            hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 600, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            components = {
                uim.container.Panel(hFigure, BackgroundColor="w")
                uim.decorator.Box(canvas, PositionMode="auto")
                uim.widget.Toolbar(canvas, Location="northwest", BarExtensionMode="expanded")
                uim.widget.RangeSlider(canvas, Min=0, Max=10)
                };
            for k = 1:numel(components)
                component = components{k};
                testCase.addTeardown(@deleteValid, component);
                component.Size = [150, 60];

                component.Margin = [5, 5, 5, 5];

                testCase.verifyEqual(char(component.SizeMode), 'manual', ...
                    class(component) + ": a Margin change keeps SizeMode 'manual'.");
                testCase.verifyEqual(component.Size, [150, 60], ...
                    class(component) + ": a Margin change keeps the manual Size.");
            end
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

            testCase.verifyEqual(canvas.Tag, "My Canvas");
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

        function canvasRegistersAndUnregistersChildren(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);
            canvas = uim.UIComponentCanvas(hPanel);

            toolbar = uim.widget.Toolbar(canvas);
            slider = uim.widget.RangeSlider(canvas);

            testCase.verifyTrue(any(canvas.Children == toolbar));
            testCase.verifyTrue(any(canvas.Children == slider));

            delete(slider)
            testCase.verifyFalse(any(canvas.Children == slider));
            testCase.verifyTrue(any(canvas.Children == toolbar));

            delete(canvas)
            testCase.verifyFalse(isvalid(toolbar));
        end

        function canvasShowsAndHidesTooltip(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(hFigure);

            canvas.showTooltip('Tooltip message', [50, 50]);
            tooltipText = findall(canvas.Axes, "Type", "text", ...
                "String", "Tooltip message");
            testCase.verifyNumElements(tooltipText, 1);
            testCase.verifyEqual(char(tooltipText.Visible), 'on');

            canvas.hideTooltip();
            testCase.verifyEqual(char(tooltipText.Visible), 'off');
            testCase.verifyEmpty(tooltipText.String);
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

        function pointerManagerKeepsMotionTrackingAlive(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure);

            % The manager ensures CurrentPoint tracking (a no-op
            % WindowButtonMotionFcn). Deleting the manager must leave
            % the tracking installed: widgets created while the manager
            % was alive rely on the same mechanism, and would silently
            % stop dragging in java figures if it were removed.
            manager = uim.interface.PointerManager(hFigure, hAxes);
            testCase.verifyNotEmpty(hFigure.WindowButtonMotionFcn);
            delete(manager);
            testCase.verifyNotEmpty(hFigure.WindowButtonMotionFcn);

            % A callback assigned by the host is never clobbered.
            manager = uim.interface.PointerManager(hFigure, hAxes);
            replacementCallback = @(~, ~) [];
            hFigure.WindowButtonMotionFcn = replacementCallback;
            delete(manager);

            testCase.verifyEqual(func2str(hFigure.WindowButtonMotionFcn), ...
                func2str(replacementCallback));
        end

        function pointerManagerLeavesHostButtonDownFcnWithNoToolActive(testCase)
            [hFigure, hAxes] = createPlainAxes(testCase);

            % With no tool active nothing else handles a press on the axes
            % background, so the host's callback stays in place.
            hostCallback = @(~, ~) setappdata(hFigure, "HostPressed", true);
            hAxes.ButtonDownFcn = hostCallback;

            manager = uim.interface.PointerManager(hFigure, hAxes, {'zoomIn'});
            testCase.addTeardown(@deleteValid, manager);

            testCase.verifyEqual(func2str(hAxes.ButtonDownFcn), func2str(hostCallback));
        end

        function pointerManagerHoldsHostButtonDownFcnWhileToolIsActive(testCase)
            [hFigure, hAxes] = createPlainAxes(testCase);
            hostCallback = @(~, ~) setappdata(hFigure, "HostPressed", true);
            hAxes.ButtonDownFcn = hostCallback;
            manager = uim.interface.PointerManager(hFigure, hAxes, {'zoomIn'});
            testCase.addTeardown(@deleteValid, manager);

            % An active tool takes presses through the window listener,
            % so the host's callback is set aside to avoid a second
            % handler for the same click.
            manager.togglePointerMode('zoomIn')
            testCase.verifyEmpty(hAxes.ButtonDownFcn);

            manager.togglePointerMode('zoomIn')
            testCase.verifyEqual(func2str(hAxes.ButtonDownFcn), func2str(hostCallback));
        end

        function pointerManagerKeepsCallbackAssignedWhileToolIsActive(testCase)
            [hFigure, hAxes] = createPlainAxes(testCase);
            hAxes.ButtonDownFcn = @(~, ~) setappdata(hFigure, "HostPressed", true);
            manager = uim.interface.PointerManager(hFigure, hAxes, {'zoomIn'});
            testCase.addTeardown(@deleteValid, manager);

            % A callback the host assigns while a tool is active is newer
            % than the one set aside, so releasing must not overwrite it.
            manager.togglePointerMode('zoomIn')
            replacementCallback = @(~, ~) setappdata(hFigure, "Replaced", true);
            hAxes.ButtonDownFcn = replacementCallback;

            manager.togglePointerMode('zoomIn')
            testCase.verifyEqual(func2str(hAxes.ButtonDownFcn), ...
                func2str(replacementCallback));
        end

        function pointerManagerReleasesHostButtonDownFcnOnDelete(testCase)
            [hFigure, hAxes] = createPlainAxes(testCase);
            hostCallback = @(~, ~) setappdata(hFigure, "HostPressed", true);
            hAxes.ButtonDownFcn = hostCallback;
            manager = uim.interface.PointerManager(hFigure, hAxes, {'zoomIn'});

            manager.togglePointerMode('zoomIn')
            delete(manager)

            testCase.verifyEqual(func2str(hAxes.ButtonDownFcn), func2str(hostCallback));
        end

        function pointerManagerReleasesHostButtonDownFcnWhenToolTurnsOff(testCase)
            [hFigure, hAxes] = createPlainAxes(testCase);
            hostCallback = @(~, ~) setappdata(hFigure, "HostPressed", true);
            hAxes.ButtonDownFcn = hostCallback;
            manager = uim.interface.PointerManager(hFigure, hAxes, {'zoomIn'});
            testCase.addTeardown(@deleteValid, manager);

            % A tool can turn itself off without going through the
            % manager; the host's callback comes back all the same.
            manager.togglePointerMode('zoomIn')
            manager.Pointers.zoomIn.deactivate()

            testCase.verifyEqual(func2str(hAxes.ButtonDownFcn), func2str(hostCallback));
        end

        function pointerManagerHoldsHostButtonDownFcnDuringCrop(testCase)
            testCase.assumeTrue(exist("drawrectangle", "file") > 0, ...
                "Crop needs Image Processing Toolbox ROI objects.");
            [hFigure, hAxes] = createPlainAxes(testCase);
            set(hAxes, "XLim", [0.5, 100.5], "YLim", [0.5, 100.5])
            hostCallback = @(~, ~) setappdata(hFigure, "HostPressed", true);
            hAxes.ButtonDownFcn = hostCallback;
            manager = uim.interface.PointerManager(hFigure, hAxes, {'crop'});
            testCase.addTeardown(@deleteValid, manager);

            % Crop's activate() waits in uiwait until the selection ends,
            % then turns the tool off. A timer stands in for the user: it
            % records the axes callback during the wait and ends it. It
            % repeats, because a resume that arrives before the wait
            % starts has no effect.
            manager.Pointers.crop.CurrentXLim = [11, 30];
            manager.Pointers.crop.CurrentYLim = [21, 60];
            resumeTimer = timer("StartDelay", 0.5, "Period", 0.5, ...
                "ExecutionMode", "fixedSpacing", ...
                "TimerFcn", @(~, ~) recordCallbackAndResume(hFigure, hAxes));
            testCase.addTeardown(@() cleanupTimer(resumeTimer));
            start(resumeTimer)

            manager.togglePointerMode('crop')
            stop(resumeTimer)

            testCase.verifyTrue(getappdata(hFigure, "WasHeldDuringWait"), ...
                "The host's callback is set aside while the crop is in progress.");
            testCase.verifyEqual(func2str(hAxes.ButtonDownFcn), func2str(hostCallback), ...
                "The host's callback is back once the crop has ended.");
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
            hPanel = uipanel(hFigure);

            indicator = uim.widget.ChannelIndicator(hPanel, "NumChannels", 4);

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

        function pointerManagerTogglesToolsOnPlainDataAxes(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "XLim", [0, 100], "YLim", [0, 50]);

            manager = uim.interface.PointerManager(hFigure, hAxes, ...
                {"zoomIn", "pan"});
            testCase.addTeardown(@deleteValid, manager);
            testCase.verifyEqual(fieldnames(manager.Pointers), ...
                {'zoomIn'; 'pan'});

            manager.togglePointerMode('zoomIn');
            testCase.verifySameHandle(manager.CurrentPointerTool, ...
                manager.Pointers.zoomIn);

            manager.togglePointerMode('zoomIn');
            testCase.verifyEmpty(manager.CurrentPointerTool);
        end

        function dataCursorReportsCursorMovement(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", "XLim", [0, 100], "YLim", [0, 50]);
            manager = uim.interface.PointerManager(hFigure, hAxes, {'dataCursor'});
            testCase.addTeardown(@deleteValid, manager);

            % CursorMovedFcn passes the motion event's source through, and
            % fires only while the tool is active and the pointer is inside
            % the axes.
            hDataCursor = manager.Pointers.dataCursor;
            hDataCursor.CursorMovedFcn = @(src, ~) setappdata(hFigure, "MovedSource", src);
            axesPosition = hAxes.Position;
            hFigure.CurrentPoint = axesPosition(1:2) + axesPosition(3:4)/2;

            hDataCursor.onButtonMotion(hFigure, [])
            testCase.verifyFalse(isappdata(hFigure, "MovedSource"), ...
                "An inactive data cursor stays silent.");

            manager.togglePointerMode('dataCursor')
            hDataCursor.onButtonMotion(hFigure, [])
            testCase.verifySameHandle(getappdata(hFigure, "MovedSource"), hFigure);
        end

        function widgetOnPlainPanelCreatesAndSharesImplicitCanvas(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);

            button = uim.control.Button(hPanel, "Text", "Run");
            testCase.verifyTrue(isappdata(hPanel, "UIComponentCanvas"));

            canvas = getappdata(hPanel, "UIComponentCanvas");
            testCase.verifyClass(canvas, "uim.UIComponentCanvas");
            testCase.verifyTrue(any(canvas.Children == button));

            % A second widget on the same panel reuses the same canvas.
            slider = uim.widget.RangeSlider(hPanel, "Min", 0, "Max", 10);
            testCase.verifySameHandle(getappdata(hPanel, "UIComponentCanvas"), canvas);
            testCase.verifyTrue(any(canvas.Children == slider));
        end

        function waitbarRunsInPlainAxes(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure);

            waitbar = uim.widget.Waitbar(hAxes, "Position", [1, 1, 200, 10]);
            testCase.addTeardown(@deleteValid, waitbar);

            waitbar.Status = 0.25;
            barLines = findall(hAxes, "Type", "line");
            testCase.verifyNumElements(barLines, 2);

            barLengths = sort(arrayfun(@(h) max(h.XData) - min(h.XData), barLines));
            testCase.verifyEqual(barLengths(1)/barLengths(2), 0.25, "RelTol", 0.05);

            waitbar.Status = 1;
            barLengths = arrayfun(@(h) max(h.XData) - min(h.XData), barLines);
            testCase.verifyEqual(barLengths(1)/barLengths(2), 1, "RelTol", 0.05);
        end

        function waitbarFollowsAVerticalPositionChange(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [20, 20, 300, 200], "YLim", [0, 1]);
            waitbar = uim.widget.Waitbar(hAxes, "Position", [1, 1, 200, 10]);
            testCase.addTeardown(@deleteValid, waitbar);
            barLines = findall(hAxes, "Type", "line");
            yBefore = barLines(1).YData(1);

            waitbar.Position = [1, 100, 200, 10];

            % 99 px higher in a 200 px axes showing one data unit
            testCase.verifyEqual(barLines(1).YData(1) - yBefore, 99/200, "AbsTol", 1e-9);
        end

        function waitbarCreatedHiddenDrawsAndDeletes(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure);

            waitbar = uim.widget.Waitbar(hAxes, "Visible", "off");
            barLines = findall(hAxes, "Type", "line");
            testCase.verifyNumElements(barLines, 2, "The bars are drawn.");
            testCase.verifyEqual(string({barLines.Visible}), ["off", "off"]);

            waitbar.Visible = "on";
            testCase.verifyEqual(string({barLines.Visible}), ["on", "on"]);

            testCase.verifyWarningFree(@() delete(waitbar));
            testCase.verifyEmpty(findall(hAxes, "Type", "line"), "delete removes the bars.");
        end

        function frameMarkerTracksValueInPlainAxes(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "XLim", [0, 100], "YLim", [0, 1]);

            marker = uim.widget.FrameMarker(hAxes, ...
                "Minimum", 1, "Maximum", 100);

            marker.Value = 42;
            markerHandles = findall(hAxes, "Tag", "FrameMarker");
            testCase.verifyNumElements(markerHandles, 3);
            for i = 1:numel(markerHandles)
                testCase.verifyEqual(unique(markerHandles(i).XData), 42);
            end

            % The marker lives in the caller's axes, so interactive data
            % tips are excluded per object (the DataCursor behavior is
            % the gate the interactive machinery consults; programmatic
            % datatip() bypasses it by design and is not the oracle).
            for i = 1:numel(markerHandles)
                hBehavior = hggetbehavior(markerHandles(i), ...
                    'DataCursor', '-peek');
                testCase.verifyFalse(isempty(hBehavior) ...
                    || logical(hBehavior.Enable));
            end

            % Hover styling must match the primitive-line knobs (a
            % chart-line-only class check silently broke this once).
            knob = findall(hAxes, "Tag", "FrameMarker", "Marker", "v");
            marker.onMouseEnterSlider(knob)
            testCase.verifyEqual(knob.MarkerSize, 12);
            marker.onMouseExitSlider(knob)
            testCase.verifyEqual(knob.MarkerSize, 10);
        end

        function planeSwitcherRunsStandaloneInPanel(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);

            switcher = uim.widget.PlaneSwitcher(hPanel, "NumPlanes", 5, ...
                "CurrentPlane", 2);
            testCase.addTeardown(@deleteValid, switcher);

            toggleButton = findall(hPanel, "Tag", "PlaneSwitcherToggleButton");
            testCase.verifyNumElements(toggleButton, 1);
            testCase.verifyEqual(switcher.CurrentPlane, 2);

            switcher.CurrentPlane = 4;
            testCase.verifyEqual(switcher.CurrentPlane, 4);
        end

        function playbackControlRunsStandaloneInPanel(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);

            control = uim.widget.PlaybackControl(hPanel, ...
                "Minimum", 1, "Maximum", 100, ...
                "NumChannels", 3, "NumPlanes", 2, ...
                "PlaybackSpeed", 2, "CurrentChannels", [2, 3], ...
                "CurrentPlane", 2);
            testCase.addTeardown(@deleteValid, control);

            % Constructor-supplied state reaches the lazily created
            % sub-widgets and the speed label.
            testCase.verifyEqual(control.CurrentChannels, [2, 3]);
            testCase.verifyEqual(control.CurrentPlane, 2);
            testCase.verifyNumElements(...
                findall(hPanel, "Type", "text", "String", "2x"), 1);

            % Sub-widgets are created and wired without a parent app.
            testCase.verifyEqual(...
                numel(findall(hPanel, "Tag", "ChannelIndicator")), 3);
            testCase.verifyNumElements(...
                findall(hPanel, "Tag", "PlaneSwitcherToggleButton"), 1);

            % The host pushes state in through properties.
            control.Value = 42;
            testCase.verifyEqual(control.Value, 42);

            control.PlaybackSpeed = 4;
            speedLabel = findall(hPanel, "Type", "text", "String", "4x");
            testCase.verifyNumElements(speedLabel, 1);

            control.CurrentChannels = [1, 3];
            testCase.verifyEqual(control.CurrentChannels, [1, 3]);
        end

        function messageBoxDisplaysInPlainPanel(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);

            messageBox = uim.widget.MessageBox(hPanel);
            testCase.addTeardown(@deleteValid, messageBox);

            messageBox.displayMessage('Hello standalone world')
            testCase.verifyTrue(messageBox.isMessageDisplaying());

            messageBox.clearMessage()
            testCase.verifyFalse(messageBox.isMessageDisplaying());
        end

        function toolbarAnchorsInsideDataAxes(testCase)
            hFigure = figure("Visible", "off", "Position", [200, 200, 560, 420]);
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [60, 50, 400, 300]);
            plot(hAxes, 1:10, (1:10).^2)
            originalXLim = hAxes.XLim;
            originalYLim = hAxes.YLim;

            toolbar = uim.widget.Toolbar(hAxes, "Location", "northeast");

            canvas = getappdata(hAxes, "UIComponentCanvas");
            testCase.verifyClass(canvas, "uim.UIComponentCanvas");
            testCase.verifySameHandle(canvas.TargetAxes, hAxes);
            testCase.verifySameHandle(toolbar.Canvas, canvas);

            expectedRect = getpixelposition(hAxes);
            testCase.verifyEqual(canvas.Axes.Position, expectedRect, "AbsTol", 1);
            testCase.verifyEqual(canvas.Size, expectedRect(3:4), "AbsTol", 1);

            % Data limits of the target axes are untouched by the overlay.
            testCase.verifyEqual(hAxes.XLim, originalXLim);
            testCase.verifyEqual(hAxes.YLim, originalYLim);

            % The toolbar sits in the upper-right quadrant of the axes
            % rect (positions are canvas-local, i.e. relative to the rect).
            toolbarPosition = toolbar.Position;
            testCase.verifyGreaterThan(toolbarPosition(1), expectedRect(3)/2);
            testCase.verifyGreaterThan(toolbarPosition(2), expectedRect(4)/2);
            testCase.verifyLessThanOrEqual(...
                toolbarPosition(1) + toolbarPosition(3), expectedRect(3) + 1);

            % The getpixelposition wrapper resolves the canvas parent to
            % a real pixel frame instead of erroring on the canvas object.
            toolbarPixelPosition = toolbar.getpixelposition();
            testCase.verifyEqual(toolbarPixelPosition(1:2), ...
                expectedRect(1:2) + toolbarPosition(1:2), "AbsTol", 1);
        end

        function overlayCanvasTracksTargetAxesPosition(testCase)
            hFigure = figure("Visible", "off", "Position", [200, 200, 700, 500]);
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [50, 40, 300, 200]);

            toolbar = uim.widget.Toolbar(hAxes, "Location", "northeast");
            canvas = uim.UIComponentCanvas.getOrCreate(hAxes);
            toolbarLocalPosition = toolbar.Position;

            % Pure move: the overlay origin follows while its size and the
            % canvas-local component position stay put.
            hAxes.Position(1:2) = [180, 150];
            drawnow
            expectedRect = getpixelposition(hAxes);
            testCase.verifyEqual(canvas.Axes.Position, expectedRect, "AbsTol", 1);
            testCase.verifyEqual(canvas.Size, expectedRect(3:4), "AbsTol", 1);
            testCase.verifyEqual(toolbar.Position, toolbarLocalPosition, "AbsTol", 1);

            % Resize: the overlay size follows and the northeast anchor
            % recomputes (toolbar shifts right with the wider rect).
            hAxes.Position(3:4) = [420, 260];
            drawnow
            expectedRect = getpixelposition(hAxes);
            testCase.verifyEqual(canvas.Axes.Position, expectedRect, "AbsTol", 1);
            testCase.verifyGreaterThan(toolbar.Position(1), toolbarLocalPosition(1));
        end

        function overlayCanvasesCoexistWithContainerCanvas(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxesOne = axes(hFigure, "Units", "pixels", "Position", [40, 40, 200, 150]);
            hAxesTwo = axes(hFigure, "Units", "pixels", "Position", [280, 40, 200, 150]);

            figureCanvas = uim.UIComponentCanvas.getOrCreate(hFigure);
            overlayOne = uim.UIComponentCanvas.getOrCreate(hAxesOne);
            overlayTwo = uim.UIComponentCanvas.getOrCreate(hAxesTwo);

            testCase.verifyNotSameHandle(overlayOne, figureCanvas);
            testCase.verifyNotSameHandle(overlayTwo, figureCanvas);
            testCase.verifyNotSameHandle(overlayOne, overlayTwo);
            testCase.verifySameHandle(...
                uim.UIComponentCanvas.getOrCreate(hAxesOne), overlayOne);

            testCase.verifyError(@() uim.UIComponentCanvas(hAxesOne), ...
                "uim:UIComponentCanvas:DuplicateCanvas");

            % Canvases created later stack on top (registration order).
            stacked = allchild(hFigure);
            testCase.verifyLessThan(find(stacked == overlayTwo.Axes), ...
                find(stacked == overlayOne.Axes));
            testCase.verifyLessThan(find(stacked == overlayOne.Axes), ...
                find(stacked == figureCanvas.Axes));

            % Non-LIFO teardown: deleting the first-installed canvas must
            % not corrupt the shared axes-creation hook for the remaining
            % canvases (registry regression).
            delete(figureCanvas)
            siblingAxes = axes(hFigure);
            testCase.verifyTrue(isvalid(siblingAxes));
            testCase.verifyTrue(isvalid(overlayOne) && isvalid(overlayTwo));

            stacked = allchild(hFigure);
            testCase.verifyLessThan(find(stacked == overlayTwo.Axes), ...
                find(stacked == overlayOne.Axes));
            testCase.verifyLessThan(find(stacked == overlayOne.Axes), ...
                find(stacked == siblingAxes));
        end

        function deletingTargetAxesDeletesOverlayAndComponents(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [50, 50, 300, 220]);
            originalCallback = get(hFigure, "DefaultAxesCreateFcn");

            toolbar = uim.widget.Toolbar(hAxes, "Location", "northeast");
            slider = uim.widget.RangeSlider(hAxes);
            canvas = uim.UIComponentCanvas.getOrCreate(hAxes);
            canvasAxes = canvas.Axes;

            delete(hAxes)

            testCase.verifyFalse(isvalid(canvas));
            testCase.verifyFalse(isvalid(toolbar));
            testCase.verifyFalse(isvalid(slider));
            testCase.verifyFalse(isvalid(canvasAxes));
            testCase.verifyTrue(isvalid(hFigure));
            testCase.verifyEqual(get(hFigure, "DefaultAxesCreateFcn"), ...
                originalCallback);
            testCase.verifyFalse(...
                isappdata(hFigure, "UIComponentCanvasSiblingHook"));
        end

        function overlayCanvasRejectsReparentAndPrivateMode(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [50, 50, 300, 220]);
            hPanel = uipanel(hFigure);

            canvas = uim.UIComponentCanvas.getOrCreate(hAxes);
            testCase.verifyError(@() canvas.reparent(hPanel), ...
                "uim:UIComponentCanvas:OverlayReparentNotSupported");

            testCase.verifyError(...
                @() uim.widget.Toolbar(hAxes, "CanvasMode", "private"), ...
                "uim:Container:PrivateCanvasUnsupportedOnOverlay");

            % A Panel wraps a real uipanel, which can not live on a canvas.
            testCase.verifyError(@() uim.container.Panel(hAxes), ...
                "uim:Panel:CanvasParentNotSupported");

            % Axes inside a tiled layout can not host a sibling overlay.
            tiledFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, tiledFigure);
            hLayout = tiledlayout(tiledFigure, 1, 1);
            hTiledAxes = nexttile(hLayout);
            testCase.verifyError(@() uim.UIComponentCanvas(hTiledAxes), ...
                "uim:UIComponentCanvas:UnsupportedAxesParent");
        end

        function readoutDisplaysFormattedValue(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            readout = uim.widget.Readout(canvas, ...
                'Label', 'Frame', 'Format', '%d');
            readout.Value = 42;
            testCase.verifyEqual(readout.String, 'Frame: 42');
            testCase.verifyNumElements(findall(canvas.Axes, ...
                "Type", "text", "String", "Frame: 42"), 1);

            % Without a label, only the formatted value is shown.
            plain = uim.widget.Readout(canvas, ...
                'Format', '%.2f', 'Location', 'northeast');
            plain.Value = pi;
            testCase.verifyEqual(plain.String, '3.14');

            delete(readout)
            testCase.verifyEmpty(findall(canvas.Axes, ...
                "Type", "text", "String", "Frame: 42"));
        end

        function spinnerStepsClampsAndEdits(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);
            canvas = uim.UIComponentCanvas(hPanel);

            spinner = uim.widget.Spinner(canvas, ...
                'Value', 5, 'Minimum', 0, 'Maximum', 6, 'Step', 2, ...
                'ValueChangedFcn', ...
                @(~, evt) setappdata(hFigure, 'LastEvent', evt));

            incrementFcn = get(findall(canvas.Axes, ...
                "Tag", "SpinnerIncrement"), 'ButtonDownFcn');
            decrementFcn = get(findall(canvas.Axes, ...
                "Tag", "SpinnerDecrement"), 'ButtonDownFcn');

            % Stepping clamps to Maximum and notifies with old/new values.
            incrementFcn([], [])
            testCase.verifyEqual(spinner.Value, 6);
            evt = getappdata(hFigure, 'LastEvent');
            testCase.verifyEqual(evt.OldValue, 5);
            testCase.verifyEqual(evt.NewValue, 6);

            % A step that does not change the value fires no callback.
            setappdata(hFigure, 'LastEvent', [])
            incrementFcn([], [])
            testCase.verifyEmpty(getappdata(hFigure, 'LastEvent'));

            decrementFcn([], [])
            testCase.verifyEqual(spinner.Value, 4);

            % Programmatic assignment updates silently (push model).
            setappdata(hFigure, 'LastEvent', [])
            spinner.Value = 1;
            testCase.verifyEmpty(getappdata(hFigure, 'LastEvent'));

            % Clicking the value opens an edit box; committing applies
            % the typed value through the user pathway.
            editFcn = get(findall(canvas.Axes, ...
                "Tag", "SpinnerValue"), 'ButtonDownFcn');
            editFcn([], [])
            editBox = findall(hFigure, "Type", "uicontrol", "Style", "edit");
            testCase.verifyNumElements(editBox, 1);

            editBox.String = '3';
            editBox.Callback(editBox, [])
            testCase.verifyEqual(spinner.Value, 3);
            testCase.verifyFalse(isvalid(editBox));
            evt = getappdata(hFigure, 'LastEvent');
            testCase.verifyEqual(evt.NewValue, 3);
        end

        function dropDownOpensWithNoSelection(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));
            dropdown = uim.widget.DropDown(canvas, 'Items', ["a", "b"], 'Value', "b");

            dropdown.open()
            selectedRows = findall(canvas.Axes, "Type", "patch", "FaceAlpha", 0.15);
            testCase.verifyNumElements(selectedRows, 1, "The selected row is marked.");
            dropdown.close()

            % "" is a valid state until Items is next assigned: the list
            % opens with no row marked as selected, and closes cleanly.
            dropdown.Value = "";
            testCase.verifyEmpty(dropdown.ValueIndex);
            dropdown.open()
            testCase.verifyTrue(dropdown.IsOpen);
            selectedRows = findall(canvas.Axes, "Type", "patch", "FaceAlpha", 0.15);
            testCase.verifyEmpty(selectedRows, "No row is marked as selected.");
            dropdown.close()
            testCase.verifyFalse(dropdown.IsOpen);
        end

        function dropDownSelectsItemAndNotifies(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            dropdown = uim.widget.DropDown(canvas, ...
                'Items', ["gray", "jet", "parula"], 'Value', "jet", ...
                'ValueChangedFcn', ...
                @(~, evt) setappdata(hFigure, 'LastEvent', evt));

            testCase.verifyEqual(dropdown.Value, "jet");
            testCase.verifyEqual(dropdown.ValueIndex, 2);
            testCase.verifyFalse(dropdown.IsOpen);

            dropdown.open()
            testCase.verifyTrue(dropdown.IsOpen);
            rows = findall(canvas.Axes, "Tag", "DropDownItem");
            testCase.verifyNumElements(rows, 3);

            % Clicking an item selects it, closes the list and notifies.
            thirdRow = rows([rows.UserData] == 3);
            thirdRow.ButtonDownFcn([], [])
            testCase.verifyEqual(dropdown.Value, "parula");
            testCase.verifyFalse(dropdown.IsOpen);
            testCase.verifyEmpty(findall(canvas.Axes, "Tag", "DropDownItem"));
            evt = getappdata(hFigure, 'LastEvent');
            testCase.verifyEqual(evt.OldValue, "jet");
            testCase.verifyEqual(evt.NewValue, "parula");

            % Selecting the current item closes without notifying.
            setappdata(hFigure, 'LastEvent', [])
            dropdown.open()
            rows = findall(canvas.Axes, "Tag", "DropDownItem");
            currentRow = rows([rows.UserData] == dropdown.ValueIndex);
            currentRow.ButtonDownFcn([], [])
            testCase.verifyFalse(dropdown.IsOpen);
            testCase.verifyEmpty(getappdata(hFigure, 'LastEvent'));

            % Programmatic assignment updates silently; invalid values
            % are rejected.
            dropdown.Value = "gray";
            testCase.verifyEmpty(getappdata(hFigure, 'LastEvent'));
            testCase.verifyError(...
                @() assignProperty(dropdown, 'Value', "bogus"), ...
                "uim:DropDown:InvalidValue");

            delete(dropdown)
            testCase.verifyEmpty(findall(canvas.Axes, "Type", "text", ...
                "String", "gray"));
        end

        function dropDownAppliesListColors(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            dropdown = uim.widget.DropDown(canvas, ...
                'Items', ["a", "b"], 'Value', "b", ...
                'ListBackgroundColor', [0.1, 0.2, 0.3], ...
                'ListBorderColor', [1, 0, 0], ...
                'SelectionColor', [0, 0, 1]);

            dropdown.open()

            listBackground = findall(canvas.Axes, "Type", "patch", ...
                "FaceColor", [0.1, 0.2, 0.3]);
            testCase.verifyNumElements(listBackground, 1);
            testCase.verifyEqual(listBackground.EdgeColor, [1, 0, 0]);

            rows = findall(canvas.Axes, "Tag", "DropDownItem");
            selectedRow = rows([rows.UserData] == dropdown.ValueIndex);
            testCase.verifyEqual(selectedRow.FaceColor, [0, 0, 1]);
            testCase.verifyEqual(selectedRow.FaceAlpha, 0.15);
        end

        function pointerToolbarBindingSyncsButtonsAndTools(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", ...
                "Position", [50, 50, 300, 220]);
            imagesc(hAxes, magic(50))

            manager = uim.interface.PointerManager(hFigure, hAxes, ...
                {'zoomIn', 'pan'});
            testCase.addTeardown(@deleteValid, manager);

            toolbar = uim.widget.Toolbar(hAxes, "Location", "northeast");
            binding = uim.interface.PointerToolBinding(toolbar, manager, ...
                ["zoomIn", "pan"]);

            testCase.verifyNumElements(binding.Buttons, 2);
            zoomButton = binding.Buttons(1);
            panButton = binding.Buttons(2);

            % Modes with a shipped default icon render it (not a text label).
            testCase.verifyClass(zoomButton.Icon, "struct");
            testCase.verifyEmpty(zoomButton.Text);

            % Button -> tool: clicking the button activates the tool,
            % and the tool's toggle event flips the button state.
            zoomButton.Callback([], [])
            testCase.verifySameHandle(...
                manager.CurrentPointerTool, manager.Pointers.zoomIn);
            testCase.verifyTrue(logical(zoomButton.Value));

            % Tool -> buttons: switching mode by other means updates
            % both button states.
            manager.togglePointerMode('pan')
            testCase.verifySameHandle(...
                manager.CurrentPointerTool, manager.Pointers.pan);
            testCase.verifyFalse(logical(zoomButton.Value));
            testCase.verifyTrue(logical(panButton.Value));

            % Modes the manager does not know are rejected clearly.
            testCase.verifyError(@() uim.interface.PointerToolBinding(...
                toolbar, manager, "crop"), ...
                "uim:PointerToolBinding:UnknownMode");

            % Deleting the binding removes the buttons it created.
            delete(binding)
            testCase.verifyFalse(isvalid(zoomButton));
            testCase.verifyFalse(isvalid(panButton));
        end

        function overviewIndicatorMapsAndNotifies(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            indicator = uim.widget.OverviewIndicator(canvas, ...
                'DataLimits', [0, 200; 0, 100], ...
                'ViewLimits', [50, 100; 25, 50], ...
                'YDir', 'reverse', ...
                'ViewChangedFcn', ...
                @(~, evt) setappdata(hFigure, 'LastEvent', evt));

            % The frame preserves the data aspect ratio (2:1) and the
            % view rect spans a quarter of the frame width.
            frame = findall(canvas.Axes, "Tag", "OverviewFrame");
            viewRect = findall(canvas.Axes, "Tag", "OverviewViewRect");
            frameWidth = max(frame.XData) - min(frame.XData);
            frameHeight = max(frame.YData) - min(frame.YData);
            testCase.verifyEqual(frameWidth/frameHeight, 2, "AbsTol", 1e-10);
            viewWidth = max(viewRect.XData) - min(viewRect.XData);
            testCase.verifyEqual(viewWidth, frameWidth/4, "AbsTol", 1e-10);

            % Programmatic push updates silently.
            setappdata(hFigure, 'LastEvent', [])
            indicator.ViewLimits = [0, 100; 0, 50];
            testCase.verifyEmpty(getappdata(hFigure, 'LastEvent'));

            % centerViewOn keeps the view size, clamps to the data
            % extent and notifies with the applied limits.
            indicator.centerViewOn(190, 90) % Near the corner -> clamped
            evt = getappdata(hFigure, 'LastEvent');
            testCase.verifyEqual(evt.XLim, [100, 200], "AbsTol", 1e-10);
            testCase.verifyEqual(evt.YLim, [50, 100], "AbsTol", 1e-10);
            testCase.verifyEqual(indicator.ViewLimits, [100, 200; 50, 100], ...
                "AbsTol", 1e-10);
        end

        function contrastSliderPushesAndNotifies(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            slider = uim.widget.ContrastSlider(canvas, ...
                'DataLimits', [0, 255], 'Limits', [10, 200], ...
                'LimitsChangedFcn', ...
                @(~, evt) setappdata(hFigure, 'LimitsEvent', evt), ...
                'AutoRequestedFcn', ...
                @(~, evt) setappdata(hFigure, 'AutoEvent', evt));

            % Knob drags read CurrentPoint from motion listeners, which
            % only tracks the mouse in java figures when the figure has
            % a WindowButtonMotionFcn; construction must ensure one.
            testCase.verifyNotEmpty(hFigure.WindowButtonMotionFcn);

            % Contrast-semantics properties map onto the range slider.
            testCase.verifyEqual(slider.DataLimits, [0, 255]);
            testCase.verifyEqual(slider.Limits, [10, 200]);
            testCase.verifyEqual([slider.Min, slider.Max], [0, 255]);
            testCase.verifyEqual([slider.Low, slider.High], [10, 200]);

            % Programmatic push updates silently.
            slider.Limits = [0, 128];
            testCase.verifyEmpty(getappdata(hFigure, 'LimitsEvent'));

            % A user interaction (knob drags flow through the value
            % setters) notifies with old/new limit pairs.
            slider.Low = 20;
            evt = getappdata(hFigure, 'LimitsEvent');
            testCase.verifyEqual(evt.OldValue, [0, 128]);
            testCase.verifyEqual(evt.NewValue, [20, 128]);

            % The public Callback stays available to hosts (the widget
            % does not occupy it for its own plumbing) and fires
            % alongside LimitsChangedFcn.
            slider.Callback = @(~, evt) setappdata(hFigure, 'RawEvent', evt);
            slider.High = 220;
            evt = getappdata(hFigure, 'LimitsEvent');
            testCase.verifyEqual(evt.NewValue, [20, 220]);
            rawEvt = getappdata(hFigure, 'RawEvent');
            testCase.verifyEqual([rawEvt.Low, rawEvt.High], [20, 220]);

            % A collapsed range is clamped to strictly increasing limits
            % before notification, and the corrected interval is applied
            % back to the slider, so hosts can assign NewValue to CLim
            % and the widget state matches what was reported.
            slider.High = 20; % Drag the high knob down onto the low knob
            evt = getappdata(hFigure, 'LimitsEvent');
            testCase.verifyGreaterThan(evt.NewValue(2), evt.NewValue(1));
            testCase.verifyEqual(evt.NewValue(1), 20);
            testCase.verifyEqual(slider.Limits, evt.NewValue);

            % The auto button requests auto levels from the host.
            autoButton = findall(canvas.Axes, ...
                "Tag", "ContrastSliderAutoButton");
            testCase.verifyNumElements(autoButton, 1);
            autoButton.ButtonDownFcn([], [])
            testCase.verifyClass(getappdata(hFigure, 'AutoEvent'), ...
                "uim.event.EventData");

            % Pushed histogram counts render inside the track x-range;
            % clearing them hides the histogram again.
            histogram = findall(canvas.Axes, ...
                "Tag", "ContrastSliderHistogram");
            testCase.verifyNumElements(histogram, 1);
            slider.HistogramCounts = [1, 4, 9, 4, 1];
            trackLeft = slider.Position(1) + slider.Padding(1);
            trackRight = slider.Position(1) + slider.Position(3) ...
                - slider.Padding(3);
            testCase.verifyGreaterThanOrEqual(min(histogram.XData), ...
                trackLeft - 1e-6);
            testCase.verifyLessThanOrEqual(max(histogram.XData), ...
                trackRight + 1e-6);
            testCase.verifyEqual(max(histogram.YData) - min(histogram.YData), ...
                slider.Position(4) - slider.Padding(2) - slider.Padding(4), ...
                "AbsTol", 1e-6);

            slider.HistogramCounts = [];
            testCase.verifyTrue(all(isnan(histogram.XData)));

            % The histogram button toggles visibility: off silently, on
            % with a request so the host can compute counts lazily.
            slider.HistogramCounts = [1, 2, 3];
            histogramButton = findall(canvas.Axes, ...
                "Tag", "ContrastSliderHistogramButton");
            testCase.verifyNumElements(histogramButton, 1);

            setappdata(hFigure, 'HistEvent', [])
            histogramButton.ButtonDownFcn([], [])
            testCase.verifyEqual(slider.HistogramVisible, 'off');
            testCase.verifyEqual(char(histogram.Visible), 'off');
            testCase.verifyEmpty(getappdata(hFigure, 'HistEvent'));

            slider.HistogramRequestedFcn = ...
                @(~, evt) setappdata(hFigure, 'HistEvent', evt);
            histogramButton.ButtonDownFcn([], [])
            testCase.verifyEqual(slider.HistogramVisible, 'on');
            testCase.verifyEqual(char(histogram.Visible), 'on');
            testCase.verifyClass(getappdata(hFigure, 'HistEvent'), ...
                "uim.event.EventData");
        end

        function contrastSliderAcceptsDisjointRangePushes(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            slider = uim.widget.ContrastSlider(canvas, ...
                'DataLimits', [0, 255], 'Limits', [0, 5]);

            % A pushed range lying entirely above the current one must
            % not trip the ordering asserts of the underlying setters.
            slider.Limits = [100, 130];
            testCase.verifyEqual(slider.Limits, [100, 130]);

            slider.DataLimits = [300, 500];
            testCase.verifyEqual(slider.DataLimits, [300, 500]);
            % Limits outside the new data range are reset to the full range.
            testCase.verifyEqual(slider.Limits, [300, 500]);

            slider.Limits = [320, 480];
            testCase.verifyEqual(slider.Limits, [320, 480]);

            % And back down again.
            slider.DataLimits = [0, 255];
            testCase.verifyEqual(slider.DataLimits, [0, 255]);
            slider.Limits = [10, 200];
            testCase.verifyEqual(slider.Limits, [10, 200]);
        end

        function contrastSliderCallbackMatchesClampedLimitsChangedFcn(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            slider = uim.widget.ContrastSlider(canvas, ...
                'DataLimits', [0, 255], 'Limits', [10, 200], ...
                'LimitsChangedFcn', ...
                @(~, evt) setappdata(hFigure, 'LimitsEvent', evt));

            setappdata(hFigure, 'RawEvents', {})
            slider.Callback = @(~, evt) setappdata(hFigure, 'RawEvents', ...
                [getappdata(hFigure, 'RawEvents'), {evt}]);

            % A collapsing drag must notify Callback exactly once, with
            % the same clamped, strictly-increasing pair reported to
            % LimitsChangedFcn — not the raw pre-clamp value, and not a
            % second time from the internal correction push-back.
            slider.High = 10; % Drag the high knob down onto the low knob
            limitsEvt = getappdata(hFigure, 'LimitsEvent');
            rawEvents = getappdata(hFigure, 'RawEvents');
            testCase.verifyNumElements(rawEvents, 1);
            testCase.verifyEqual([rawEvents{1}.Low, rawEvents{1}.High], ...
                limitsEvt.NewValue);
            testCase.verifyGreaterThan(rawEvents{1}.High, rawEvents{1}.Low);

            % Programmatic pushes stay silent on the Callback channel
            % too, matching the documented push/notify contract.
            setappdata(hFigure, 'RawEvents', {})
            slider.Limits = [50, 150];
            testCase.verifyEmpty(getappdata(hFigure, 'RawEvents'));
        end

        function contrastSliderHoldsKnobPushedAgainstTheOther(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));
            setappdata(hFigure, "NotifyCount", 0)
            slider = uim.widget.ContrastSlider(canvas, ...
                'DataLimits', [0, 255], 'Limits', [10, 100], ...
                'LimitsChangedFcn', @(~, ~) setappdata(hFigure, "NotifyCount", ...
                    getappdata(hFigure, "NotifyCount") + 1));

            % Pushing the low knob onto the high knob separates the pair
            % by moving the low knob back; the high knob stays put.
            slider.Low = slider.High;
            pushedLimits = slider.Limits;
            testCase.verifyEqual(pushedLimits(2), 100);
            testCase.verifyLessThan(pushedLimits(1), 100);
            testCase.verifyEqual(getappdata(hFigure, "NotifyCount"), 1);

            % Holding the knob there (one push per motion event) neither
            % moves the range nor notifies again.
            for iPush = 1:20
                slider.Low = slider.High;
            end
            testCase.verifyEqual(slider.Limits, pushedLimits);
            testCase.verifyEqual(getappdata(hFigure, "NotifyCount"), 1);
        end

        function overviewIndicatorRecoversSizeAfterAspectChanges(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            indicator = uim.widget.OverviewIndicator(canvas, ...
                'DataLimits', [0, 200; 0, 100], ...
                'ViewLimits', [0, 200; 0, 100]);

            % The box hugs the letterboxed frame: 2:1 data inside the
            % default 120x90 box (padding 6) gives a 120x66 chip.
            landscapeSize = indicator.Size;
            testCase.verifyEqual(landscapeSize, [120, 66], "AbsTol", 1);

            % The configured size stays the fitting maximum, so an
            % aspect flip must not ratchet the box smaller and smaller.
            indicator.DataLimits = [0, 100; 0, 200];
            testCase.verifyEqual(indicator.Size, [51, 90], "AbsTol", 1);

            indicator.DataLimits = [0, 200; 0, 100];
            testCase.verifyEqual(indicator.Size, landscapeSize, "AbsTol", 1);

            % A host-assigned size becomes the new fitting maximum.
            indicator.Size = [140, 90];
            testCase.verifyEqual(indicator.Size(1), 140, "AbsTol", 1);
        end

        function dropDownRejectsItemsUpdateAtomically(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            dropdown = uim.widget.DropDown(canvas, ...
                'Items', ["gray", "jet"], 'Value', "jet");

            % An Items list without the current Value is rejected before
            % anything is assigned, so the widget stays consistent and
            % usable for hosts that catch the error.
            testCase.verifyError(...
                @() assignProperty(dropdown, 'Items', ["a", "b"]), ...
                "uim:DropDown:InvalidValue");
            testCase.verifyEqual(dropdown.Items, ["gray", "jet"]);
            testCase.verifyEqual(dropdown.Value, "jet");

            dropdown.open()
            testCase.verifyNumElements(...
                findall(canvas.Axes, "Tag", "DropDownItem"), 2);
            dropdown.close()

            % A compatible update goes through; an unset Value defaults
            % to the first item.
            dropdown.Items = ["hot", "jet"];
            testCase.verifyEqual(dropdown.Value, "jet");

            plain = uim.widget.DropDown(canvas, ...
                'Items', ["x", "y"], 'Location', 'northeast');
            testCase.verifyEqual(plain.Value, "x");
        end

        function dropDownSwitchesToDisjointItemsViaValueReset(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            dropdown = uim.widget.DropDown(canvas, ...
                'Items', ["gray", "jet"], 'Value', "jet");

            % Neither assignment order works directly for a disjoint
            % Items list (both are members-of-the-other-list checks);
            % resetting Value to "" first is the escape hatch, and
            % Items then defaults Value to the new first item.
            testCase.verifyError(...
                @() assignProperty(dropdown, 'Value', "hot"), ...
                "uim:DropDown:InvalidValue");

            dropdown.Value = "";
            dropdown.Items = ["hot", "cool"];
            testCase.verifyEqual(dropdown.Items, ["hot", "cool"]);
            testCase.verifyEqual(dropdown.Value, "hot");
        end

        function spinnerHideDiscardsOpenEdit(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            canvas = uim.UIComponentCanvas(uipanel(hFigure));

            spinner = uim.widget.Spinner(canvas, 'Value', 5);

            editFcn = get(findall(canvas.Axes, ...
                "Tag", "SpinnerValue"), 'ButtonDownFcn');
            editFcn([], [])
            editBox = findall(hFigure, "Type", "uicontrol", "Style", "edit");
            testCase.verifyNumElements(editBox, 1);
            editBox.String = '9'; % Typed but not committed

            % Hiding the spinner must dismiss the native edit box (it is
            % not a canvas child) and discard the uncommitted value.
            spinner.Visible = 'off';
            testCase.verifyFalse(isvalid(editBox));
            testCase.verifyEqual(spinner.Value, 5);

            % A fresh edit session works after showing the spinner again.
            spinner.Visible = 'on';
            editFcn([], [])
            editBox = findall(hFigure, "Type", "uicontrol", "Style", "edit");
            testCase.verifyNumElements(editBox, 1);
            editBox.String = '7';
            editBox.Callback(editBox, [])
            testCase.verifyEqual(spinner.Value, 7);
        end

        function toolbarStaysConsistentAfterBindingDelete(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", ...
                "Position", [50, 50, 300, 220]);

            manager = uim.interface.PointerManager(hFigure, hAxes, ...
                {'zoomIn', 'pan'});
            testCase.addTeardown(@deleteValid, manager);

            toolbar = uim.widget.Toolbar(hAxes, "Location", "northeast");
            binding = uim.interface.PointerToolBinding(toolbar, manager, ...
                ["zoomIn", "pan"]);
            testCase.verifyEqual(toolbar.NumButtons, 2);

            % Deleting the binding removes its buttons through the
            % toolbar, so the toolbar's bookkeeping stays consistent
            % and later operations work on valid handles.
            delete(binding)
            testCase.verifyEqual(toolbar.NumButtons, 0);

            hButton = toolbar.addButton("Text", "x");
            testCase.verifyEqual(toolbar.NumButtons, 1);
            testCase.verifyTrue(isvalid(hButton));

            toolbar.removeButton(hButton)
            testCase.verifyEqual(toolbar.NumButtons, 0);
            testCase.verifyFalse(isvalid(hButton));
        end

        function explicitSizeSurvivesParentResize(testCase)
            hFigure = figure("Visible", "off", "Position", [200, 200, 500, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);
            canvas = uim.UIComponentCanvas(hPanel);

            slider = uim.widget.RangeSlider(canvas);
            slider.Size = [123, 17];
            testCase.verifyEqual(slider.Size, [123, 17]);

            % An explicit size assignment opts out of auto-layout, so it
            % must survive a parent resize instead of being recomputed.
            hFigure.Position(3:4) = [350, 300];
            drawnow
            testCase.verifyEqual(slider.Size, [123, 17]);
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

function assignProperty(object, propertyName, value)
%assignProperty Assign a property inside a function call, so property-set
%errors can be verified with verifyError.
    object.(propertyName) = value;
end

function [hFigure, hAxes] = createPlainAxes(testCase)
%createPlainAxes Hidden figure with one data axes, deleted on teardown
    hFigure = figure("Visible", "off");
    testCase.addTeardown(@deleteValid, hFigure);
    hAxes = axes(hFigure, "XLim", [0, 100], "YLim", [0, 50]);
end

function recordCallbackAndResume(hFigure, hAxes)
%recordCallbackAndResume Note whether the axes callback is held, then end the wait
    setappdata(hFigure, "WasHeldDuringWait", isempty(hAxes.ButtonDownFcn))
    uiresume(hFigure)
end

function cleanupTimer(resumeTimer)
    if isvalid(resumeTimer)
        stop(resumeTimer)
        delete(resumeTimer)
    end
end
