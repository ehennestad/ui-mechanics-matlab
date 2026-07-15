function setPointerBehavior(hObj, pointerBehavior)
%setPointerBehavior Set hover pointer behavior on an object, if possible.
%
%   uim.utility.setPointerBehavior(hObj, pointerBehavior) assigns the
%   given pointer behavior struct (or [] to clear it) to a graphics
%   object, using the Image Processing Toolbox pointer manager.
%
%   Hover pointer effects are cosmetic, so if the Image Processing
%   Toolbox is not installed this function silently does nothing and
%   widgets remain fully functional without them. This is the only
%   supported way for uim components to register pointer behavior; call
%   this rather than iptSetPointerBehavior/iptPointerManager directly.

    persistent hasPointerManager
    if isempty(hasPointerManager)
        hasPointerManager = exist('iptSetPointerBehavior', 'file') == 2;
    end
    if ~hasPointerManager; return; end

    iptSetPointerBehavior(hObj, pointerBehavior)

    % Clearing a behavior does not require the figure's pointer manager,
    % and during teardown the ancestor figure may already be gone.
    if ~isempty(pointerBehavior)
        hFigure = ancestor(hObj, 'figure');
        if ~isempty(hFigure)
            iptPointerManager(hFigure);
        end
    end
end
