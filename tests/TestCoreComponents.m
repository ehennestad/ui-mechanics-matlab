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

            toolbar = uim.widget.toolbar(canvas, "Location", "northwest");
            button = toolbar.addButton("Text", "Run", "Tag", "RunButton");
            slider = uim.widget.rangeslider(canvas, "Min", 0, "Max", 10, ...
                "Low", 2, "High", 8);
            pages = uim.widget.PageIndicator(canvas, {"One", "Two"});
            pointerManager = uim.interface.pointerManager(hFigure, canvas.Axes, ...
                {"zoomIn", "zoomOut", "pan", "dataCursor"});
            testCase.addTeardown(@deleteValid, pointerManager);

            testCase.verifyClass(canvas.Axes, "matlab.graphics.axis.Axes");
            testCase.verifyClass(button, "uim.control.Button");
            testCase.verifyEqual(slider.Low, 2);
            testCase.verifyEqual(slider.High, 8);
            testCase.verifyEqual(pages.CurrentPage, 1);
            testCase.verifyEqual(numel(fieldnames(pointerManager.pointers)), 4);
        end

        function axesControlsRunInUiFigure(testCase)
            hFigure = uifigure("Visible", "off", "Position", [100, 100, 500, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Position", [1, 1, 500, 400]);
            canvas = uim.UIComponentCanvas(hPanel);
            toolbar = uim.widget.toolbar(canvas);
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

        function imageAndRoiGraphicsRun(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure);

            tileAxes = uim.graphics.tiledImageAxes(hPanel, ...
                "gridSize", [2, 2], "imageSize", [16, 16]);
            testCase.verifyEqual(tileAxes.nTiles, 4);

            hAxes = axes(hPanel);
            imageData = uint8(255 * ones(40, 40, 3));
            imageData(10:30, 10:30, :) = 0;
            hPatch = uim.graphics.patchLineDrawing(hAxes, imageData, ...
                "SmoothIter", 0, "cropImage", false, "plotType", "patch");

            testCase.verifyNotEmpty(hPatch);
            testCase.verifyTrue(all(isgraphics(hPatch)));
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
