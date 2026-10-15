function varargout = px2du(ax, pixelCoords, recursive)
%px2du Convert pixel coordinates to axes data coordinates
%
%   dataUnits = uim.utility.px2du(ax, pixelCoords) converts the n-by-2
%   array of [x, y] points in pixels from the lower-left corner of axes
%   ax to data units. The axes pixel position from getpixelposition is
%   mapped onto XLim and YLim, and reversed axis directions (XDir or
%   YDir 'reverse') are taken into account.
%
%   dataUnits = uim.utility.px2du(ax, pixelCoords, recursive) with
%   recursive true reads pixelCoords as relative to the figure instead
%   (default false).
%
%   [x, y] = uim.utility.px2du(...) returns the x and y coordinates as
%   separate column vectors.
%
%   See also uim.utility.du2px

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
