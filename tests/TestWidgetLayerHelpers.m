classdef TestWidgetLayerHelpers < matlab.unittest.TestCase
%TestWidgetLayerHelpers Pure helpers behind buttons, toolbars, message boxes and vector images

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % uim.control.internal

        function contentOffsetFollowsAlignmentAndPadding(testCase)
            offsetFor = @(h, v) uim.control.internal.contentOffsetInBox(...
                [100, 40], [30, 10], [4, 3, 6, 5], h, v);

            testCase.verifyEqual(offsetFor('left', 'bottom'), [4, 3]);
            testCase.verifyEqual(offsetFor('center', 'middle'), [35, 15]);
            testCase.verifyEqual(offsetFor('right', 'top'), [64, 25]);
            testCase.verifyEqual(offsetFor("Center", "Middle"), [35, 15], "Case-insensitive.");
        end

        function contentOffsetRejectsUnknownAlignment(testCase)
            testCase.verifyError(@() uim.control.internal.contentOffsetInBox(...
                [100, 40], [30, 10], zeros(1, 4), 'justified', 'middle'), ...
                "uim:contentOffsetInBox:InvalidAlignment");
            testCase.verifyError(@() uim.control.internal.contentOffsetInBox(...
                [100, 40], [30, 10], zeros(1, 4), 'left', 'baseline'), ...
                "uim:contentOffsetInBox:InvalidAlignment");
        end

        function requestedIconSizeDrivesTheLongDimension(testCase)
            [dimension, value] = uim.control.internal.fittedIconDimension(2, [50, 50], [24, 16]);
            testCase.verifyEqual(dimension, 'width');
            testCase.verifyEqual(value, 24);

            [dimension, value] = uim.control.internal.fittedIconDimension(0.5, [50, 50], [24, 16]);
            testCase.verifyEqual(dimension, 'height');
            testCase.verifyEqual(value, 16);
        end

        function unsetIconSizeFillsTheLimitingBoxDimension(testCase)
            [dimension, value] = uim.control.internal.fittedIconDimension(2, [40, 30]);
            testCase.verifyEqual(dimension, 'width', "A wide icon in a squarer box is width-limited.");
            testCase.verifyEqual(value, 40);

            [dimension, value] = uim.control.internal.fittedIconDimension(1, [40, 30], [nan, nan]);
            testCase.verifyEqual(dimension, 'height');
            testCase.verifyEqual(value, 30);
        end
    end

    methods (Test) % uim.widget.internal

        function runStartHonoursAllAlignmentNames(testCase)
            start = @(a) uim.widget.internal.alignRunStart(10, 100, 30, a);
            testCase.verifyEqual(start('left'), 10);
            testCase.verifyEqual(start('top'), 10);
            testCase.verifyEqual(start('center'), 45);
            testCase.verifyEqual(start('middle'), 45);
            testCase.verifyEqual(start('right'), 80);
            testCase.verifyEqual(start('bottom'), 80);
            testCase.verifyError(@() start('sideways'), "uim:alignRunStart:InvalidAlignment");
        end

        function messageWrapsAtSpacesWithinTheLimit(testCase)
            messageLines = uim.widget.internal.wrapMessageLines('one two three four', 9);
            testCase.verifyEqual(messageLines, {'one two '; 'three '; 'four'});

            messageLines = uim.widget.internal.wrapMessageLines('ab cd ef', 5);
            testCase.verifyEqual(messageLines, {'ab cd '; 'ef'}, ...
                "The space that ends a line does not count against the limit.");
        end

        function messageWrapsAfterPathSeparators(testCase)
            message = ['a', filesep, 'bb', filesep, 'ccc'];
            messageLines = uim.widget.internal.wrapMessageLines(message, 6);
            testCase.verifyEqual(messageLines, {['a', filesep, 'bb', filesep]; 'ccc'}, ...
                "Two tokens fit in six characters, the third does not.");

            messageLines = uim.widget.internal.wrapMessageLines(message, 4);
            testCase.verifyEqual(messageLines, {['a', filesep]; ['bb', filesep]; 'ccc'});
        end

        function overlongTokenGetsItsOwnLine(testCase)
            messageLines = uim.widget.internal.wrapMessageLines('short averyveryverylongword end', 8);
            testCase.verifyEqual(messageLines, {'short '; 'averyveryverylongword '; 'end'});
            testCase.verifyEqual(uim.widget.internal.wrapMessageLines('short averyveryverylongword ', 8), ...
                {'short '; 'averyveryverylongword '}, "A trailing separator adds no empty line.");
            testCase.verifyEmpty(uim.widget.internal.wrapMessageLines('', 8));
            testCase.verifyEqual(uim.widget.internal.wrapMessageLines("fits", 8), {'fits'});
        end
    end

    methods (Test) % uim.graphics.internal

        function boundingBoxAnchorNamesEveryCorner(testCase)
            bbox = [10, 20, 30, 40];
            anchor = @(h, v) uim.graphics.internal.boundingBoxAnchor(bbox, h, v);
            testCase.verifyEqual(anchor('left', 'bottom'), [10, 20]);
            testCase.verifyEqual(anchor('center', 'middle'), [25, 40]);
            testCase.verifyEqual(anchor('right', 'top'), [40, 60]);
            testCase.verifyError(@() anchor('outside', 'top'), "uim:boundingBoxAnchor:InvalidAlignment");
            testCase.verifyError(@() anchor('left', 'above'), "uim:boundingBoxAnchor:InvalidAlignment");
        end

        function cropKeepsOnePixelMarginAroundContent(testCase)
            image = 255*ones(10, 12, 3, 'uint8');
            image(4:6, 5:8, :) = 0;
            cropped = uim.graphics.internal.cropImageToContent(image);
            testCase.verifySize(cropped, [5, 6, 3]);
            testCase.verifyEqual(cropped(1, 1, 1), uint8(255), "Margin row is background.");
            testCase.verifyEqual(cropped(2, 2, 1), uint8(0));
        end

        function cropClampsMarginAtImageEdgesAndSkipsEmptyImages(testCase)
            image = 255*ones(5, 5, 'uint8');
            image(1:2, 4:5) = 0;
            cropped = uim.graphics.internal.cropImageToContent(image);
            testCase.verifySize(cropped, [3, 3]);

            blank = 255*ones(4, 4, 'uint8');
            testCase.verifyEqual(uim.graphics.internal.cropImageToContent(blank), blank);

            dark = zeros(4, 4, 'uint8');
            dark(2, 2) = 7;
            testCase.verifySize(uim.graphics.internal.cropImageToContent(dark, 0), [3, 3]);
        end
    end
end
