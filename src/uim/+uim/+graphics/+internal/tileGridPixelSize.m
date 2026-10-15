function pixelSize = tileGridPixelSize(gridSize, imageSize, pixelPadding)
%tileGridPixelSize Pixel size of a tile grid including the gaps between tiles
%
%   pixelSize = uim.graphics.internal.tileGridPixelSize(gridSize, ...
%       imageSize, pixelPadding) returns [height, width] in pixels of a
%   gridSize ([numRows, numColumns]) grid of imageSize ([height, width])
%   tiles separated by pixelPadding pixels.

    arguments
        gridSize (1,2) double {mustBeInteger, mustBePositive}
        imageSize (1,2) double {mustBeInteger, mustBePositive}
        pixelPadding (1,1) double {mustBeNonnegative}
    end

    pixelSize = gridSize .* imageSize + pixelPadding .* (gridSize - 1);
end
