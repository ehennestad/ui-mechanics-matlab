function icons = getDefaultIcons()
%getDefaultIcons Vector icons shipped with the toolbox
%
%   icons = uim.style.getDefaultIcons() returns a struct mapping icon
%   names to vector icon data, in the format accepted by the Button
%   Icon property (and uim.graphics.ImageVector): a struct with a
%   polyshape Shape and a Color. Icons are recolored by the consuming
%   button's ForegroundColor.
%
%   Shipped names match the pointer-tool mode keys, so
%   uim.interface.PointerToolBinding picks them up automatically:
%   'zoomIn', 'zoomOut', 'pan', 'crop'.
%
%   The icons were drawn by the toolbox author and are stored as
%   patch-ready vector data in resources/icons/icon_library.mat.

    persistent cachedIcons cachedFileDate

    toolboxSourceDir = fileparts(fileparts(fileparts(...
        mfilename('fullpath'))));
    iconFile = fullfile(toolboxSourceDir, 'resources', 'icons', ...
        'icon_library.mat');

    % Key the cache on the file timestamp, so an updated icon library
    % (e.g. after pulling a new toolbox version into a running session)
    % is picked up without requiring clear functions.
    fileInfo = dir(iconFile);
    if isempty(cachedIcons) || ~isequal(cachedFileDate, fileInfo.datenum)
        cachedIcons = load(iconFile);
        cachedFileDate = fileInfo.datenum;
    end

    icons = cachedIcons;
end
