classdef TestInteractionGeometry < matlab.unittest.TestCase
%TestInteractionGeometry Unit tests for the UI-free maths in uim.interface.internal
%
%   Zoom, pan, axis-drag, selection-rectangle and crop arithmetic, plus
%   the press/key translations of the PointerManager, tested without
%   any graphics.

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % Point and range predicates

        function pointInsideLimitsIsInclusive(testCase)
            inside = @(p) uim.interface.internal.isPointInsideLimits(p, [0, 10], [5, 15]);
            testCase.verifyTrue(inside([3, 7]));
            testCase.verifyTrue(inside([0, 5]));
            testCase.verifyTrue(inside([10, 15]));
            testCase.verifyFalse(inside([-1, 7]));
            testCase.verifyFalse(inside([3, 16]));
        end

        function rangeStrictlyInsideExcludesTouchingEdges(testCase)
            testCase.verifyTrue(uim.interface.internal.isRangeStrictlyInside([1, 9], [0, 10]));
            testCase.verifyFalse(uim.interface.internal.isRangeStrictlyInside([0, 9], [0, 10]));
            testCase.verifyFalse(uim.interface.internal.isRangeStrictlyInside([1, 10], [0, 10]));
        end

        function clickWithoutDragUsesOnePercentOfExtent(testCase)
            xLim = [0, 100]; yLim = [0, 100];
            testCase.verifyTrue(uim.interface.internal.isClickWithoutDrag([10, 10], [10.5, 10.9], xLim, yLim));
            testCase.verifyFalse(uim.interface.internal.isClickWithoutDrag([10, 10], [11, 10], xLim, yLim));
            testCase.verifyFalse(uim.interface.internal.isClickWithoutDrag([10, 10], [10, 12], xLim, yLim));
        end
    end

    methods (Test) % Range clamping

        function clampRangeShiftsWithoutResizing(testCase)
            testCase.verifyEqual(uim.interface.internal.clampRangeWithin([-5, 15], [0, 100]), [0, 20]);
            testCase.verifyEqual(uim.interface.internal.clampRangeWithin([90, 110], [0, 100]), [80, 100]);
            testCase.verifyEqual(uim.interface.internal.clampRangeWithin([20, 40], [0, 100]), [20, 40]);
        end

        function clampRangeSnapsToBoundsWhenWider(testCase)
            testCase.verifyEqual(uim.interface.internal.clampRangeWithin([-50, 150], [0, 100]), [0, 100]);
        end

        function intersectRangesClipsEachEnd(testCase)
            testCase.verifyEqual(uim.interface.internal.intersectRanges([-5, 50], [0, 100]), [0, 50]);
            testCase.verifyEqual(uim.interface.internal.intersectRanges([50, 150], [0, 100]), [50, 100]);
            testCase.verifyEqual(uim.interface.internal.intersectRanges([-5, 150], [0, 100]), [0, 100]);
        end
    end

    methods (Test) % Zooming

        function scaleLimitsGrowsAndShrinksAboutCentre(testCase)
            testCase.verifyEqual(uim.interface.internal.scaleLimits([0, 100], -0.25), [25, 75]);
            testCase.verifyEqual(uim.interface.internal.scaleLimits([25, 75], 0.5), [0, 100]);
            testCase.verifyEqual(uim.interface.internal.scaleLimits([10, 20], 0), [10, 20]);
        end

        function zoomAboutCentredPointerKeepsCentre(testCase)
            % Pointer at the axes centre, pointing at the data centre: the
            % window shrinks symmetrically (up to the quarter-pixel tuning).
            [xLim, yLim] = uim.interface.internal.zoomLimitsAboutPoint(...
                [0, 100], [0, 100], -0.25, [200, 200], [400, 400], [50, 50], 'normal');
            testCase.verifyEqual(xLim, [25, 75], "AbsTol", 0.05);
            testCase.verifyEqual(yLim, [25, 75], "AbsTol", 0.05);
        end

        function zoomAboutOffCentrePointerKeepsPointUnderPointer(testCase)
            % Pointer a quarter of the way in from the left/bottom, at data (25, 25)
            [xLim, yLim] = uim.interface.internal.zoomLimitsAboutPoint(...
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
            [~, yLimNormal] = uim.interface.internal.zoomLimitsAboutPoint(...
                [0, 100], [0, 100], -0.25, [200, 300], [400, 400], [50, 25], 'normal');
            [~, yLimReverse] = uim.interface.internal.zoomLimitsAboutPoint(...
                [0, 100], [0, 100], -0.25, [200, 300], [400, 400], [50, 25], 'reverse');
            testCase.verifyEqual((25 - yLimNormal(1))/diff(yLimNormal), 0.75, "AbsTol", 0.01);
            testCase.verifyEqual((25 - yLimReverse(1))/diff(yLimReverse), 0.25, "AbsTol", 0.01);
        end

        function aspectFitWidensTheNarrowDimension(testCase)
            [xLim, yLim] = uim.interface.internal.fitLimitsToAspectRatio([0, 100], [0, 100], 2);
            testCase.verifyEqual(xLim, [-50, 150]);
            testCase.verifyEqual(yLim, [0, 100]);

            [xLim, yLim] = uim.interface.internal.fitLimitsToAspectRatio([0, 100], [0, 100], 0.5);
            testCase.verifyEqual(xLim, [0, 100]);
            testCase.verifyEqual(yLim, [-50, 150]);

            [xLim, yLim] = uim.interface.internal.fitLimitsToAspectRatio([0, 200], [0, 100], 2);
            testCase.verifyEqual([xLim, yLim], [0, 200, 0, 100], "Already matching.");
        end
    end

    methods (Test) % Panning and axis dragging

        function panMovesContentWithThePointer(testCase)
            [xLim, yLim] = uim.interface.internal.panLimits(...
                [0, 100], [0, 50], [40, 20], [400, 200], 'normal');
            testCase.verifyEqual(xLim, [-10, 90]);
            testCase.verifyEqual(yLim, [-5, 45]);
        end

        function panFlipsVerticalShiftOnReversedAxes(testCase)
            [~, yLim] = uim.interface.internal.panLimits(...
                [0, 100], [0, 50], [0, 20], [400, 200], 'reverse');
            testCase.verifyEqual(yLim, [5, 55]);
        end

        function stretchLimitsScalesByDragFraction(testCase)
            testCase.verifyEqual(uim.interface.internal.stretchLimits([0, 100], 40, 400), [-10, 110]);
            testCase.verifyEqual(uim.interface.internal.stretchLimits([0, 100], -40, 400), [10, 90]);
        end
    end

    methods (Test) % Selection rectangle and crop

        function rectangleOutlineIsClosedAndClampedToLimits(testCase)
            [x, y] = uim.interface.internal.rectangleOutlineBetween([10, 20], [30, 40], [0, 100], [0, 100]);
            testCase.verifyEqual(x, [10, 10, 30, 30, 10]);
            testCase.verifyEqual(y, [20, 40, 40, 20, 20]);

            [x, y] = uim.interface.internal.rectangleOutlineBetween([10, 20], [130, -5], [0, 100], [0, 100]);
            testCase.verifyEqual(x(3), 100);
            testCase.verifyEqual(y(2), 0);
        end

        function cropLimitsAndRectanglesRoundTrip(testCase)
            rectangle = uim.interface.internal.limitsToRectangle([11, 30], [5, 24]);
            testCase.verifyEqual(rectangle, [11, 5, 20, 20]);

            [xLim, yLim] = uim.interface.internal.rectangleToLimits(rectangle);
            testCase.verifyEqual(xLim, [11, 30]);
            testCase.verifyEqual(yLim, [5, 24]);
        end

        function undefinedCropGivesEmptyRectangle(testCase)
            testCase.verifyEmpty(uim.interface.internal.limitsToRectangle([], []));
            testCase.verifyEmpty(uim.interface.internal.limitsToRectangle([1, inf], [1, inf]));
        end

        function cropMaskOutlineHasHoleAtTheCrop(testCase)
            [x, y] = uim.interface.internal.cropMaskOutline([10, 20, 30, 40], [100, 80]);
            testCase.verifyNumElements(x, 10);
            testCase.verifyEqual(x(1:5), [0, 101, 101, 0, 0]);
            testCase.verifyEqual(y(1:5), [81, 81, 0, 0, 81]);
            testCase.verifyEqual(x(6:10), [10, 40, 40, 10, 10]);
            testCase.verifyEqual(y(6:10), [20, 20, 60, 60, 20]);
        end
    end

    methods (Test) % PointerManager translations

        function selectionTypeMapsToMouseButtons(testCase)
            button = @uim.interface.internal.selectionTypeToButton;
            testCase.verifyEqual(button('normal', {}), 1);
            testCase.verifyEqual(button('open', {}), 1);
            testCase.verifyEqual(button('alt', {}), 3);
            testCase.verifyEqual(button('alt', {'control'}), 1, "ctrl+left is still the left button.");
            testCase.verifyEqual(button('extend', {}), 2);
            testCase.verifyEqual(button('extend', {'shift'}), 1, "shift+left is still the left button.");
            testCase.verifyEqual(button("alt"), 3, "Modifiers default to none.");
        end

        function keyBindingsResolveToToolNames(testCase)
            testCase.verifyEqual(uim.interface.internal.keyToPointerToolName('q'), 'zoomIn');
            testCase.verifyEqual(uim.interface.internal.keyToPointerToolName('w'), 'zoomOut');
            testCase.verifyEqual(uim.interface.internal.keyToPointerToolName('y'), 'pan');
            testCase.verifyEqual(uim.interface.internal.keyToPointerToolName("i"), 'dataCursor');
            testCase.verifyEqual(uim.interface.internal.keyToPointerToolName('x'), 'crop');
            testCase.verifyEmpty(uim.interface.internal.keyToPointerToolName('z'));
            testCase.verifyEmpty(uim.interface.internal.keyToPointerToolName('escape'));
            testCase.verifyEmpty(uim.interface.internal.keyToPointerToolName('1'));
        end
    end
end
