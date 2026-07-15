%zoomOverviewExample Zoom/pan toolbar with an interactive zoom outline
%
%   Combines two widgets inside a data axes:
%     - a uim.widget.Toolbar with zoom/pan pointer tools (northeast),
%       wired through uim.interface.PointerToolBinding;
%     - a uim.widget.OverviewIndicator (southeast) showing the full data
%       extent and the current view. Drag the view rectangle (or click
%       elsewhere in the frame) to move the view; zooming with the
%       tools or keyboard shortcuts (q/w/y) updates the outline.
%
%   Run from anywhere in the repository; the script adds src/ to the
%   path if the toolbox is not already installed.

if ~exist('uim.UIComponentCanvas', 'class')
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')))
end

hFigure = figure('Name', 'Zoom overview example', 'Color', 'w');
hAxes = axes(hFigure);
imagesc(hAxes, peaks(500))
title(hAxes, 'Zoom in, then drag the outline to move the view')

% Zoom/pan tools + toolbar
pointerManager = uim.interface.PointerManager(hFigure, hAxes, ...
    {'zoomIn', 'zoomOut', 'pan'});

toolbar = uim.widget.Toolbar(hAxes, ...
    'Location', 'northeast', 'Margin', [10, 10, 10, 10], ...
    'BackgroundAlpha', 0.5, 'NewButtonSize', [52, 22]);

binding = uim.interface.PointerToolBinding(toolbar, pointerManager, ...
    ["zoomIn", "zoomOut", "pan"], ...
    'Tooltips', struct('zoomIn', 'Zoom in (q)', ...
        'zoomOut', 'Zoom out (w)', 'pan', 'Pan (y)'));

hFigure.KeyPressFcn = @(src, evt) pointerManager.onKeyPress(src, evt);

% Interactive zoom outline: dragging the view rectangle moves the view.
indicator = uim.widget.OverviewIndicator(hAxes, ...
    'Location', 'southeast', 'Margin', [10, 10, 10, 10], ...
    'YDir', 'reverse', ...
    'DataLimits', [hAxes.XLim; hAxes.YLim], ...
    'ViewLimits', [hAxes.XLim; hAxes.YLim], ...
    'ViewChangedFcn', ...
    @(~, evt) set(hAxes, 'XLim', evt.XLim, 'YLim', evt.YLim));

% Keep the outline in sync when the zoom/pan tools change the view.
limitListener = addlistener(hAxes, {'XLim', 'YLim'}, 'PostSet', ...
    @(~, ~) updateOverview(indicator, hAxes));

function updateOverview(indicator, hAxes)
    indicator.ViewLimits = [hAxes.XLim; hAxes.YLim];
end
