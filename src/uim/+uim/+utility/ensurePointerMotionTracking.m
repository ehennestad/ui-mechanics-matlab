function ensurePointerMotionTracking(hFigure)
%ensurePointerMotionTracking Make CurrentPoint follow the mouse
%
%   ensurePointerMotionTracking(hFigure) assigns a no-op
%   WindowButtonMotionFcn when the figure has none. In java-based
%   figures (classic desktop) the figure — and axes — CurrentPoint only
%   updates during mouse motion while a WindowButtonMotionFcn is set;
%   widgets that read CurrentPoint from WindowMouseMotion listeners
%   (slider knobs, draggable outlines) silently freeze without one.
%
%   A user-assigned callback is left untouched, and the no-op stays for
%   the figure's lifetime (removing it when one widget is deleted could
%   break another widget that still needs it).

    arguments
        hFigure (1,1) matlab.ui.Figure
    end

    if isempty(hFigure.WindowButtonMotionFcn)
        hFigure.WindowButtonMotionFcn = @(~, ~) [];
    end
end
