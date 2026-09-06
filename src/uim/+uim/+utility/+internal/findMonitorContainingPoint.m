function monitorIndex = findMonitorContainingPoint(point, monitorPositions)
%findMonitorContainingPoint Index of the monitor whose bounds contain a point
%
%   monitorIndex = uim.utility.internal.findMonitorContainingPoint(point,
%       monitorPositions) returns the row of monitorPositions (n-by-4
%   [x, y, width, height] rectangles, as returned by the root
%   MonitorPositions property) that contains point ([x, y]), or NaN when
%   no monitor does. The first matching monitor wins.

    arguments
        point (1,2) double
        monitorPositions (:,4) double
    end

    monitorIndex = nan;

    for iMonitor = 1:size(monitorPositions, 1)
        if isPointInPosition(point, monitorPositions(iMonitor, :))
            monitorIndex = iMonitor;
            return
        end
    end
end

function tf = isPointInPosition(point, position)
%isPointInPosition True when point lies inside the rectangle position
    xLimits = [position(1), sum(position([1,3])) - 1];
    yLimits = [position(2), sum(position([2,4])) - 1];

    tf = point(1) >= xLimits(1) && point(1) <= xLimits(2) && ...
         point(2) >= yLimits(1) && point(2) <= yLimits(2);
end
