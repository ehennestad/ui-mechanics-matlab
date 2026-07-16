function createColormapList(parentMenu, targetAxes, options)
%CREATECOLORMAPLIST Add MATLAB colormap choices to a menu.

    arguments
        parentMenu (1,1) {mustBeMenuContainer}
        targetAxes (1,1) matlab.graphics.axis.AbstractAxes
        options.Separator (1,1) matlab.lang.OnOffSwitchState = "off"
    end

    menu = uimenu(parentMenu, "Text", "Set Colormap", ...
        "Separator", options.Separator);
    colormapNames = ["parula", "turbo", "jet", "hsv", "hot", "cool", ...
        "spring", "summer", "autumn", "winter", "gray", "bone", ...
        "copper", "pink"];

    for name = colormapNames
        item = uimenu(menu, "Text", name);
        item.MenuSelectedFcn = @(~,~) colormap(targetAxes, char(name));
    end
end

function mustBeMenuContainer(value)
    arguments
        value (1,1)
    end

    mustBeA(value, ["matlab.ui.container.Menu", ...
        "matlab.ui.container.ContextMenu"])
end
