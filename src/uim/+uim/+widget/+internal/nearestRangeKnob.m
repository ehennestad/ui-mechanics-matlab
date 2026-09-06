function whichKnob = nearestRangeKnob(value, low, high)
%nearestRangeKnob Decide which range-slider knob a track press should move
%
%   whichKnob = uim.widget.internal.nearestRangeKnob(value, low, high)
%   returns 'low' or 'high': the knob closest to value. A value at or
%   below low always selects the low knob and a value at or above high the
%   high knob; ties inside the range go to the low knob.

    arguments
        value (1,1) double
        low (1,1) double
        high (1,1) double
    end

    if value <= low
        whichKnob = 'low';
    elseif value >= high
        whichKnob = 'high';
    elseif abs(value - low) > abs(value - high)
        whichKnob = 'high';
    else
        whichKnob = 'low';
    end
end
