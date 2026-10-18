function pixelPosition = getContentPixelPosition(hParent)
%getContentPixelPosition Return the drawable content area of a UI container
%
%   pixelPosition = uim.utility.getContentPixelPosition(hParent) returns
%   [x, y, width, height] in pixels of the area where children of
%   hParent are laid out.
%
%   For a figure, getpixelposition returns the usable content bounds.
%   A panel lays out its children inside its border and title, and for
%   tabs getpixelposition can include the tab header while normalized
%   children are laid out below it. For panels and tabs the area a
%   normalized child fills is therefore measured, so pixel-positioned
%   children use the same bounds as normalized children. That position
%   is in the container's own frame, whose content starts at [1, 1].

    pixelPosition = getpixelposition(hParent);

    if ~isgraphics(hParent)
        return
    end

    if ~isa(hParent, 'matlab.ui.container.Tab') && ~isa(hParent, 'matlab.ui.container.Panel')
        return
    end

    measuredPosition = measureNormalizedChildPosition(hParent);
    if ~isempty(measuredPosition)
        pixelPosition = measuredPosition;
    end
end

function pixelPosition = measureNormalizedChildPosition(hParent)
    pixelPosition = [];
    hProbe = [];

    try
        hProbe = uipanel(hParent, ...
            'Units', 'normalized', ...
            'Position', [0, 0, 1, 1], ...
            'BorderType', 'none', ...
            'Visible', 'off', ...
            'Tag', 'uimContentPixelPositionProbe');

        drawnow limitrate
        measuredPosition = getpixelposition(hProbe);

        % On some platforms a panel border measures a fraction of a
        % pixel, while components are laid out in whole pixels
        if all(measuredPosition(3:4) > 0)
            pixelPosition = round(measuredPosition);
        end
    catch
        pixelPosition = [];
    end

    if ~isempty(hProbe) && isvalid(hProbe)
        delete(hProbe)
    end
end
