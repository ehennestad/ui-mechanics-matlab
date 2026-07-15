%contrastSliderExample Contrast slider anchored inside an image axes
%
%   A uim.widget.ContrastSlider in the northeast corner of a data axes.
%   Dragging the knobs updates the axes CLim through LimitsChangedFcn;
%   the auto button asks the host for auto levels (here: the 1st-99th
%   percentile of the image), which the host pushes back through the
%   Limits property.
%
%   Run from anywhere in the repository; the script adds src/ to the
%   path if the toolbox is not already installed.

if ~exist('uim.UIComponentCanvas', 'class')
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')))
end

% A low-contrast image: most of the dynamic range is unused.
imageData = 100 + 30*mat2gray(peaks(500));

hFigure = figure('Name', 'Contrast slider example', 'Color', 'w');
hAxes = axes(hFigure);
imagesc(hAxes, imageData, [0, 255])
colormap(hAxes, 'gray')
title(hAxes, 'Drag the knobs, or press auto')

slider = uim.widget.ContrastSlider(hAxes, ...
    'Location', 'northeast', 'Margin', [10, 10, 10, 10], ...
    'DataLimits', [0, 255], 'Limits', [0, 255], ...
    'BackgroundColor', 'k', 'BackgroundAlpha', 0.5, ...
    'LimitsChangedFcn', @(~, evt) set(hAxes, 'CLim', evt.NewValue), ...
    'AutoRequestedFcn', @(src, ~) applyAutoLevels(src, hAxes, imageData));

function applyAutoLevels(slider, hAxes, imageData)
%applyAutoLevels Compute 1st-99th percentile limits and push them back
    sortedValues = sort(imageData(:));
    limitIndices = max(1, round([0.01, 0.99]*numel(sortedValues)));
    newLimits = sortedValues(limitIndices)';

    slider.Limits = newLimits;      % Update the widget (silent)
    set(hAxes, 'CLim', newLimits)   % Apply to the display
end
