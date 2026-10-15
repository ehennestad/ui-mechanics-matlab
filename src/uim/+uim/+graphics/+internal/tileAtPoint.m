function tileNum = tileAtPoint(tileIndexMap, x, y, scaleFactor)
%tileAtPoint Tile number under an axes coordinate, NaN outside the grid
%
%   tileNum = uim.graphics.internal.tileAtPoint(tileIndexMap, x, y, ...
%       scaleFactor) looks up the tile at axes coordinate (x, y) in the
%   TileIndexMap produced by computeTileLayout. scaleFactor ([x, y], as
%   TiledImageAxes computes it) converts axes units to composite-image
%   pixels. Points outside the composite image, and points in the gaps
%   between tiles, return NaN.

    arguments
        tileIndexMap (:,:) double
        x (1,1) double
        y (1,1) double
        scaleFactor (1,2) double {mustBePositive}
    end

    column = round(x .* scaleFactor(1));
    row = round(y .* scaleFactor(2));

    [numRows, numColumns] = size(tileIndexMap);

    if column >= 1 && column <= numColumns && row >= 1 && row <= numRows
        tileNum = tileIndexMap(row, column);
    else
        tileNum = nan;
    end
end
