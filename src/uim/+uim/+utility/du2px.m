function pixelCoordinates = du2px(ax, dataUnits, recursive)
%Convert data unit coordinates to pixel coordinates
%
%   pixelCoords = du2px(ax, dataUnits)

% Todo: Does it need to change if axis are reversed... Probably

    if nargin < 3
        recursive = false; % See getpixelposition doc
    end

    axPos = getpixelposition(ax, recursive);
    axLim = [ax.XLim; ax.YLim]';
    axRange = diff(axLim);
    relativeCoordinates = (dataUnits - axLim(1, :)) ./ axRange;

    if strcmp(ax.XDir, 'reverse')
        relativeCoordinates(:, 1) = 1 - relativeCoordinates(:, 1);
    end
    if strcmp(ax.YDir, 'reverse')
        relativeCoordinates(:, 2) = 1 - relativeCoordinates(:, 2);
    end

    pixelCoordinates = relativeCoordinates .* axPos(3:4);
    if recursive
        pixelCoordinates = pixelCoordinates + axPos(1:2);
    end
end
