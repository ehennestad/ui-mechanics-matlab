function [screenSize, screenNumber] = getCurrentScreenSize(hFig)
%GETCURRENTSCREENSIZE Summary of this function goes here
%
%   [screenSize, screenNumber] = getCurrentScreenSize(hFig) returns the
%   posision coordinates (screenSize) and number of the monitor where a
%   figure is located.

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
