function excludeFromDataTips(hObjects)
%excludeFromDataTips Keep interactive data tips off widget graphics
%
%   excludeFromDataTips(hObjects) disables the data-cursor behavior on
%   each object. In java-based figures, clicking a graphics object pins
%   a data tip even when the object has its own ButtonDownFcn; the
%   behavior object is what the interactive data-cursor machinery
%   consults. HitTest, ButtonDownFcn and ContextMenu are unaffected.
%
%   Use this for widget graphics drawn into a caller-owned axes, where
%   the axes-level switches (see disableAxesInteractivity) must not be
%   touched. Note that the programmatic datatip() function bypasses the
%   behavior gate by design — this guards interactive clicks only.

    for i = 1:numel(hObjects)
        try
            hBehavior = hggetbehavior(hObjects(i), 'DataCursor');
            hBehavior.Enable = false;
        catch
            % Object type without behavior support; there is nothing to
            % exclude.
        end
    end
end
