classdef TestDependencyBoundary < matlab.unittest.TestCase

    methods (Test)
        function sourceDoesNotReferenceForbiddenFrameworks(testCase)
            sourceRoot = TestDependencyBoundary.getSourceRoot();
            sourceFiles = dir(fullfile(sourceRoot, "**", "*.m"));

            forbiddenPatterns = [
                "nansen\."
                "applify\."
                "uiw\."
                "uix\."
                "uics\."
                "javacomponent"
                "java\."
                "javax\."
                "com\.mathworks"
                "findjobj"
                "getjframe"
                "matlab\.ui\.internal"
            ];

            violations = strings(0, 1);
            for i = 1:numel(sourceFiles)
                filePath = fullfile(sourceFiles(i).folder, sourceFiles(i).name);
                sourceText = string(fileread(filePath));

                for pattern = forbiddenPatterns'
                    if ~isempty(regexp(sourceText, pattern, "once"))
                        relativePath = erase(string(filePath), sourceRoot + filesep);
                        violations(end+1, 1) = relativePath + " -> " + pattern; %#ok<AGROW>
                    end
                end
            end

            testCase.verifyEmpty(violations, ...
                "The standalone source contains forbidden dependencies.");
        end

        function excludedBackendComponentsAreAbsent(testCase)
            sourceRoot = TestDependencyBoundary.getSourceRoot();
            excludedFiles = [
                fullfile(sourceRoot, "+abstract", "AppWindow.m")
                fullfile(sourceRoot, "+widget", "StylableTable.m")
                fullfile(sourceRoot, "AxesDialogBox.m")
                fullfile(sourceRoot, "+utility", "getJavaColor.m")
                fullfile(sourceRoot, "+event", "javaKeyEventToMatlabKeyData.m")
            ];

            testCase.verifyFalse(any(isfile(excludedFiles)), ...
                "A Java-, Widgets-, or application-backed component was copied.");
        end
    end

    methods (Static, Access = private)
        function sourceRoot = getSourceRoot()
            arguments (Output)
                sourceRoot (1,1) string
            end

            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourceRoot = string(fullfile(repositoryRoot, "src", "uim", "+uim"));
        end
    end
end
