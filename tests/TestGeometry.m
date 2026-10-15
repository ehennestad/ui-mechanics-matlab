classdef TestGeometry < matlab.unittest.TestCase
%TestGeometry Axis-limit, range and rectangle arithmetic in uim.geometry

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % Point and range predicates

        function pointInsideLimitsIsInclusive(testCase)
            inside = @(p) uim.geometry.isPointInsideLimits(p, [0, 10], [5, 15]);
            testCase.verifyTrue(inside([3, 7]));
            testCase.verifyTrue(inside([0, 5]));
            testCase.verifyTrue(inside([10, 15]));
            testCase.verifyFalse(inside([-1, 7]));
            testCase.verifyFalse(inside([3, 16]));
        end

        function rangeStrictlyInsideExcludesTouchingEdges(testCase)
            testCase.verifyTrue(uim.geometry.internal.isRangeStrictlyInside([1, 9], [0, 10]));
            testCase.verifyFalse(uim.geometry.internal.isRangeStrictlyInside([0, 9], [0, 10]));
            testCase.verifyFalse(uim.geometry.internal.isRangeStrictlyInside([1, 10], [0, 10]));
        end
    end

    methods (Test) % Fitting ranges inside bounds

        function fitRangeShiftsWithoutResizing(testCase)
            testCase.verifyEqual(uim.geometry.fitRangeInside([-5, 15], [0, 100]), [0, 20]);
            testCase.verifyEqual(uim.geometry.fitRangeInside([90, 110], [0, 100]), [80, 100]);
            testCase.verifyEqual(uim.geometry.fitRangeInside([20, 40], [0, 100]), [20, 40]);
        end

        function fitRangeNarrowsToBoundsWhenWider(testCase)
            testCase.verifyEqual(uim.geometry.fitRangeInside([-50, 150], [0, 100]), [0, 100]);
        end

        function fitRangeRejectsReversedRanges(testCase)
            testCase.verifyError(@() uim.geometry.fitRangeInside([12, -3], [0, 10]), ...
                "uim:geometry:InvalidRange");
            testCase.verifyError(@() uim.geometry.fitRangeInside([2, 3], [10, 0]), ...
                "uim:geometry:InvalidRange");
        end

        function intersectRangesClipsEachEnd(testCase)
            testCase.verifyEqual(uim.geometry.intersectRanges([-5, 50], [0, 100]), [0, 50]);
            testCase.verifyEqual(uim.geometry.intersectRanges([50, 150], [0, 100]), [50, 100]);
            testCase.verifyEqual(uim.geometry.intersectRanges([-5, 150], [0, 100]), [0, 100]);
        end
    end

    methods (Test) % Zooming

        function scaleLimitsGrowsAndShrinksAboutCentre(testCase)
            testCase.verifyEqual(uim.geometry.scaleLimits([0, 100], -0.25), [25, 75]);
            testCase.verifyEqual(uim.geometry.scaleLimits([25, 75], 0.5), [0, 100]);
            testCase.verifyEqual(uim.geometry.scaleLimits([10, 20], 0), [10, 20]);
        end

        function zoomAboutCentredPointerKeepsCentre(testCase)
            % Pointer at the axes centre, pointing at the data centre: the
            % window shrinks symmetrically (up to the quarter-pixel tuning).
            [xLim, yLim] = uim.geometry.internal.zoomLimitsAboutPoint(...
                [0, 100], [0, 100], -0.25, [200, 200], [400, 400], [50, 50], 'normal');
            testCase.verifyEqual(xLim, [25, 75], "AbsTol", 0.05);
            testCase.verifyEqual(yLim, [25, 75], "AbsTol", 0.05);
        end

        function zoomAboutOffCentrePointerKeepsPointUnderPointer(testCase)
            % Pointer a quarter of the way in from the left/bottom, at data (25, 25)
            [xLim, yLim] = uim.geometry.internal.zoomLimitsAboutPoint(...
                [0, 100], [0, 100], -0.25, [100, 100], [400, 400], [25, 25], 'normal');
            % The point under the pointer must map to the same relative position
            relativeX = (25 - xLim(1))/diff(xLim);
            relativeY = (25 - yLim(1))/diff(yLim);
            testCase.verifyEqual(relativeX, 0.25, "AbsTol", 0.01);
            testCase.verifyEqual(relativeY, 0.25, "AbsTol", 0.01);
            testCase.verifyEqual(diff(xLim), 50, "AbsTol", 1e-9);
        end

        function zoomHonoursReversedYAxis(testCase)
            % On an image axes the top of the axes is the smallest y value
            [~, yLimNormal] = uim.geometry.internal.zoomLimitsAboutPoint(...
                [0, 100], [0, 100], -0.25, [200, 300], [400, 400], [50, 25], 'normal');
            [~, yLimReverse] = uim.geometry.internal.zoomLimitsAboutPoint(...
                [0, 100], [0, 100], -0.25, [200, 300], [400, 400], [50, 25], 'reverse');
            testCase.verifyEqual((25 - yLimNormal(1))/diff(yLimNormal), 0.75, "AbsTol", 0.01);
            testCase.verifyEqual((25 - yLimReverse(1))/diff(yLimReverse), 0.25, "AbsTol", 0.01);
        end

        function aspectFitWidensTheNarrowDimension(testCase)
            [xLim, yLim] = uim.geometry.fitLimitsToAspectRatio([0, 100], [0, 100], 2);
            testCase.verifyEqual(xLim, [-50, 150]);
            testCase.verifyEqual(yLim, [0, 100]);

            [xLim, yLim] = uim.geometry.fitLimitsToAspectRatio([0, 100], [0, 100], 0.5);
            testCase.verifyEqual(xLim, [0, 100]);
            testCase.verifyEqual(yLim, [-50, 150]);

            [xLim, yLim] = uim.geometry.fitLimitsToAspectRatio([0, 200], [0, 100], 2);
            testCase.verifyEqual([xLim, yLim], [0, 200, 0, 100], "Already matching.");
        end
    end

    methods (Test) % Panning and axis dragging

        function panMovesContentWithThePointer(testCase)
            [xLim, yLim] = uim.geometry.internal.panLimits(...
                [0, 100], [0, 50], [40, 20], [400, 200], 'normal');
            testCase.verifyEqual(xLim, [-10, 90]);
            testCase.verifyEqual(yLim, [-5, 45]);
        end

        function panFlipsVerticalShiftOnReversedAxes(testCase)
            [~, yLim] = uim.geometry.internal.panLimits(...
                [0, 100], [0, 50], [0, 20], [400, 200], 'reverse');
            testCase.verifyEqual(yLim, [5, 55]);
        end

        function stretchLimitsScalesByDragFraction(testCase)
            testCase.verifyEqual(uim.geometry.internal.stretchLimits([0, 100], 40, 400), [-10, 110]);
            testCase.verifyEqual(uim.geometry.internal.stretchLimits([0, 100], -40, 400), [10, 90]);
        end
    end

    methods (Test) % Selection rectangle and crop

        function cropLimitsAndRectanglesRoundTrip(testCase)
            rectangle = uim.geometry.internal.limitsToRectangle([11, 30], [5, 24]);
            testCase.verifyEqual(rectangle, [11, 5, 20, 20]);

            [xLim, yLim] = uim.geometry.internal.rectangleToLimits(rectangle);
            testCase.verifyEqual(xLim, [11, 30]);
            testCase.verifyEqual(yLim, [5, 24]);
        end

        function undefinedCropGivesEmptyRectangle(testCase)
            testCase.verifyEmpty(uim.geometry.internal.limitsToRectangle([], []));
            testCase.verifyEmpty(uim.geometry.internal.limitsToRectangle([1, inf], [1, inf]));
        end
    end

    methods (Test) % Overview indicator

        function letterboxFitFillsTheLimitingDimension(testCase)
            [scale, frameSize] = uim.geometry.letterboxFit([400, 100], [200, 200]);
            testCase.verifyEqual(scale, 0.5);
            testCase.verifyEqual(frameSize, [200, 50]);

            [scale, frameSize] = uim.geometry.letterboxFit([100, 400], [200, 200]);
            testCase.verifyEqual(scale, 0.5);
            testCase.verifyEqual(frameSize, [50, 200]);
        end

        function letterboxFitMatchesEqualAspectExactly(testCase)
            [scale, frameSize] = uim.geometry.letterboxFit([30, 20], [90, 60]);
            testCase.verifyEqual(scale, 3);
            testCase.verifyEqual(frameSize, [90, 60]);
        end

        function limitsInsideExtentAreUnchanged(testCase)
            limits = [10, 20; 30, 40];
            clamped = uim.geometry.internal.shiftLimitsInside(limits, [0, 100; 0, 100]);
            testCase.verifyEqual(clamped, limits);
        end

        function limitsAreShiftedBackInsideExtent(testCase)
            extent = [0, 100; 0, 100];
            clamped = uim.geometry.internal.shiftLimitsInside([95, 105; -5, 5], extent);
            testCase.verifyEqual(clamped, [90, 100; 0, 10]);
        end

        function oversizedWindowIsShiftedByNetOvershoot(testCase)
            % A window wider than the extent cannot fit: the two edge
            % corrections cancel to a net shift of the window.
            clamped = uim.geometry.internal.shiftLimitsInside([-10, 120; 0, 50], [0, 100; 0, 100]);
            testCase.verifyEqual(clamped, [-20, 110; 0, 50]);
        end

        function centeredLimitsSurroundTheCenter(testCase)
            limits = uim.geometry.centeredLimits([50, 20], [10, 4]);
            testCase.verifyEqual(limits, [45, 55; 18, 22]);
        end
    end

end
