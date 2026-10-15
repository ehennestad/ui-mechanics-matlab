function [screenSize, screenNumber] = getCurrentScreenSize(hFig)
%getCurrentScreenSize Position and index of the monitor a figure is on
%
%   screenSize = uim.utility.getCurrentScreenSize(hFig) returns the
%   [x, y, width, height] pixel rectangle of the monitor that holds the
%   figure's upper-left corner, or its upper-right corner when the left
%   one is off every monitor. hFig.Position must be in pixels.
%
%   [screenSize, screenNumber] = uim.utility.getCurrentScreenSize(hFig)
%   also returns the row of that monitor in the root MonitorPositions.
%
%   With a single monitor, that monitor is returned. When neither corner
%   is on a monitor, the function warns and returns the root ScreenSize
%   and screenNumber 1.
%
%   See also uim.utility.centerFigureOnScreen, uim.utility.layout.place

    MP = get(0, 'MonitorPosition');
    if size(MP, 1) == 1
        screenSize = MP;
        screenNumber = 1;
        return
    end

    % Get coordinates for upper left corner of figure
    xPos = hFig.Position(1);
    yPos = hFig.Position(2) + hFig.Position(4);

    screenNumber = uim.utility.internal.findMonitorContainingPoint(...
        [xPos, yPos], MP); % Check upper left

    if isnan(screenNumber)                          % Check upper right
        % Get x-coordinate for upper right corner
        xPos = hFig.Position(1) + hFig.Position(3);
        screenNumber = uim.utility.internal.findMonitorContainingPoint(...
            [xPos, yPos], MP);
    end

    if ~isnan(screenNumber)
        screenSize = MP(screenNumber, :);
    else
        screenSize = get(0, 'ScreenSize');
        screenNumber = 1;
        warning('Could not resolve which screen figure is on, using main screen...')
        %screenSize = [];
    end

    if nargout == 1
        clear screenNumber
    end
end
