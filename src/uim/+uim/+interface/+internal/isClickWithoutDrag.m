function tf = isClickWithoutDrag(anchor, point, xLim, yLim)
%isClickWithoutDrag True when a press/release pair barely moved
%
%   tf = uim.interface.internal.isClickWithoutDrag(anchor, point, xLim,
%       yLim) treats a movement smaller than one percent of the mean
%   axes extent (in data units) as a click rather than a drag, so a
%   slightly shaky click still triggers the click action.

    arguments
        anchor (1,2) double
        point (1,2) double
        xLim (1,2) double
        yLim (1,2) double
    end

    tolerance = mean([diff(xLim), diff(yLim)]) / 100;
    tf = all(abs(anchor - point) < tolerance);
end
