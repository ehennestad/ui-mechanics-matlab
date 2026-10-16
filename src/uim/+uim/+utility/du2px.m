function pixelCoordinates = du2px(ax, dataUnits, recursive)
%du2px Convert axes data coordinates to pixel coordinates
%
%   pixelCoordinates = uim.utility.du2px(ax, dataUnits) converts the
%   n-by-2 array of [x, y] points in data units of axes ax to pixels from
%   the lower-left corner of the axes. XLim and YLim are mapped onto the
%   axes pixel position from getpixelposition, and reversed axis
%   directions (XDir or YDir 'reverse') are taken into account.
%
%   pixelCoordinates = uim.utility.du2px(ax, dataUnits, recursive) with
%   recursive true returns pixels relative to the figure instead
%   (default false).
%
%   See also uim.utility.px2du

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
