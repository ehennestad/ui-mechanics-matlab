function change = clampScrollChange(change, currentPosition, maximum, visibleAmount)
%clampScrollChange Limit a scrollbar movement so the bar stays on its track
%
%   change = uim.widget.internal.clampScrollChange(change, currentPosition,
%       maximum, visibleAmount) reduces change so that the bar, whose
%   leading edge is at currentPosition, never moves below 0 or past
%   maximum - visibleAmount (the bar itself spans visibleAmount).

    arguments
        change (1,1) double
        currentPosition (1,1) double
        maximum (1,1) double
        visibleAmount (1,1) double
    end

    upperLimit = maximum - visibleAmount;

    if currentPosition + change < 0
        change = -currentPosition;
    elseif currentPosition + change >= upperLimit
        change = upperLimit - currentPosition;
    end
end
