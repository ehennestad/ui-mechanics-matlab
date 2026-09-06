function [xCoords, yCoords] = knobOutline(center, radii, numPoints)
%knobOutline Closed elliptical outline for a slider knob
%
%   [xCoords, yCoords] = uim.widget.internal.knobOutline(center, radii)
%   returns the vertices of an ellipse centred on center ([x, y]) with the
%   given radii ([rx, ry]). A scalar radii draws a circle. Sliders that
%   draw into a caller-supplied data axes pass different radii per axis so
%   the knob stays round on screen.
%
%   [...] = knobOutline(center, radii, numPoints) sets the number of
%   vertices (default 200).

    arguments
        center (1,2) double
        radii (1,:) double {mustBeNonnegative}
        numPoints (1,1) double {mustBeInteger, mustBePositive} = 200
    end

    if isscalar(radii)
        radii = [radii, radii];
    end

    theta = linspace(0, 2*pi, numPoints);
    xCoords = center(1) + radii(1) .* cos(theta);
    yCoords = center(2) + radii(2) .* sin(theta);
end
