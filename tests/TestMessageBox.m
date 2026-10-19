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

        function constructorAssignsNameValueArguments(testCase)
            hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 200]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 380, 180]);

            messageBox = uim.widget.MessageBox(hPanel, "fontsize", 10, MinSize=[200, 40]);
            testCase.addTeardown(@deleteValid, messageBox);
            testCase.verifyEqual(messageBox.FontSize, 10);
            testCase.verifyEqual(messageBox.MinSize, [200, 40]);
        end

        function constructorRejectsInvalidNameValueArguments(testCase)
            hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 200]);
            testCase.addTeardown(@deleteValid, hFigure);
            hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 380, 180]);

            testCase.verifyError(@() uim.widget.MessageBox(hPanel, NoSuchProperty=1), ...
                "MATLAB:TooManyInputs");
            testCase.verifyError(@() uim.widget.MessageBox(hPanel, 1, 2), "MATLAB:TooManyInputs");
            % Private properties are not construction options
            testCase.verifyError(@() uim.widget.MessageBox(hPanel, CornerRadius=4), ...
                "MATLAB:TooManyInputs");
        end

        function boxOverAnAxesCanBeDraggedInsideIt(testCase)
            hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 600, 400]);
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure, "Units", "pixels", "Position", [50, 50, 500, 300]);
            messageBox = uim.widget.MessageBox(hAxes);
            testCase.addTeardown(@deleteValid, messageBox);
            messageBox.displayMessage('Drag me')

            boxAxes = messageBoxAxes(hFigure, hAxes);
            hBackground = findobj(boxAxes, "Type", "patch", "-function", ...
                @(h) isa(h.ButtonDownFcn, "function_handle") && contains(func2str(h.ButtonDownFcn), "startDrag"));
            testCase.assertNumElements(hBackground, 1, "The box background takes presses.");
            positionBefore = getpixelposition(boxAxes);

            hFigure.CurrentPoint = [300, 200];
            hBackground.ButtonDownFcn(hBackground, [])
            hFigure.CurrentPoint = [320, 190];
            moveWithListener(messageBox)
            testCase.verifyEqual(getpixelposition(boxAxes), positionBefore + [20, -10, 0, 0], ...
                "AbsTol", 1e-6, "The box follows the pointer.");

            hFigure.CurrentPoint = [2000, 200];
            moveWithListener(messageBox)
            boxPosition = getpixelposition(boxAxes);
            testCase.verifyEqual(boxPosition(1) + boxPosition(3), 550, "AbsTol", 1e-6, ...
                "The box stops at the right edge of the axes.");
        end

        function boxOverAnAxesNeedsNoToolbox(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure);
            messageBox = uim.widget.MessageBox(hAxes);
            testCase.addTeardown(@deleteValid, messageBox);

            testCase.verifyEmpty(findall(hAxes, "Tag", "imrect"), ...
                "No imrect is created in the reference axes.");
            testCase.verifyFalse(isa(messageBox, "uim.mixin.Resizable"));
        end

        function constructorAcceptsNameValueSyntax(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);

            messageBox = uim.widget.MessageBox(uipanel(hFigure), FontSize=10);
            testCase.addTeardown(@deleteValid, messageBox);

            testCase.verifyEqual(messageBox.FontSize, 10);
        end

        function resetCentersTheBoxInAPanel(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);

            messageBox.resetAxesPosition()

            % 380 x 180 px panel, 300 x 50 px box
            testCase.verifyEqual(messageBoxAxes(hFigure).Position, [40, 65, 300, 50], "AbsTol", 1e-9, ...
                "The box is centred in the panel, not offset by the panel position.");
        end

        function successiveLongMessagesKeepTheBoxSize(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);
            messageBox.resetAxesPosition()
            hAxes = messageBoxAxes(hFigure);
            positionBefore = hAxes.Position;
            % A point is 1 px at 72 px/inch (macOS) and 1.33 px at 96
            % px/inch (Linux). The medium message must overflow the box at
            % both densities, and the long message sized from the enlarged
            % box must differ from the long message sized from the original.
            mediumMessage = repmat('lorem ipsum ', 1, 10);
            longMessage = repmat('lorem ipsum ', 1, 60);

            messageBox.displayMessage(longMessage)
            positionForLongMessage = hAxes.Position;
            messageBox.clearMessage()

            messageBox.displayMessage(mediumMessage)
            testCase.assertGreaterThan(hAxes.Position(4), positionBefore(4), ...
                "Precondition: the medium message enlarges the box.");
            messageBox.displayMessage(longMessage)
            testCase.verifyEqual(hAxes.Position, positionForLongMessage, "AbsTol", 1e-9, ...
                "A long message is sized from the original box, not from an enlarged one.");

            messageBox.clearMessage()
            testCase.verifyEqual(hAxes.Position, positionBefore, "AbsTol", 1e-9, ...
                "Clearing restores the original box.");
        end

        function deleteStopsAPendingMessageTimer(testCase)
            timersBefore = numel(timerfindall);
            [~, messageBox] = createMessageBox(testCase);

            messageBox.displayMessage('Brief', 0.5)
            delete(messageBox)
            pause(1)

            testCase.verifyEqual(numel(timerfindall), timersBefore, ...
                "No timer is left after the box is deleted.");
        end

        function pendingMessageIgnoresDeletedGraphics(testCase)
            timersBefore = numel(timerfindall);
            [hFigure, messageBox] = createMessageBox(testCase);

            messageBox.displayMessage('Brief', 0.3)
            delete(hFigure)
            pause(0.8)

            testCase.verifyEqual(numel(timerfindall), timersBefore, ...
                "The timer deletes itself after firing.");
            testCase.verifyWarningFree(@() messageBox.clearMessage(), ...
                "Clearing after the figure is closed does nothing.");
        end

        function messagesAfterTheFigureClosesDoNothing(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);
            messageBox.waitbar(0.2, 'Loading')
            delete(hFigure)

            testCase.verifyWarningFree(@() messageBox.displayMessage('Late message'), ...
                "displayMessage does nothing once the figure is closed.");
            testCase.verifyWarningFree(@() messageBox.waitbar(0.5, 'Still loading'), ...
                "waitbar does nothing once the figure is closed.");
        end

        function callsOnADeletedBoxDoNothing(testCase)
            [~, messageBox] = createMessageBox(testCase);
            messageBox.waitbar(0.2, 'Loading')

            % A host that quits deletes its widgets while it may still
            % report progress
            delete(messageBox)

            testCase.verifyWarningFree(@() messageBox.waitbar(0.5, 'Still loading'));
            testCase.verifyWarningFree(@() messageBox.displayMessage('Late message'));
            testCase.verifyWarningFree(@() messageBox.clearMessage());
        end

        function boxDeletedWhileWaitbarRedrawsStopsQuietly(testCase)
            [hFigure, messageBox] = createMessageBox(testCase);
            messageBox.waitbar(0.1, 'Loading')

            % A queued callback runs at the next drawnow, as a close
            % request does; waitbar's redraw is the first one
            setappdata(groot, "TestMessageBoxClosed", false)
            testCase.addTeardown(@() rmappdata(groot, "TestMessageBoxClosed"));
            closeTimer = timer("StartDelay", 0, "TimerFcn", @(~, ~) closeOnce(hFigure, messageBox));
            testCase.addTeardown(@() delete(closeTimer));
            start(closeTimer)

            testCase.verifyWarningFree(@() messageBox.waitbar(0.6, 'Loading more'), ...
                "waitbar stops once the box is deleted during its own redraw.");
            testCase.assumeTrue(getappdata(groot, "TestMessageBoxClosed"), ...
                "The close ran during the waitbar call.");
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

function hAxes = messageBoxAxes(hFigure, referenceAxes)
    allAxes = findall(hFigure, "Type", "axes");
    if nargin > 1
        allAxes = allAxes(allAxes ~= referenceAxes);
    end
    hAxes = allAxes(1);
end

function moveWithListener(messageBox)
%moveWithListener Run the drag's motion listener; a hidden figure raises no motion events
    warningState = warning("off", "MATLAB:structOnObject");
    restoreWarning = onCleanup(@() warning(warningState));
    boxState = struct(messageBox);
    boxState.DragMotionListener.Callback([], [])
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

function closeOnce(hFigure, messageBox)
%closeOnce Delete the box and its figure, as quitting a host app does
    if isvalid(messageBox); delete(messageBox); end
    if isvalid(hFigure); delete(hFigure); end
    setappdata(groot, "TestMessageBoxClosed", true)
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
