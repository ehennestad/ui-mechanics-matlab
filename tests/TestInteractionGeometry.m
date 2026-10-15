classdef TestInteractionGeometry < matlab.unittest.TestCase
%TestInteractionGeometry Unit tests for the UI-free maths in uim.interface.internal
%
%   Click-without-drag detection, the selection-rectangle and crop-mask
%   outlines, and the press/key translations of the PointerManager,
%   tested without any graphics. The limit arithmetic is tested in
%   TestGeometry.

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % Point and range predicates

        function clickWithoutDragUsesOnePercentOfExtent(testCase)
            xLim = [0, 100]; yLim = [0, 100];
            testCase.verifyTrue(uim.interface.internal.isClickWithoutDrag([10, 10], [10.5, 10.9], xLim, yLim));
            testCase.verifyFalse(uim.interface.internal.isClickWithoutDrag([10, 10], [11, 10], xLim, yLim));
            testCase.verifyFalse(uim.interface.internal.isClickWithoutDrag([10, 10], [10, 12], xLim, yLim));
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
            testCase.verifyEqual(button('alt', {'control'}), 3, ...
                "ctrl+click is the secondary click on macOS.");
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
