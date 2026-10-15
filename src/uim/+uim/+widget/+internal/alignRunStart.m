function runStart = alignRunStart(availableStart, availableLength, runLength, alignment)
%alignRunStart Start coordinate of a run of items aligned within a span
%
%   runStart = uim.widget.internal.alignRunStart(availableStart, ...
%       availableLength, runLength, alignment) places a run of total
%   runLength inside the span [availableStart, availableStart +
%   availableLength]. alignment is 'left'/'top' (start), 'center'/'middle'
%   or 'right'/'bottom' (end). Toolbars use it to lay out their buttons
%   along the bar.

    arguments
        availableStart (1,1) double
        availableLength (1,1) double
        runLength (1,1) double
        alignment {mustBeTextScalar}
    end

    switch lower(char(alignment))
        case {'left', 'top'}
            runStart = availableStart;
        case {'center', 'middle'}
            runStart = availableStart + availableLength/2 - runLength/2;
        case {'right', 'bottom'}
            runStart = availableStart + availableLength - runLength;
        otherwise
            error("uim:alignRunStart:InvalidAlignment", ...
                "Alignment must be left/top, center/middle or right/bottom; got ""%s"".", ...
                char(alignment))
    end
end
