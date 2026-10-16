function varargout = rectangle(boxSize, cornerRadius, numCornerSegmentPoints)
%rectangle Outline coordinates of a rectangle, optionally with rounded corners
%
%   edgeCoordinates = uim.shape.rectangle(boxSize) returns the four
%   corners of a box of size boxSize ([width, height], rounded to whole
%   numbers) with its lower-left corner at the origin, as a 4-by-2 array
%   of [x, y] points. The last point is not repeated.
%
%   [xCoords, yCoords] = uim.shape.rectangle(boxSize) returns the x and
%   y coordinates as separate row vectors.
%
%   [...] = uim.shape.rectangle(boxSize, cornerRadius) rounds the
%   corners with radius cornerRadius (default 0, square corners). The
%   rounded outline has 4*numCornerSegmentPoints + 1 points and ends on
%   its first point.
%
%   [...] = uim.shape.rectangle(boxSize, cornerRadius,
%   numCornerSegmentPoints) sets the number of points per rounded corner
%   (default 25). Higher values give smoother corners.
%
%   Coordinates start in the upper left corner and traverse the box
%   counterclockwise:
%
%        <--
%  ul _ _ _ _ _          y ^
%    |         | ^         |
%  | |         | |         |
%  v |_ _ _ _ _|            -------> x
%        -->               0

%   Written by Eivind Hennestad | Vervaeke Lab

    if nargin < 3; numCornerSegmentPoints = 25; end
    if nargin < 2; cornerRadius = 0; end

    boxSize = round(boxSize);

    if cornerRadius == 0
        xx = [0, 0, boxSize(1), boxSize(1)];
        yy = [boxSize(2), 0, 0, boxSize(2)];

    else

        numPoints = numCornerSegmentPoints * 4;
        segmentInd = repmat(1:4, numCornerSegmentPoints, 1);

        thetaOffset = (360 / numPoints) / 2;

        theta = linspace(thetaOffset, 360-thetaOffset, numPoints);
        theta = theta + 90; % 1str segment should be upper left
        theta = deg2rad(theta);

        rho = ones(size(theta)) .* cornerRadius;

        [xx, yy] = pol2cart(theta, rho);

        % Shift so that circle is in the 1st quadrant of the coordinate system
        xx = xx-min(xx); yy = yy-min(yy);

        isRightSide = segmentInd==3 | segmentInd==4;
        xx(isRightSide) = xx(isRightSide) + boxSize(1) - cornerRadius*2;

        isTopSide = segmentInd==1 | segmentInd==4;
        yy(isTopSide) = yy(isTopSide) + boxSize(2) - cornerRadius*2;

        xx(end+1) = xx(1);
        yy(end+1) = yy(1);
    end

if nargout == 1
    varargout = {[xx', yy']};
elseif nargout == 2
    varargout = {xx, yy};
end
