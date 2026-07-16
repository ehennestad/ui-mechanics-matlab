function varargout = px2du(ax, pixelCoords, recursive)
%px2du Convert pixel coordinates to data unit coordinates
%
%   dataUnits = px2du(ax, pixelCoords)

    if nargin < 3
        recursive = false; % See getpixelposition doc
    end

    % Get Axes position in pixels.
    axPos = getpixelposition(ax, recursive);

    xLim = ax.XLim;
    yLim = ax.YLim;

    axLim = [xLim', yLim'];

    %axLim = reshape(axis(ax), 2, 2);
    axRange = diff(axLim);

    if recursive
        pixelCoords = pixelCoords - axPos(1:2);
    end
    relativeCoordinates = pixelCoords ./ axPos(3:4);
    if strcmp(ax.XDir, 'reverse')
        relativeCoordinates(:, 1) = 1 - relativeCoordinates(:, 1);
    end
    if strcmp(ax.YDir, 'reverse')
        relativeCoordinates(:, 2) = 1 - relativeCoordinates(:, 2);
    end

    dataUnits = relativeCoordinates .* axRange + axLim(1, 1:2);

    if nargout == 1
        varargout = {dataUnits};
    else
        varargout = {dataUnits(:,1), dataUnits(:,2)};
    end
end
