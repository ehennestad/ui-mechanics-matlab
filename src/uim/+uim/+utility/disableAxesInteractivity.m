function disableAxesInteractivity(hAxes)
%disableAxesInteractivity Turn off built-in interactions for a widget axes
%
%   disableAxesInteractivity(hAxes) disables the default axes
%   interactions (pan/zoom/datatip gestures) so that graphics objects
%   drawn as widget parts do not trigger MATLAB's built-in
%   data-exploration affordances when the user interacts with a widget.
%
%   Data tips need to be switched off separately from the default
%   interaction set in *web-based* figures (uifigures, and all figures
%   in the JavaScript-based desktop): there, clicking a chart object
%   pins a data tip even after disableDefaultInteractivity has been
%   called, and the authoritative switch is
%   InteractionOptions.DatatipsSupported (R2023a and later).
%
%   In java-based figures (classic desktop) that switch must NOT be
%   touched: InteractionOptions is unsupported there — setting it warns
%   ("InteractionOptions is only supported for web-based figures"), and
%   the stored value warns again every time the interaction system
%   re-applies it. disableDefaultInteractivity alone covers data tips
%   in java figures.

    arguments
        hAxes (1,1) matlab.graphics.axis.Axes
    end

    disableDefaultInteractivity(hAxes)

    if isprop(hAxes, 'InteractionOptions') && isWebFigure(hAxes)
        hAxes.InteractionOptions.DatatipsSupported = 'off';
    end
end

function tf = isWebFigure(hAxes)
    try
        tf = matlab.ui.internal.isUIFigure(ancestor(hAxes, 'figure'));
    catch
        % If the check is unavailable, set the option anyway; the worst
        % case is the warning this guard exists to avoid.
        tf = true;
    end
end
