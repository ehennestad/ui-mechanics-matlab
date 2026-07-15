function disableAxesInteractivity(hAxes)
%disableAxesInteractivity Turn off built-in interactions for a widget axes
%
%   disableAxesInteractivity(hAxes) disables the default axes
%   interactions (pan/zoom/datatip gestures) so that graphics objects
%   drawn as widget parts do not trigger MATLAB's built-in
%   data-exploration affordances when the user interacts with a widget.
%
%   Data tips need to be switched off separately from the default
%   interaction set: clicking a chart object pins a data tip even after
%   disableDefaultInteractivity has been called, and the switch that
%   governs this is InteractionOptions.DatatipsSupported (R2023a and
%   later). Setting it in a java-based figure (classic desktop) raises
%   the warning "InteractionOptions is only supported for web-based
%   figures" — both at set time and whenever the interaction system
%   re-applies the stored value — but the setting is effective there
%   regardless (observed on R2026a). Since the warning is spurious for
%   this use, it is disabled for the session the first time this
%   function runs.

    arguments
        hAxes (1,1) matlab.graphics.axis.Axes
    end

    disableDefaultInteractivity(hAxes)

    if isprop(hAxes, 'InteractionOptions')
        suppressUnsupportedFigureWarning()
        hAxes.InteractionOptions.DatatipsSupported = 'off';
    end

    % In java-based figures neither axes-level switch above stops
    % click-pinned data tips — tips still attach to objects in the axes
    % (observed on R2026a). Exclude every object drawn into the axes
    % from the data-cursor machinery instead. The listener's lifetime
    % is tied to the axes.
    excludeFromDataTips(hAxes.Children)
    addlistener(hAxes, 'ChildAdded', ...
        @(~, evt) excludeFromDataTips(evt.ChildNode));
end

function excludeFromDataTips(hObjects)
    for i = 1:numel(hObjects)
        try
            hBehavior = hggetbehavior(hObjects(i), 'DataCursor');
            hBehavior.Enable = false;
        catch
            % Object type without data-cursor behavior support; there is
            % nothing to exclude.
        end
    end
end

function suppressUnsupportedFigureWarning()
%suppressUnsupportedFigureWarning Silence the java-figure warning, once
    persistent isSuppressed
    if isempty(isSuppressed)
        warning('off', 'MATLAB:modes:InteractionOptions:UnsupportedOnJava')
        isSuppressed = true;
    end
end
