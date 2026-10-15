function center = tileCenter(tileNum, numColumns, imageSize, pixelPadding, scaleFactor)
%tileCenter Axes coordinate of a tile's centre in a row-wise tile grid
%
%   center = uim.graphics.internal.tileCenter(tileNum, numColumns, ...
%       imageSize, pixelPadding, scaleFactor) returns the [x, y] axes
%   coordinate of the centre of tile tileNum, counting tiles row by row.
%   imageSize ([height, width]) and pixelPadding are in composite-image
%   pixels; scaleFactor ([height, width]) converts them to axes units.
%   The half pixel offset places the centre on MATLAB's pixel-centre
%   convention.

    arguments
        tileNum (1,1) double {mustBeInteger, mustBePositive}
        numColumns (1,1) double {mustBeInteger, mustBePositive}
        imageSize (1,2) double {mustBePositive}
        pixelPadding (1,1) double {mustBeNonnegative}
        scaleFactor (1,2) double {mustBePositive}
    end

    padding = pixelPadding ./ scaleFactor;
    tileSize = imageSize ./ scaleFactor;

    iRow = ceil(tileNum / numColumns);
    iCol = mod(tileNum - 1, numColumns) + 1;

    center = zeros(1, 2);
    center(1) = tileSize(2)*(iCol-1) + padding(2)*(iCol-1) + tileSize(2)/2;
    center(2) = tileSize(1)*(iRow-1) + padding(1)*(iRow-1) + tileSize(1)/2;

    center = center + 0.5;
end
