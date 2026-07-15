%pointerToolbarExample Zoom/pan toolbar anchored inside an image axes
%
%   A uim.widget.Toolbar in the northeast corner of a data axes, wired
%   to zoom/pan pointer tools through uim.interface.PointerToolBinding:
%   clicking a button toggles the tool, and toggling a tool by keyboard
%   shortcut (q/w/y) or programmatically updates the button states.
%
%   Run from anywhere in the repository; the script adds src/ to the
%   path if the toolbox is not already installed.

if ~exist('uim.UIComponentCanvas', 'class')
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')))
end

hFigure = figure('Name', 'Pointer toolbar example', 'Color', 'w');
hAxes = axes(hFigure);
imagesc(hAxes, peaks(500))
title(hAxes, 'Toggle a tool, then click/drag in the image')

pointerManager = uim.interface.PointerManager(hFigure, hAxes, ...
    {'zoomIn', 'zoomOut', 'pan'});

toolbar = uim.widget.Toolbar(hAxes, ...
    'Location', 'northeast', 'Margin', [10, 10, 10, 10], ...
    'BackgroundAlpha', 0.5);

% Buttons use the toolbox's shipped icons for these modes.
binding = uim.interface.PointerToolBinding(toolbar, pointerManager, ...
    ["zoomIn", "zoomOut", "pan"], ...
    'Tooltips', struct('zoomIn', 'Zoom in (q)', ...
        'zoomOut', 'Zoom out (w)', 'pan', 'Pan (y)'));

% Keyboard shortcuts toggle the tools AND update the button states.
hFigure.KeyPressFcn = @(src, evt) pointerManager.onKeyPress(src, evt);
