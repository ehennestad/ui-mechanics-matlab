%dropdownExample Colormap selector anchored inside an image axes
%
%   A uim.widget.DropDown placed in the northwest corner of a data axes
%   (via the overlay canvas). Selecting an item applies the colormap to
%   the axes through ValueChangedFcn.
%
%   Run from anywhere in the repository; the script puts the toolbox
%   source first on the path.

% Put this repository's source first on the path: an older uim package
% (e.g. NANSEN's bundled copy) may otherwise shadow it.
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')))

hFigure = figure('Name', 'DropDown example', 'Color', 'w');
hAxes = axes(hFigure);
imagesc(hAxes, peaks(200))
title(hAxes, 'Pick a colormap from the dropdown')

% Note: the overlay anchors to the axes Position rectangle. Under
% axis image/equal the visible plot box can be smaller than that
% rectangle, so widgets would anchor outside the image.

dropdown = uim.widget.DropDown(hAxes, ...
    'Items', ["gray", "parula", "jet", "hot", "bone"], ...
    'Value', "parula", ...
    'Location', 'northwest', ...
    'Margin', [10, 10, 10, 10], ...
    'ValueChangedFcn', @(src, evt) colormap(hAxes, char(evt.NewValue)));

colormap(hAxes, char(dropdown.Value))

% The list can also be driven programmatically:
%   dropdown.open()
%   dropdown.close()
%   dropdown.Value = "hot";   % updates silently (no callback)
