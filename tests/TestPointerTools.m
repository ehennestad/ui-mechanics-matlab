classdef TestPointerTools < matlab.unittest.TestCase
%TestPointerTools Headless behaviour of the pointer tools and the PointerManager
%
%   Tools are driven through their public press/motion/release methods
%   and property pushes. In a hidden figure the pointer position is
%   fixed, so tests rely on explicit points and on limit arithmetic.

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % PointerTool base behaviour

        function toolNotifiesOnActivationChanges(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.Pan(hAxes);
            toggleListener = listener(tool, "ToggledPointerTool", ...
                @(~, evt) setappdata(hFigure, "Toggled", evt.Value));
            testCase.addTeardown(@delete, toggleListener);

            tool.activate()
            testCase.verifyTrue(logical(getappdata(hFigure, "Toggled")));
            % setptr installs the hand as a custom cursor image
            testCase.verifyTrue(ismember(hFigure.Pointer, {'hand', 'custom'}));
            tool.suspend()
            testCase.verifyFalse(logical(getappdata(hFigure, "Toggled")));
            tool.deactivate()

            testCase.verifyTrue(tool.isPointerInsideAxes([50, 50]));
            testCase.verifyFalse(tool.isPointerInsideAxes([-50, 50]));
            testCase.verifyFalse(tool.onKeyPress([], []));
            testCase.verifyFalse(tool.onKeyRelease([], []));
        end
    end

    methods (Test) % Zoom tools

        function zoomInClickHalvesTheView(testCase)
            [~, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.ZoomIn(hAxes);

            tool.onButtonDown([], struct("Button", 3))
            testCase.verifyFalse(tool.IsButtonDown, "Right button is ignored.");

            tool.onButtonDown([], struct("Button", 1))
            testCase.verifyTrue(tool.IsButtonDown);
            testCase.verifyNotEmpty(findobj(hAxes, "Tag", "Rectangular Selection Outline"));

            % Press and release at the same (fixed) pointer position: a click
            tool.onButtonUp([], [])
            testCase.verifyFalse(tool.IsButtonDown);
            testCase.verifyEqual(diff(hAxes.XLim), 50, "AbsTol", 1e-9);
            testCase.verifyEqual(diff(hAxes.YLim), 50, "AbsTol", 1e-9);
            testCase.verifyGreaterThanOrEqual(hAxes.XLim(1), 0.5);
            testCase.verifyLessThanOrEqual(hAxes.XLim(2), 100.5);
        end

        function scrollZoomKeepsThePointUnderThePointer(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.ZoomIn(hAxes);

            % The axes is 300 pixels square. The pointer stays at one
            % figure pixel; the data point under it may move by about a
            % screen pixel per zoom step, and no more.
            hFigure.CurrentPoint = [125, 275];
            pointBefore = hAxes.CurrentPoint(1, 1:2);
            tool.imageZoom('in')
            pointAfter = hAxes.CurrentPoint(1, 1:2);

            testCase.verifyLessThan(diff(hAxes.XLim), 100, "The view zoomed in.");
            dataUnitsPerPixel = diff(hAxes.XLim) / 300;
            testCase.verifyEqual(pointAfter, pointBefore, ...
                "AbsTol", 1.5*dataUnitsPerPixel);
        end

        function zoomInHonoursHostCallbacks(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.ZoomIn(hAxes);
            tool.ZoomInFcn = @() setappdata(hFigure, "ZoomIn", true);

            tool.onButtonDown([], struct("Button", 1))
            tool.onButtonUp([], [])
            testCase.verifyTrue(isappdata(hFigure, "ZoomIn"));
            testCase.verifyEqual(hAxes.XLim, [0.5, 100.5], ...
                "Without RunDefault the host owns the zoom.");

            tool.RunDefault = true;
            tool.onButtonDown([], struct("Button", 1))
            tool.onButtonUp([], [])
            testCase.verifyEqual(diff(hAxes.XLim), 50, "AbsTol", 1e-9);
        end

        function zoomInRectangleFitsAspectAndStaysInsideImage(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.ZoomIn(hAxes);
            tool.ZoomFinishedFcn = @() setappdata(hFigure, "ZoomFinished", true);

            tool.AnchorPoint = [10, 10];
            tool.plotRectangle()
            tool.updateRectangle([60, 40])
            hOutline = findobj(hAxes, "Tag", "Rectangular Selection Outline");
            testCase.verifyEqual(hOutline.XData, [10, 10, 60, 60, 10]);
            testCase.verifyEqual(hOutline.YData, [10, 40, 40, 10, 10]);

            tool.setNewImageLimits([10, 60], [10, 40])
            testCase.verifyEqual(hAxes.XLim, [10, 60], "AbsTol", 1e-9);
            testCase.verifyEqual(hAxes.YLim, [0.5, 50.5], "AbsTol", 1e-9, ...
                "Square axes: y widened to match, then shifted inside the image.");
            testCase.verifyTrue(isappdata(hFigure, "ZoomFinished"));

            tool.resetRectangle()
            testCase.verifyEmpty(findobj(hAxes, "Tag", "Rectangular Selection Outline"));
        end

        function zoomInDragReleaseDelegatesToRectangularZoomFcn(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.ZoomIn(hAxes);
            tool.RectangularZoomFcn = @(xLim, yLim) setappdata(hFigure, "RectZoom", [xLim, yLim]);

            tool.onButtonDown([], struct("Button", 1))
            tool.AnchorPoint = [90, 90]; % far from the fixed pointer position: a drag
            tool.onButtonUp([], [])

            testCase.verifyTrue(isappdata(hFigure, "RectZoom"));
            reported = getappdata(hFigure, "RectZoom");
            testCase.verifyLessThanOrEqual(reported(1), reported(2));
            testCase.verifyEqual(hAxes.XLim, [0.5, 100.5], "Host owns the zoom.");
            testCase.verifyEmpty(findobj(hAxes, "Tag", "Rectangular Selection Outline"));
        end

        function zoomOutRestoresTheOriginalView(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            zoomIn = uim.interface.pointertools.ZoomIn(hAxes);
            zoomOut = uim.interface.pointertools.ZoomOut(hAxes);

            zoomIn.imageZoom('in')
            testCase.assertEqual(diff(hAxes.XLim), 50, "AbsTol", 1e-9);

            zoomOut.onButtonDown([], struct("Button", 3))
            testCase.verifyEqual(diff(hAxes.XLim), 50, "AbsTol", 1e-9, "Right button is ignored.");

            zoomOut.onButtonDown([], struct("Button", 1))
            testCase.verifyEqual(hAxes.XLim, [0.5, 100.5], "AbsTol", 1e-9);
            testCase.verifyEqual(hAxes.YLim, [0.5, 100.5], "AbsTol", 1e-9);

            zoomIn.imageZoom('in')
            zoomOut.ButtonDownFcn = @() setappdata(hFigure, "ZoomOut", true);
            zoomOut.onButtonDown([], struct("Button", 1))
            testCase.verifyTrue(isappdata(hFigure, "ZoomOut"));
            testCase.verifyEqual(diff(hAxes.XLim), 50, "AbsTol", 1e-9, "Host owns the zoom.");

            zoomOut.activate()
            zoomOut.onButtonMotion([], [])
            zoomOut.onButtonUp([], [])
        end

        function zoomableShiftViewAndClampedLimits(testCase)
            [~, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.ZoomIn(hAxes);
            tool.imageZoom('in')

            tool.shiftView([5, 5])
            testCase.verifyEqual(hAxes.XLim, [20.5, 70.5], "AbsTol", 1e-9);
            testCase.verifyEqual(hAxes.YLim, [30.5, 80.5], "AbsTol", 1e-9);

            tool.setNewXLims([-20, 30])
            testCase.verifyEqual(hAxes.XLim, [0.5, 30], "AbsTol", 1e-9);
            tool.setNewYLims([90, 200])
            testCase.verifyEqual(hAxes.YLim, [90, 100.5], "AbsTol", 1e-9);
            tool.setNewXLims()
            tool.setNewYLims([])
            testCase.verifyEqual(hAxes.XLim, [0.5, 100.5], "AbsTol", 1e-9);
            testCase.verifyEqual(hAxes.YLim, [0.5, 100.5], "AbsTol", 1e-9);
        end
    end

    methods (Test) % Pan and axis zoom

        function panMovesTheViewWithinTheOriginalLimits(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.Pan(hAxes);
            set(hAxes, "XLim", [25.5, 75.5], "YLim", [25.5, 75.5])

            tool.onButtonDown([], struct("Button", 1))
            testCase.verifyTrue(tool.IsButtonDown);

            tool.moveAxes([30, 0])
            testCase.verifyEqual(hAxes.XLim, [20.5, 70.5], "AbsTol", 1e-9, ...
                "300 px axes showing 50 units: 30 px is 5 units, content follows the pointer.");
            tool.moveAxes([0, 30])
            testCase.verifyEqual(hAxes.YLim, [30.5, 80.5], "AbsTol", 1e-9, ...
                "Reversed y axis flips the vertical direction.");

            tool.moveAxes([-3000, 0])
            testCase.verifyEqual(hAxes.XLim, [20.5, 70.5], "AbsTol", 1e-9, ...
                "A move past the original limits is refused.");
            tool.ConstrainX = false;
            tool.moveAxes([-3000, 0])
            testCase.verifyEqual(hAxes.XLim, [520.5, 570.5], "AbsTol", 1e-9);

            tool.ButtonMotionFcn = @(shift) setappdata(hFigure, "PanShift", shift);
            tool.PreviousPoint = [0, 0];
            tool.onButtonMotion([], [])
            testCase.verifyTrue(isappdata(hFigure, "PanShift"), ...
                "A host ButtonMotionFcn receives the pointer shift instead.");

            tool.onButtonUp([], [])
            testCase.verifyFalse(tool.IsButtonDown);
            tool.onButtonDown([], struct("Button", 3))
            testCase.verifyFalse(tool.IsButtonDown, "Right button is ignored.");
        end

        function panFollowsThePointerInAnyFigureUnits(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.Pan(hAxes);
            set(hAxes, "XLim", [25.5, 75.5], "YLim", [25.5, 75.5])

            for figureUnits = ["centimeters", "normalized"]
                hFigure.Units = figureUnits;
                xLimBefore = hAxes.XLim;

                hFigure.CurrentPoint = pixelsToFigureUnits(hFigure, [200, 200]);
                tool.onButtonDown([], struct("Button", 1))
                hFigure.CurrentPoint = pixelsToFigureUnits(hFigure, [230, 200]);
                tool.onButtonMotion([], [])
                tool.onButtonUp([], [])

                % 300 px axes showing 50 units: a 30 px drag is 5 units.
                testCase.verifyEqual(hAxes.XLim, xLimBefore - 5, "AbsTol", 1e-6, ...
                    "A 30 px drag moves the view by 30 px with figure Units " + figureUnits + ".");
            end
        end

        function axisZoomStretchMatchesThePointerInAnyUnits(testCase)
            hFigure = figure("Visible", "off", "Units", "centimeters");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "XLim", [0, 100], "YLim", [0, 100]);
            tool = uim.interface.pointertools.AxisZoom(hAxes);
            axesPosition = getpixelposition(hAxes);

            hFigure.CurrentPoint = pixelsToFigureUnits(hFigure, [200, 200]);
            tool.onButtonDown([], struct("Button", 1))
            hFigure.CurrentPoint = pixelsToFigureUnits(hFigure, [190, 190]);
            tool.dragXLimits()
            tool.dragYLimits('left')

            % A drag of d px towards the origin moves each end inwards by
            % range * d / axesLength.
            expectedXShift = 100 * 10 / axesPosition(3);
            expectedYShift = 100 * 10 / axesPosition(4);
            testCase.verifyEqual(hAxes.XLim, [expectedXShift, 100 - expectedXShift], "AbsTol", 1e-6, ...
                "The stretch uses pixel distances, not normalized axes units.");
            testCase.verifyEqual(hAxes.YLim, [expectedYShift, 100 - expectedYShift], "AbsTol", 1e-6);
        end

        function dragToolsRecoverAfterButtonMotionFcnError(testCase)
            for toolName = ["Pan", "AxisZoom"]
                [hFigure, hAxes] = createImageAxes(testCase);
                toolClass = "uim.interface.pointertools." + toolName;
                failingTool = feval(toolClass, hAxes);
                failingTool.ButtonMotionFcn = @(shift) error("test:motionFailed", "Motion failed");
                failingTool.PreviousPoint = [0, 0];
                failingTool.onButtonDown([], struct("Button", 1))
                testCase.verifyError(@() failingTool.onButtonMotion([], []), "test:motionFailed");

                otherTool = feval(toolClass, hAxes);
                otherTool.ButtonMotionFcn = @(shift) setappdata(hFigure, "Shift", shift);
                otherTool.PreviousPoint = [0, 0];
                otherTool.onButtonDown([], struct("Button", 1))
                otherTool.onButtonMotion([], [])
                testCase.verifyTrue(isappdata(hFigure, "Shift"), ...
                    toolName + ": an error in one tool's ButtonMotionFcn does not block another tool.");

                failingTool.ButtonMotionFcn = @(shift) setappdata(hFigure, "Recovered", true);
                failingTool.onButtonMotion([], [])
                testCase.verifyTrue(isappdata(hFigure, "Recovered"), ...
                    toolName + ": the tool handles the next motion after an error.");
            end
        end

        function axisZoomDragStretchesLimitsWithinOriginal(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.AxisZoom(hAxes);

            tool.onButtonDown([], struct("Button", 1))
            testCase.verifyTrue(tool.IsButtonDown);

            % Dragging 60 px towards the origin shrinks the 100-unit range
            % by 20 units on each side (300 px axes).
            tool.PreviousMousePoint = hFigure.CurrentPoint + [60, 0];
            tool.dragXLimits()
            testCase.verifyEqual(hAxes.XLim, [20.5, 80.5], "AbsTol", 1e-9);

            tool.PreviousMousePoint = hFigure.CurrentPoint + [0, 60];
            tool.dragYLimits('left')
            testCase.verifyEqual(hAxes.YLim, [20.5, 80.5], "AbsTol", 1e-9);

            tool.PreviousMousePoint = hFigure.CurrentPoint - [600, 600];
            tool.dragXLimits()
            tool.dragYLimits('left')
            testCase.verifyEqual(hAxes.XLim, [0.5, 100.5], "AbsTol", 1e-9, ...
                "Stretching past the original limits is clipped.");
            testCase.verifyEqual(hAxes.YLim, [0.5, 100.5], "AbsTol", 1e-9);

            tool.CurrentAxis = 'x';
            tool.setPointerSymbol()
            testCase.verifyEqual(hFigure.Pointer, 'left');
            tool.CurrentAxis = 'y';
            tool.setPointerSymbol()
            testCase.verifyEqual(hFigure.Pointer, 'top');

            tool.ButtonMotionFcn = @(shift) setappdata(hFigure, "AxisShift", shift);
            tool.PreviousPoint = [0, 0];
            tool.onButtonMotion([], [])
            testCase.verifyTrue(isappdata(hFigure, "AxisShift"));

            tool.onButtonUp([], [])
            testCase.verifyFalse(tool.IsButtonDown);
        end

        function axisZoomMeasuresFirstMotionFromThePress(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.AxisZoom(hAxes);
            tool.ButtonMotionFcn = @(shift) setappdata(hFigure, "AxisShift", shift);

            for pressPoint = {[100, 100], [250, 150]}
                hFigure.CurrentPoint = pressPoint{1};
                tool.onButtonDown([], struct("Button", 1))
                hFigure.CurrentPoint = pressPoint{1} + [5, -3];
                tool.onButtonMotion([], [])
                tool.onButtonUp([], [])

                testCase.verifyEqual(getappdata(hFigure, "AxisShift"), [5, -3], ...
                    "The first motion of each drag is measured from its press.");
            end
        end

        function axisZoomHonoursConstrainFlags(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            tool = uim.interface.pointertools.AxisZoom(hAxes);
            tool.ConstrainX = false;
            tool.onButtonDown([], struct("Button", 1))

            % Dragging 60 px away from the origin widens the 100-unit
            % range by 20 units on each side (300 px axes).
            tool.PreviousMousePoint = hFigure.CurrentPoint - [60, 60];
            tool.dragXLimits()
            tool.dragYLimits('left')

            testCase.verifyEqual(hAxes.XLim, [-19.5, 120.5], "AbsTol", 1e-9, ...
                "With ConstrainX false the x limits may pass XLimOrig.");
            testCase.verifyEqual(hAxes.YLim, [0.5, 100.5], "AbsTol", 1e-9, ...
                "With ConstrainY true the y limits stay clipped.");
        end
    end

    methods (Test) % Crop

        function cropToolReportsSelectedRegion(testCase)
            testCase.assumeTrue(exist("drawrectangle", "file") > 0, ...
                "Crop needs Image Processing Toolbox ROI objects.");
            [hFigure, hAxes] = createImageAxes(testCase);
            crop = uim.interface.pointertools.Crop(hAxes);
            cropListener = listener(crop, "CropLimitChanged", ...
                @(~, evt) setappdata(hFigure, "CropLimits", [evt.XLim, evt.YLim]));
            testCase.addTeardown(@delete, cropListener);

            % A preset region creates the ROI immediately; a timer ends the
            % modal wait that activate() enters in place of the user. It
            % repeats, because a resume that arrives before the wait
            % starts has no effect.
            crop.CurrentXLim = [11, 30];
            crop.CurrentYLim = [21, 60];
            resumeTimer = timer("StartDelay", 0.5, "Period", 0.5, ...
                "ExecutionMode", "fixedSpacing", ...
                "TimerFcn", @(~, ~) uiresume(hFigure));
            testCase.addTeardown(@() cleanupTimer(resumeTimer));
            start(resumeTimer)

            crop.activate()
            stop(resumeTimer)

            testCase.verifyEqual(crop.CurrentXLim, [11, 30]);
            testCase.verifyEqual(crop.CurrentYLim, [21, 60]);
            testCase.verifyEqual(getappdata(hFigure, "CropLimits"), [11, 30, 21, 60]);
            hMask = findobj(hAxes, "Tag", "Crop Outline");
            testCase.verifyNumElements(hMask, 1);
            testCase.verifyEqual(hMask.XData(6:9)', [11, 31, 31, 11]);
            testCase.verifyEmpty(crop.ImrectHandle, "The ROI is removed on deactivate.");

            crop.deactivate()
            testCase.verifyNumElements(findobj(hAxes, "Tag", "Crop Outline"), 1, ...
                "Deactivating without an ROI leaves the mask alone.");
        end
    end

    methods (Test) % PointerManager

        function keyBindingsToggleToolsWithExitModes(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            manager = uim.interface.PointerManager(hFigure, hAxes, ...
                {"zoomIn", "zoomOut", "pan", "dataCursor"});
            testCase.addTeardown(@deleteValid, manager);

            press = @(key) manager.onKeyPress([], struct("Key", key, "Modifier", {{}}));

            testCase.verifyTrue(press('q'));
            testCase.verifyClass(manager.CurrentPointerTool, "uim.interface.pointertools.ZoomIn");
            testCase.verifyTrue(press('q'));
            testCase.verifyEmpty(manager.CurrentPointerTool, ...
                "A 'previous'-mode tool with no predecessor toggles off.");
            testCase.verifyEqual(hFigure.Pointer, 'arrow');

            press('i')
            testCase.verifyClass(manager.CurrentPointerTool, "uim.interface.pointertools.DataCursor");
            press('y')
            testCase.verifyClass(manager.CurrentPointerTool, "uim.interface.pointertools.Pan");
            press('y')
            testCase.verifyClass(manager.CurrentPointerTool, "uim.interface.pointertools.DataCursor", ...
                "Toggling a 'previous'-mode tool off resumes the suspended default-mode tool.");
            press('q')
            press('w')
            testCase.verifyClass(manager.CurrentPointerTool, "uim.interface.pointertools.ZoomOut", ...
                "Switching between 'previous'-mode tools replaces the current one.");
            press('i')
            testCase.verifyClass(manager.CurrentPointerTool, "uim.interface.pointertools.DataCursor", ...
                "A default-mode tool replaces a 'previous'-mode tool and flushes the suspended one.");
            press('i')
            testCase.verifyEmpty(manager.CurrentPointerTool, ...
                "Toggling the active default-mode tool off returns to no tool.");

            testCase.verifyFalse(press('z'), "Unbound key.");
            testCase.verifyFalse(manager.onKeyPress([], struct("Key", 'q', "Modifier", {{'shift'}})));
            testCase.verifyFalse(manager.onKeyRelease([], []));
            manager.togglePointerMode('teleport')
            testCase.verifyEmpty(manager.CurrentPointerTool, "Unknown tools are ignored.");
        end

        function managerAcceptsConstructorHandlesAndRejectsUnknownNames(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            manager = uim.interface.PointerManager(hFigure, hAxes, ...
                {@uim.interface.pointertools.Pan, "crop"});
            testCase.addTeardown(@deleteValid, manager);
            testCase.verifyEqual(sort(fieldnames(manager.Pointers)), {'crop'; 'pan'});

            testCase.verifyError(...
                @() uim.interface.PointerManager(hFigure, hAxes, {"teleport"}), ...
                "uim:PointerManager:UnknownPointerTool");
        end

        function managerDefaultToolIsRestoredAfterDefaultModeToggle(testCase)
            [hFigure, hAxes] = createImageAxes(testCase);
            manager = uim.interface.PointerManager(hFigure, hAxes, {"dataCursor", "zoomIn"});
            testCase.addTeardown(@deleteValid, manager);
            manager.DefaultPointerTool = manager.Pointers.zoomIn;

            manager.togglePointerMode('dataCursor')
            manager.togglePointerMode('dataCursor')
            testCase.verifyClass(manager.CurrentPointerTool, "uim.interface.pointertools.ZoomIn");
            manager.updatePointerSymbol()
            manager.togglePointerMode('zoomIn')
            testCase.verifyEmpty(manager.CurrentPointerTool);
        end
    end
end

function [hFigure, hAxes] = createImageAxes(testCase)
%createImageAxes Hidden figure with a square 100x100 image axes
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 400]);
    testCase.addTeardown(@deleteValid, hFigure);
    hAxes = axes(hFigure, "Units", "pixels", "Position", [50, 50, 300, 300]);
    image(hAxes, zeros(100, "uint8"))
    set(hAxes, "XLim", [0.5, 100.5], "YLim", [0.5, 100.5], "YDir", "reverse")
    hold(hAxes, "on")
end

function point = pixelsToFigureUnits(hFigure, pixelPoint)
%pixelsToFigureUnits Express a figure point given in pixels in the figure Units
    pointPosition = hgconvertunits(hFigure, [pixelPoint, 0, 0], ...
        "pixels", hFigure.Units, hFigure);
    point = pointPosition(1:2);
end

function cleanupTimer(resumeTimer)
    if isvalid(resumeTimer)
        stop(resumeTimer)
        delete(resumeTimer)
    end
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
