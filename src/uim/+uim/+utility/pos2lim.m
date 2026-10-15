function limits = pos2lim(position)
%pos2lim Convert position rectangles to corner limits
%
%   limits = uim.utility.pos2lim(position) converts an n-by-4 array of
%   [x, y, width, height] rectangles to an n-by-4 array of
%   [xMin, yMin, xMax, yMax] corners, where xMax = x + width and
%   yMax = y + height.
%
%   Example:
%       uim.utility.pos2lim([10, 20, 30, 40])   % [10, 20, 40, 60]

    numRows = size(position, 1);
    limits = position(:, [1,2,1,2]) + [ zeros(numRows, 2),  position(:, 3:4)];
end
