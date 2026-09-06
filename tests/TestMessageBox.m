classdef TestMessageBox < matlab.unittest.TestCase
%TestMessageBox Headless behaviour of the MessageBox overlay and its waitbar

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test)

        function messageIsShownAndCleared(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);

            testCase.verifyFalse(messageBox.isMessageDisplaying());
            messageBox.displayMessage('Hello world')
            testCase.verifyTrue(messageBox.isMessageDisplaying());
            testCase.verifyEqual(displayedLines(hFigure), {'Hello world'});

            messageBox.displayMessage('Hello world')
            testCase.verifyTrue(messageBox.isMessageDisplaying(), "Repeating a message is a no-op.");

            messageBox.clearMessage()
            testCase.verifyFalse(messageBox.isMessageDisplaying());
            testCase.verifyEmpty(displayedLines(hFigure));
        end

        function longMessageWrapsAndGrowsTheBox(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);
            hAxes = messageBoxAxes(hFigure);
            heightBefore = hAxes.Position(4);

            messageBox.displayMessage(repmat('lorem ipsum ', 1, 40))
            lines = displayedLines(hFigure);
            testCase.verifyGreaterThan(numel(lines), 1, "The message folds into several lines.");
            testCase.verifyGreaterThan(hAxes.Position(4), heightBefore, "The box grows to fit.");

            messageBox.clearMessage()
            testCase.verifyEqual(hAxes.Position(4), heightBefore, "AbsTol", 1e-9, ...
                "The box shrinks back when cleared.");
        end

        function messageClearsItselfAfterDuration(testCase)
            [~, messageBox] = createMessageBox(testCase);
            messageBox.displayMessage('Brief', 0.2)
            testCase.verifyTrue(messageBox.isMessageDisplaying());
            pause(0.8)
            drawnow
            testCase.verifyFalse(messageBox.isMessageDisplaying());
        end

        function fadingMessageEndsInTheSameStates(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);
            hBackground = findall(hFigure, "Type", "patch", "Parent", messageBoxAxes(hFigure));
            hBackground = hBackground(arrayfun(@(h) numel(h.XData) > 10, hBackground));

            messageBox.displayMessage('Fading in', [], true)
            testCase.verifyTrue(messageBox.isMessageDisplaying());
            testCase.verifyEqual(hBackground.FaceAlpha, messageBox.BackgroundAlpha, "AbsTol", 1e-9);

            messageBox.clearMessage(true)
            testCase.verifyFalse(messageBox.isMessageDisplaying());
            testCase.verifyEqual(char(hBackground.Visible), 'off');
        end

        function closeButtonClearsTheMessage(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);
            messageBox.displayMessage('Close me')
            hClose = findall(hFigure, "Type", "line", "Marker", "x");
            testCase.assertNumElements(hClose, 1);
            hClose.ButtonDownFcn(hClose, [])
            testCase.verifyFalse(messageBox.isMessageDisplaying());
        end

        function waitbarShowsProgressWithMessage(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);

            linesBefore = numel(findall(hFigure, "Type", "line"));
            messageBox.waitbar(0.25, 'Working')
            testCase.verifyTrue(messageBox.isMessageDisplaying());
            testCase.verifyEqual(numel(findall(hFigure, "Type", "line")), linesBefore + 2, ...
                "The waitbar adds a completed and a remaining bar.");
            messageBox.waitbar(1.5)
            messageBox.waitbar(1, '', 'close')
            messageBox.clearMessage()
            testCase.verifyFalse(messageBox.isMessageDisplaying());
        end

        function boxCanBeRepositionedAndReset(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);
            hAxes = messageBoxAxes(hFigure);

            messageBox.resetAxesPosition()
            testCase.verifyLessThanOrEqual(hAxes.Position(3), messageBox.MinSize(1) + 1e-9);
            testCase.verifyLessThanOrEqual(hAxes.Position(4), messageBox.MinSize(2) + 1e-9);

            messageBox.centerInWindow([0, 0, 400, 200])
            center = hAxes.Position(1:2) + hAxes.Position(3:4)/2;
            testCase.verifyEqual(center, [200, 100], "AbsTol", 1);

            messageBox.FontColor = [1, 0, 0];
            messageBox.BackgroundColor = [0, 0, 1];
            delete(messageBox)
            testCase.verifyFalse(isvalid(hAxes));
        end

        function constructorReportsUnknownParameters(testCase)
            hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 200]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 380, 180]);

            output = evalc("messageBox = uim.widget.MessageBox(hPanel, 'FontSize', 10, 'NoSuchProperty', 1);");
            testCase.addTeardown(@deleteValid, messageBox);
            testCase.verifyEqual(messageBox.FontSize, 10);
            testCase.verifyTrue(contains(output, 'NoSuchProperty'));
            testCase.verifyError(@() uim.widget.MessageBox(hPanel, 1, 2), ?MException);
        end
    end
end

function [hFigure, messageBox] = createMessageBox(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 200]);
    testCase.addTeardown(@deleteValid, hFigure);
    hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 380, 180]);
    messageBox = uim.widget.MessageBox(hPanel);
    testCase.addTeardown(@deleteValid, messageBox);
end

function hAxes = messageBoxAxes(hFigure)
    allAxes = findall(hFigure, "Type", "axes");
    hAxes = allAxes(1);
end

function lines = displayedLines(hFigure)
%displayedLines Visible, non-empty text lines of the message
    hTexts = findall(hFigure, "Type", "text", "Visible", "on");
    lines = cell(0, 1);
    for i = 1:numel(hTexts)
        value = hTexts(i).String;
        if ischar(value); value = {value}; end
        value = value(~cellfun(@isempty, value));
        lines = [lines; value(:)]; %#ok<AGROW>
    end
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
