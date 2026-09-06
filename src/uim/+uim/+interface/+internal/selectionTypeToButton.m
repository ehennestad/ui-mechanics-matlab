function buttonNumber = selectionTypeToButton(selectionType, modifiers)
%selectionTypeToButton Recover the mouse button from a figure SelectionType
%
%   buttonNumber = uim.interface.internal.selectionTypeToButton(...
%       selectionType, modifiers) returns 1 (left), 2 (middle) or 3
%   (right). 'extend' is shift+left or middle, so the figure's
%   CurrentModifier list is consulted to report shift+left as button 1,
%   matching the eventdata of an axes ButtonDownFcn. 'alt' (right or
%   ctrl+left) reports 3: on macOS ctrl+click is the secondary click, so
%   tools leave it to the context menu.

    arguments
        selectionType {mustBeTextScalar}
        modifiers = {}
    end

    modifiers = cellstr(modifiers);

    switch lower(char(selectionType))
        case 'alt'
            buttonNumber = 3;
        case 'extend'
            if any(strcmp(modifiers, 'shift'))
                buttonNumber = 1;
            else
                buttonNumber = 2;
            end
        otherwise
            buttonNumber = 1;
    end
end
