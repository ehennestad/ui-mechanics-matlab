function varargout = circle(radius, numCornerSegmentPoints)
%circle Outline coordinates of a circle
%
%   edgeCoordinates = uim.shape.circle(radius) returns the outline of a
%   circle of the given radius (default 10) as an n-by-2 array of [x, y]
%   points. The circle lies in the first quadrant, touching both axes,
%   so its centre is at [radius, radius]. The outline starts near the top
%   left, runs counterclockwise and ends on its first point.
%
%   [xCoords, yCoords] = uim.shape.circle(radius) returns the x and y
%   coordinates as separate row vectors.
%
%   [...] = uim.shape.circle(radius, numCornerSegmentPoints) sets the
%   number of points per quarter circle (default 25), so the outline has
%   4*numCornerSegmentPoints + 1 points.
%
%   See also uim.shape.rectangle

%   Written by Eivind Hennestad | Vervaeke Lab

    if nargin < 2; numCornerSegmentPoints = 25; end
    if nargin < 1; radius = 10; end

    varargout = cell(1, nargout);

    [varargout{:}] = uim.shape.rectangle([radius*2, radius*2], radius, numCornerSegmentPoints);
end
