function toggleUicontrolLabel(h, strA, strB)
%toggleUicontrolLabel Swap one word for another in a menu item label
%
%   uim.utility.toggleUicontrolLabel(h, strA, strB) replaces strA with
%   strB in h.Text, or strB with strA when the label contains strB but
%   not strA. h is an object with a Text property, such as a uimenu.
%   An empty h does nothing.
%
%   Example:
%       menu = uimenu(hFigure, Text="Show grid");
%       uim.utility.toggleUicontrolLabel(menu, "Show", "Hide")
%       % menu.Text is now 'Hide grid'
%
%   A label that contains neither strA nor strB raises
%   uim:toggleUicontrolLabel:LabelNotFound.

    if isempty(h); return; end

    if contains(h.Text, strA)
        h.Text = strrep(h.Text, strA, strB);
    elseif contains(h.Text, strB)
        h.Text = strrep(h.Text, strB, strA);
    else
        error("uim:toggleUicontrolLabel:LabelNotFound", ...
            'Text labels are not present, something has gone wrong...')
    end
end
