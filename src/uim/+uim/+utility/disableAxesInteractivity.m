function disableAxesInteractivity(hAxes)
%disableAxesInteractivity Turn off built-in interactions for a widget axes
%
%   disableAxesInteractivity(hAxes) disables the default axes
%   interactions (pan/zoom/datatip gestures) so that graphics objects
%   drawn as widget parts do not trigger MATLAB's built-in
%   data-exploration affordances when the user interacts with a widget.
%
%   Data tips need to be switched off separately from the default
%   interaction set: in the JavaScript-based figure desktop, clicking a
%   chart object pins a data tip even after disableDefaultInteractivity
%   has been called. The authoritative switch is
%   InteractionOptions.DatatipsSupported (R2023a and later).

    arguments
        hAxes (1,1) matlab.graphics.axis.Axes
    end

    disableDefaultInteractivity(hAxes)

    if isprop(hAxes, 'InteractionOptions')
        hAxes.InteractionOptions.DatatipsSupported = 'off';
    end
end
