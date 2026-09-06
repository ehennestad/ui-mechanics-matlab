classdef TestLayoutUtilities < matlab.unittest.TestCase
%TestLayoutUtilities Public layout helpers in uim.utility and uim.utility.layout

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % subdividePosition

        function normalizedLengthsShareTheAvailableSpace(testCase)
            [pos, siz] = uim.utility.layout.subdividePosition(0, 100, [0.5, 0.5], 10);
            testCase.verifyEqual(siz, [45, 45]);
            testCase.verifyEqual(pos, [1, 56]);
        end

        function pixelLengthsAreTakenBeforeNormalizedOnes(testCase)
            [pos, siz] = uim.utility.layout.subdividePosition(0, 100, [30, 1], 10);
            testCase.verifyEqual(siz, [30, 60]);
            testCase.verifyEqual(pos, [1, 41]);
        end

        function roundingRemainderGoesToLeadingComponents(testCase)
            [~, siz] = uim.utility.layout.subdividePosition(0, 100, [1, 1, 1]/3, 0);
            testCase.verifyEqual(siz, [34, 33, 33]);
            testCase.verifyEqual(sum(siz), 100);
        end

        function alignmentShiftsTheWholeGroup(testCase)
            [left, siz] = uim.utility.layout.subdividePosition(0, 100, [20, 20], 10, 'left');
            center = uim.utility.layout.subdividePosition(0, 100, [20, 20], 10, 'center');
            right = uim.utility.layout.subdividePosition(0, 100, [20, 20], 10, 'right');

            testCase.verifyEqual(siz, [20, 20]);
            testCase.verifyEqual(left, [1, 31]);
            testCase.verifyEqual(center, [26, 56]);
            testCase.verifyEqual(right, [50, 80]);
        end

        function initialOffsetAndColumnInputAreHonoured(testCase)
            pos = uim.utility.layout.subdividePosition(200, 100, [20; 20], 10);
            testCase.verifyEqual(pos, [201, 231]);
        end
    end

    methods (Test) % findgridsize, pos2lim

        function gridSizeFavoursLandscapeAspect(testCase)
            [nRows, nCols] = uim.utility.layout.findgridsize(6);
            testCase.verifyEqual([nRows, nCols], [2, 3]);
        end

        function gridSizeGrowsCountUntilAnAspectFits(testCase)
            [nRows, nCols] = uim.utility.layout.findgridsize(7);
            testCase.verifyEqual([nRows, nCols], [3, 5], ...
                "7 has no landscape factorisation; the next count that does is 15.");
        end

        function gridSizeAcceptsTargetAspectRatio(testCase)
            [nRows, nCols] = uim.utility.layout.findgridsize(4, [], 1);
            testCase.verifyEqual([nRows, nCols], [2, 2]);
        end

        function pos2limConvertsRectanglesToLimits(testCase)
            testCase.verifyEqual(uim.utility.pos2lim([10, 20, 30, 40]), [10, 20, 40, 60]);
            testCase.verifyEqual(uim.utility.pos2lim([0, 0, 1, 1; 5, 5, 2, 3]), ...
                [0, 0, 1, 1; 5, 5, 7, 8]);
        end
    end

    methods (Test) % Screen and figure placement

        function monitorLookupUsesInclusiveBounds(testCase)
            monitors = [1, 1, 100, 100; 101, 1, 100, 100];
            find = @(point) uim.utility.internal.findMonitorContainingPoint(point, monitors);

            testCase.verifyEqual(find([50, 50]), 1);
            testCase.verifyEqual(find([100, 100]), 1, "Far edge pixel belongs to the monitor.");
            testCase.verifyEqual(find([101, 1]), 2);
            testCase.verifyEqual(find([150, 50]), 2);
            testCase.verifyTrue(isnan(find([300, 50])));
            testCase.verifyTrue(isnan(find([50, 0])));
        end

        function currentScreenSizeIsAMonitorRectangle(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 200, 100]);
            [screenSize, screenNumber] = uim.utility.getCurrentScreenSize(hFigure);

            monitors = get(groot, "MonitorPositions");
            testCase.verifySize(screenSize, [1, 4]);
            testCase.verifyGreaterThanOrEqual(screenNumber, 1);
            testCase.verifyLessThanOrEqual(screenNumber, size(monitors, 1));
        end

        function placeMovesFigureToScreenEdges(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 200, 100]);
            screen = uim.utility.getCurrentScreenSize(hFigure);

            uim.utility.layout.place(hFigure, 'bottom')
            testCase.verifyEqual(hFigure.Position(2), screen(2));

            uim.utility.layout.place(hFigure, 'left', 5)
            testCase.verifyEqual(hFigure.Position(1), screen(1) + 5);

            uim.utility.layout.place(hFigure, 'northeast')
            testCase.verifyEqual(hFigure.Position(1), screen(1) + screen(3) - 200);
            testCase.verifyEqual(hFigure.Position(2), screen(2) + screen(4) - 100);

            uim.utility.layout.place(hFigure, 'southwest', [3, 4])
            testCase.verifyEqual(hFigure.Position(1:2), screen(1:2) + [3, 4]);

            uim.utility.layout.place(hFigure, 'northwest')
            uim.utility.layout.place(hFigure, 'southeast')
            uim.utility.layout.place(hFigure, 'top')
            uim.utility.layout.place(hFigure, 'right')
            testCase.verifyEqual(hFigure.Position(1), screen(1) + screen(3) - 200);
        end

        function centerFigureOnScreenCentresWithinTheMonitor(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 200, 100]);
            screen = uim.utility.getCurrentScreenSize(hFigure);

            uim.utility.centerFigureOnScreen(hFigure)
            expectedLocation = screen(1:2) + (screen(3:4) - [200, 100])/2;
            testCase.verifyEqual(hFigure.Position(1:2), expectedLocation, "AbsTol", 1);

            uim.utility.layout.place(hFigure, 'center')
            testCase.verifyEqual(hFigure.Position(1:2), expectedLocation, "AbsTol", 1);
        end

        function centerObjectInRectanglePlacesPanelCentre(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [0, 0, 100, 50]);

            uim.utility.layout.centerObjectInRectangle(hPanel, [0, 0, 400, 300])
            testCase.verifyEqual(hPanel.Position(1:2), [150, 125]);

            hOuter = uipanel(hFigure, "Units", "pixels", "Position", [20, 20, 200, 100]);
            uim.utility.layout.centerObjectInRectangle(hPanel, hOuter)
            testCase.verifyEqual(hPanel.Position(1:2), [70, 45]);
        end

        function centerObjectInRectangleRejectsNonPositionInput(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [0, 0, 100, 50]);
            testCase.verifyError(...
                @() uim.utility.layout.centerObjectInRectangle(hPanel, "nowhere"), ...
                ?MException);
        end

        function centerObjectInRectangleKeepsFigureOnScreen(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 200, 100]);
            screen = uim.utility.getCurrentScreenSize(hFigure);

            uim.utility.layout.centerObjectInRectangle(hFigure, screen - [10000, 10000, 0, 0])
            testCase.verifyGreaterThanOrEqual(hFigure.Position(1:2), screen(1:2));
        end

        function setPixelPositionNonScalarPositionsEachHandle(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hControls = gobjects(1, 2);
            hControls(1) = uicontrol(hFigure, "Style", "text", "Units", "normalized");
            hControls(2) = uicontrol(hFigure, "Style", "text", "Units", "normalized");

            positions = [10, 20, 30, 40; 50, 60, 70, 80];
            uim.utility.setpixelpositionnonscalar(hControls, positions)

            testCase.verifyEqual(getpixelposition(hControls(1)), positions(1, :), "AbsTol", 1);
            testCase.verifyEqual(getpixelposition(hControls(2)), positions(2, :), "AbsTol", 1);
            testCase.verifyEqual(get(hControls, "Units"), {'normalized'; 'normalized'}, ...
                "Original units are restored.");

            uim.utility.setpixelpositionnonscalar(hControls(1), [1, 2, 30, 40])
            testCase.verifyEqual(getpixelposition(hControls(1)), [1, 2, 30, 40], "AbsTol", 1);
        end

        function setPixelPositionNonScalarSupportsRecursiveAndRejectsBadShape(testCase)
            hFigure = createHiddenFigure(testCase, [100, 100, 400, 300]);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [50, 50, 300, 200]);
            hControls = [uicontrol(hPanel, "Style", "text"), uicontrol(hPanel, "Style", "text")];

            uim.utility.setpixelpositionnonscalar(hControls, [60, 70, 20, 10; 80, 90, 20, 10], true)
            testCase.verifyEqual(getpixelposition(hControls(1), true), [60, 70, 20, 10], "AbsTol", 1);
            testCase.verifyEqual(getpixelposition(hControls(2)), [30, 40, 20, 10], "AbsTol", 1);

            testCase.verifyError(...
                @() uim.utility.setpixelpositionnonscalar(hControls, [1, 2, 3, 4]), ?MException);
            testCase.verifyError(...
                @() uim.utility.setpixelpositionnonscalar(42, [1, 2, 3, 4]), ?MException);
        end
    end
end

function hFigure = createHiddenFigure(testCase, position)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", position);
    testCase.addTeardown(@deleteValid, hFigure);
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
