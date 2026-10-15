function [xCoords, yCoords] = cropMaskOutline(rectangle, imageSizeXY)
%cropMaskOutline Vertices of a patch that darkens everything outside a crop
%
%   [xCoords, yCoords] = uim.interface.internal.cropMaskOutline(rectangle,
%       imageSizeXY) returns the vertices of a single patch made of an
%   outer box around the whole image (imageSizeXY = [width, height])
%   followed by the inner crop rectangle ([x, y, width, height]) traced
%   in the opposite direction, so the crop region is a hole in the
%   patch.

    arguments
        rectangle (1,4) double
        imageSizeXY (1,2) double
    end

    innerX = rectangle(1) + [0, rectangle(3), rectangle(3), 0];
    innerY = rectangle(2) + [0, 0, rectangle(4), rectangle(4)];

    outerX = [0, imageSizeXY(1)+1, imageSizeXY(1)+1, 0, 0];
    outerY = [imageSizeXY(2)+1, imageSizeXY(2)+1, 0, 0, imageSizeXY(2)+1];

    xCoords = [outerX, innerX, innerX(1)];
    yCoords = [outerY, innerY, innerY(1)];
end
