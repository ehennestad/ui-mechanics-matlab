function layout = computeTileLayout(gridSize, imageSize, pixelPadding, plotOrder)
%computeTileLayout Pixel bookkeeping for a grid of image tiles
%
%   layout = uim.graphics.internal.computeTileLayout(gridSize, imageSize,
%       pixelPadding, plotOrder) describes where each tile of a gridSize
%   ([numRows, numColumns]) grid of imageSize ([height, width]) tiles,
%   separated by pixelPadding pixels, sits inside the composite image.
%   plotOrder is 'rowwise' (tile numbers increase along rows) or
%   'columnwise'.
%
%   layout is a struct with fields
%       TileIndices  - numRows-by-numColumns cell array; element k holds
%                      the linear pixel indices of tile k into the
%                      composite image (height-by-width)
%       TileCorners  - numTiles-by-2 [x, y] pixel coordinate of each
%                      tile's upper-left corner
%       TileIndexMap - height-by-width matrix giving the tile number at
%                      each pixel, NaN in the gaps

    arguments
        gridSize (1,2) double {mustBeInteger, mustBePositive}
        imageSize (1,2) double {mustBeInteger, mustBePositive}
        pixelPadding (1,1) double {mustBeInteger, mustBeNonnegative}
        plotOrder {mustBeTextScalar}
    end

    numRows = gridSize(1);
    numColumns = gridSize(2);

    % Pixel coordinate of the first column/row of each tile
    x0 = ((1:numColumns) - 1) .* (imageSize(2) + pixelPadding) + 1;
    y0 = ((1:numRows) - 1) .* (imageSize(1) + pixelPadding) + 1;

    % Pixel coordinates covered by each tile column/row
    X = arrayfun(@(x) (x-1) + (1:imageSize(2)), x0, 'UniformOutput', false);
    Y = arrayfun(@(y) (y-1) + (1:imageSize(1)), y0, 'UniformOutput', false);

    tileOrder = 1:numRows*numColumns;
    switch lower(char(plotOrder))
        case 'columnwise'
            tileOrder = reshape(tileOrder, numRows, numColumns);
        case 'rowwise'
            tileOrder = reshape(tileOrder, numColumns, numRows)';
        otherwise
            error('uim:graphics:InvalidPlotOrder', ...
                'plotOrder must be ''rowwise'' or ''columnwise''; got "%s".', ...
                char(plotOrder))
    end

    fullSize = uim.graphics.internal.tileGridPixelSize(...
        gridSize, imageSize, pixelPadding);

    layout = struct(...
        'TileIndices', {cell(size(tileOrder))}, ...
        'TileCorners', zeros(numel(tileOrder), 2), ...
        'TileIndexMap', nan(fullSize));

    for j = 1:size(tileOrder, 1)
        for i = 1:size(tileOrder, 2)
            tileNum = tileOrder(j, i);
            [ii, jj] = meshgrid(X{i}, Y{j});
            layout.TileIndices{tileNum} = sub2ind(fullSize, jj, ii);
            layout.TileCorners(tileNum, :) = [X{i}(1), Y{j}(1)];
            layout.TileIndexMap(Y{j}, X{i}) = tileNum;
        end
    end
end
