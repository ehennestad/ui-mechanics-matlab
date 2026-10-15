classdef TestWidgetGeometry < matlab.unittest.TestCase
%TestWidgetGeometry Unit tests for the UI-free maths in uim.widget.internal
%
%   These functions carry the coordinate and value computations of the
%   slider family, the scrollbar and the overview indicator, so they are
%   tested here without creating any graphics.

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % Value <-> pixel mapping

        function valueLimitsMapToTrackEnds(testCase)
            pixel = uim.widget.internal.mapValueToPixel([0, 50, 100], [0, 100], 20, 200);
            testCase.verifyEqual(pixel, [20, 120, 220]);
        end

        function valueMappingHandlesOffsetLimitsAndExtrapolates(testCase)
            pixel = uim.widget.internal.mapValueToPixel([-5, 5, 15], [5, 15], 10, 100);
            testCase.verifyEqual(pixel, [-90, 10, 110]);
        end

        function valueMappingAcceptsIntegerValues(testCase)
            pixel = uim.widget.internal.mapValueToPixel(uint8(128), [0, 255], 0, 255);
            testCase.verifyClass(pixel, "double");
            testCase.verifyEqual(pixel, 128);
        end

        function valueMappingRejectsNonIncreasingLimits(testCase)
            testCase.verifyError(...
                @() uim.widget.internal.mapValueToPixel(1, [3, 3], 0, 10), ...
                "uim:mapValueToPixel:InvalidLimits");
            testCase.verifyError(...
                @() uim.widget.internal.mapValueToPixel(1, [5, 3], 0, 10), ...
                "uim:mapValueToPixel:InvalidLimits");
        end

        function pixelMappingInvertsValueMapping(testCase)
            valueLimits = [-2, 8];
            values = linspace(-2, 8, 7);
            pixels = uim.widget.internal.mapValueToPixel(values, valueLimits, 33, 150);
            recovered = uim.widget.internal.mapPixelToValue(pixels, valueLimits, 33, 150);
            testCase.verifyEqual(recovered, values, "AbsTol", 1e-12);
        end

        function pixelMappingRejectsZeroLengthTrack(testCase)
            testCase.verifyError(...
                @() uim.widget.internal.mapPixelToValue(5, [0, 1], 0, 0), ...
                "MATLAB:validators:mustBeNonzero");
        end
    end

    methods (Test) % Snapping and knob selection

        function snapToStepRoundsToNearestMultiple(testCase)
            testCase.verifyEqual(uim.widget.internal.snapToStep(0.26, 0.1), 0.3, "AbsTol", 1e-12);
            testCase.verifyEqual(uim.widget.internal.snapToStep(7.4, 5), 5);
            testCase.verifyEqual(uim.widget.internal.snapToStep(7.5, 5), 10);
            testCase.verifyEqual(uim.widget.internal.snapToStep(-2.6, 1), -3);
        end

        function snapToStepWorksElementwise(testCase)
            snapped = uim.widget.internal.snapToStep([0.1, 0.9, 1.4], 0.5);
            testCase.verifyEqual(snapped, [0, 1, 1.5]);
        end

        function snapToStepRejectsNonPositiveStep(testCase)
            testCase.verifyError(@() uim.widget.internal.snapToStep(1, 0), ...
                "MATLAB:validators:mustBePositive");
        end

        function nearestRangeKnobPicksClosestKnob(testCase)
            testCase.verifyEqual(uim.widget.internal.nearestRangeKnob(1, 3, 9), 'low');
            testCase.verifyEqual(uim.widget.internal.nearestRangeKnob(3, 3, 9), 'low');
            testCase.verifyEqual(uim.widget.internal.nearestRangeKnob(4, 3, 9), 'low');
            testCase.verifyEqual(uim.widget.internal.nearestRangeKnob(8, 3, 9), 'high');
            testCase.verifyEqual(uim.widget.internal.nearestRangeKnob(9, 3, 9), 'high');
            testCase.verifyEqual(uim.widget.internal.nearestRangeKnob(12, 3, 9), 'high');
        end

        function nearestRangeKnobTieGoesToLowKnob(testCase)
            testCase.verifyEqual(uim.widget.internal.nearestRangeKnob(6, 3, 9), 'low');
        end
    end

    methods (Test) % Tick marks and knob outline

        function tickMarksAreNanSeparatedSegments(testCase)
            [x, y] = uim.widget.internal.tickMarkCoordinates([10, 110], 50, 8, 'under', 5);

            testCase.verifySize(x, [3, 5]);
            testCase.verifySize(y, [3, 5]);
            testCase.verifyTrue(all(isnan(x(3, :))) && all(isnan(y(3, :))));
            % Default inset of 2 pixels keeps ticks clear of the track ends
            testCase.verifyEqual(x(1, :), linspace(12, 108, 5), "AbsTol", 1e-12);
            testCase.verifyEqual(x(1, :), x(2, :));
            testCase.verifyEqual(y(1:2, 1), [50; 42]);
        end

        function tickMarkModesOffsetTheTicks(testCase)
            [~, yUnder] = uim.widget.internal.tickMarkCoordinates([0, 100], 50, 8, 'under', 3);
            [~, yOver] = uim.widget.internal.tickMarkCoordinates([0, 100], 50, 8, 'over', 3);
            [~, yBoth] = uim.widget.internal.tickMarkCoordinates([0, 100], 50, 8, 'both', 3);
            [~, yUnderX2] = uim.widget.internal.tickMarkCoordinates([0, 100], 50, 8, 'underx2', 3);

            testCase.verifyEqual(yUnder(1:2, 1), [50; 42]);
            testCase.verifyEqual(yOver(1:2, 1), [58; 50]);
            testCase.verifyEqual(yBoth(1:2, 1), [54; 46]);
            testCase.verifyEqual(yUnderX2(1:2, 1), [42; 34]);
        end

        function tickMarksAcceptStringModeAndCustomInset(testCase)
            [x, ~] = uim.widget.internal.tickMarkCoordinates([0, 100], 0, 4, "both", 2, 0);
            testCase.verifyEqual(x(1, :), [0, 100]);
        end

        function tickMarksRejectUnknownMode(testCase)
            testCase.verifyError(...
                @() uim.widget.internal.tickMarkCoordinates([0, 100], 0, 4, 'sideways', 3), ...
                "uim:tickMarkCoordinates:InvalidTickMode");
        end

        function knobOutlineIsClosedCircleOfGivenRadius(testCase)
            [x, y] = uim.widget.internal.knobOutline([10, 20], 7.5);

            testCase.verifyNumElements(x, 200);
            testCase.verifyEqual([x(1), y(1)], [x(end), y(end)], "AbsTol", 1e-12);
            radius = hypot(x - 10, y - 20);
            testCase.verifyEqual(radius, 7.5*ones(size(radius)), "AbsTol", 1e-12);
        end

        function knobOutlineScalesRadiiPerAxis(testCase)
            % 17 vertices place samples exactly on the axis crossings
            [x, y] = uim.widget.internal.knobOutline([0, 0], [4, 1], 17);

            testCase.verifyNumElements(x, 17);
            testCase.verifyEqual(max(x), 4, "AbsTol", 1e-12);
            testCase.verifyEqual(max(y), 1, "AbsTol", 1e-12);
        end
    end

    methods (Test) % Scrollbar

        function scrollChangeInsideTrackIsUnchanged(testCase)
            change = uim.widget.internal.clampScrollChange(0.2, 0.3, 1, 0.25);
            testCase.verifyEqual(change, 0.2);
        end

        function scrollChangeIsClampedAtBothEnds(testCase)
            testCase.verifyEqual(uim.widget.internal.clampScrollChange(-0.5, 0.3, 1, 0.25), -0.3);
            testCase.verifyEqual(uim.widget.internal.clampScrollChange(0.9, 0.3, 1, 0.25), 0.45, "AbsTol", 1e-12);
        end

        function scrollStepIsAcceptedWhenConsistentWithHistory(testCase)
            history = zeros(5, 1);
            [isAccepted, history] = uim.widget.internal.acceptScrollStep(history, 1);
            testCase.verifyTrue(isAccepted);
            testCase.verifyEqual(history, [0; 0; 0; 0; 1]);
        end

        function strayOppositeScrollStepIsRejected(testCase)
            history = [0; 1; 1; 1; 1];
            [isAccepted, history] = uim.widget.internal.acceptScrollStep(history, -1);
            testCase.verifyFalse(isAccepted);
            testCase.verifyEqual(history, [1; 1; 1; 1; -1]);
        end

        function zeroScrollStepIsNeverAccepted(testCase)
            isAccepted = uim.widget.internal.acceptScrollStep([1; 1; 1], 0);
            testCase.verifyFalse(isAccepted);
        end

        function scrollBarSizeCoversVisibleFraction(testCase)
            vertical = uim.widget.internal.scrollBarSize([10, 200], 'vertical', 0.25, 1, 6);
            horizontal = uim.widget.internal.scrollBarSize([200, 10], 'horizontal', 50, 100, 6);
            testCase.verifyEqual(vertical, [6, 50]);
            testCase.verifyEqual(horizontal, [100, 6]);
        end

        function scrollBarNeverShorterThanItsWidth(testCase)
            barSize = uim.widget.internal.scrollBarSize([10, 200], "vertical", 0.001, 1, 6);
            testCase.verifyEqual(barSize, [6, 6]);
        end

        function scrollBarSizeRejectsUnknownOrientation(testCase)
            testCase.verifyError(...
                @() uim.widget.internal.scrollBarSize([10, 200], 'diagonal', 0.5, 1, 6), ...
                "uim:scrollBarSize:InvalidOrientation");
        end
    end

    methods (Test) % Overview indicator

        function dataCornersMapToFrameCorners(testCase)
            dataLimits = [0, 200; 0, 100];
            frameOrigin = [10, 20];
            scale = 0.5;

            [x, y] = uim.widget.internal.mapDataToFrame(...
                [0, 200], [0, 100], dataLimits, frameOrigin, scale, 'normal');
            testCase.verifyEqual(x, [10, 110]);
            testCase.verifyEqual(y, [20, 70]);

            [x, y] = uim.widget.internal.mapDataToFrame(...
                [0, 200], [0, 100], dataLimits, frameOrigin, scale, 'reverse');
            testCase.verifyEqual(x, [10, 110]);
            testCase.verifyEqual(y, [70, 20], ...
                "With reversed y the smallest data y sits at the top of the frame.");
        end

        function frameToDataInvertsDataToFrame(testCase)
            dataLimits = [-50, 150; 10, 90];
            frameOrigin = [5, 7];
            scale = 1.25;
            point = [37, 61];

            for yDir = ["normal", "reverse"]
                [x, y] = uim.widget.internal.mapDataToFrame(point(1), point(2), ...
                    dataLimits, frameOrigin, scale, yDir);
                [xBack, yBack] = uim.widget.internal.mapFrameToData([x, y], ...
                    dataLimits, frameOrigin, scale, yDir);
                testCase.verifyEqual([xBack, yBack], point, "AbsTol", 1e-12);
            end
        end
    end

end
