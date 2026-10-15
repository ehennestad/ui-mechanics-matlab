classdef TestColorAndDataUtilities < matlab.unittest.TestCase
%TestColorAndDataUtilities Colour conversion and small data helpers in uim.utility

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % hex2rgb / rgb2hex

        function hexConvertsToUnitRgb(testCase)
            testCase.verifyEqual(uim.utility.hex2rgb('#334D66'), [0.2, 0.302, 0.4], "AbsTol", 1e-3);
            testCase.verifyEqual(uim.utility.hex2rgb('334D66'), [0.2, 0.302, 0.4], "AbsTol", 1e-3);
        end

        function hexConvertsToByteRgbOnRequest(testCase)
            testCase.verifyEqual(uim.utility.hex2rgb('#334D66', 256), [51, 77, 102]);
            testCase.verifyEqual(uim.utility.hex2rgb('#334D66', 255), [51, 77, 102]);
        end

        function hexAcceptsCharMatrixAndCellInput(testCase)
            expected = [51, 77, 102; 128, 153, 179];
            testCase.verifyEqual(uim.utility.hex2rgb(['#334D66'; '#8099B3'], 256), expected);
            testCase.verifyEqual(uim.utility.hex2rgb({'#334D66', '#8099B3'}, 256), expected);
        end

        function hexRejectsUnsupportedRange(testCase)
            testCase.verifyError(@() uim.utility.hex2rgb('#334D66', 100), "uim:utility:hex2rgb:InvalidRange");
            testCase.verifyError(@() uim.utility.hex2rgb('#334D66', [1, 2]), "uim:utility:hex2rgb:InvalidRange");
        end

        function rgbConvertsToHexFromUnitOrByteScale(testCase)
            testCase.verifyEqual(uim.utility.rgb2hex([0, 1, 0]), '#00FF00');
            testCase.verifyEqual(uim.utility.rgb2hex([0, 255, 0]), '#00FF00');
            testCase.verifyEqual(uim.utility.rgb2hex([0.2, 0.3, 0.4; 0.5, 0.6, 0.7]), ...
                ['#334D66'; '#8099B3']);
        end

        function rgbHexRoundTripIsStable(testCase)
            colors = [0.2, 0.3, 0.4; 1, 1, 1; 0, 0, 0];
            recovered = uim.utility.hex2rgb(uim.utility.rgb2hex(colors));
            testCase.verifyEqual(recovered, colors, "AbsTol", 1/255);
        end

        function rgbRejectsMalformedInput(testCase)
            testCase.verifyError(@() uim.utility.rgb2hex([0, 1]), "uim:utility:rgb2hex:InvalidSize");
            testCase.verifyError(@() uim.utility.rgb2hex([0, 300, 0]), "uim:utility:rgb2hex:ValueOutOfRange");
            testCase.verifyError(@() uim.utility.rgb2hex('#00FF00'), "uim:utility:rgb2hex:InvalidType");
        end
    end

    methods (Test) % wavelengthToRgb

        function wavelengthMapsSpectrumEndpoints(testCase)
            testCase.verifyEqual(uim.utility.wavelengthToRgb(700), [1, 0, 0]);
            testCase.verifyEqual(uim.utility.wavelengthToRgb(380), [0.3, 0, 0.3], "AbsTol", 1e-12);
            testCase.verifyEqual(uim.utility.wavelengthToRgb(500), [0, 1, 0.5], "AbsTol", 1e-12);
            testCase.verifyEqual(uim.utility.wavelengthToRgb(460), [0, 0.4, 1], "AbsTol", 1e-12);
            testCase.verifyEqual(uim.utility.wavelengthToRgb(545), [0.5, 1, 0], "AbsTol", 1e-12);
            testCase.verifyEqual(uim.utility.wavelengthToRgb(600), [1, 0.6923, 0], "AbsTol", 1e-3);
        end

        function wavelengthOutsideVisibleRangeIsClamped(testCase)
            testCase.verifyEqual(uim.utility.wavelengthToRgb(900), [0.3, 0, 0], "AbsTol", 1e-12);
            testCase.verifyEqual(uim.utility.wavelengthToRgb(100), ...
                uim.utility.wavelengthToRgb(380));
        end

        function wavelengthRejectsNonPositiveInput(testCase)
            testCase.verifyError(@() uim.utility.wavelengthToRgb(-5), ...
                "MATLAB:validators:mustBePositive");
        end
    end

    methods (Test) % circularSmooth, range

        function circularSmoothWrapsAroundTheEnds(testCase)
            smoothed = uim.utility.circularSmooth([1, 0, 0, 0], 3);
            testCase.verifyEqual(smoothed, [1, 1, 0, 1]/3, "AbsTol", 1e-12);
        end

        function circularSmoothPreservesShapeAndConstants(testCase)
            testCase.verifyEqual(uim.utility.circularSmooth(5*ones(1, 6), 4), 5*ones(1, 6));
            column = uim.utility.circularSmooth((1:6)', 2);
            testCase.verifyTrue(iscolumn(column));
            testCase.verifyEmpty(uim.utility.circularSmooth([], 3));
        end

        function circularSmoothClampsWindowAndAcceptsMethod(testCase)
            smoothed = uim.utility.circularSmooth([1, 2, 3], 10, "movmedian");
            testCase.verifyNumElements(smoothed, 3);
            testCase.verifyError(@() uim.utility.circularSmooth([1, 2, 3], 0), ...
                "MATLAB:validators:mustBePositive");
        end

        function rangeWorksPerColumn(testCase)
            testCase.verifyEqual(uim.utility.range([1, 5; 4, 2]), [3, 3]);
            testCase.verifyError(@() uim.utility.range("abc"), "MATLAB:validators:mustBeNumeric");
        end
    end
end
