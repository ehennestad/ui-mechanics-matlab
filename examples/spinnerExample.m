%spinnerExample Smoothing-window spinner anchored inside a plot axes
%
%   A uim.widget.Spinner in the northeast corner of a data axes controls
%   the moving-average window of a noisy signal. Click -/+ to step the
%   window size, or click the value itself to type one (opens a
%   temporary edit box).
%
%   Run from anywhere in the repository; the script adds src/ to the
%   path if the toolbox is not already installed.

if ~exist('uim.UIComponentCanvas', 'class')
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')))
end

rng(42) % Reproducible noise
x = linspace(0, 4*pi, 500);
noisySignal = sin(x) + 0.4*randn(size(x));

hFigure = figure('Name', 'Spinner example', 'Color', 'w');
hAxes = axes(hFigure);
plot(hAxes, x, noisySignal, 'Color', [0.8, 0.8, 0.8])
hold(hAxes, 'on')
hSmoothLine = plot(hAxes, x, noisySignal, 'LineWidth', 2);
title(hAxes, 'Use the spinner to set the smoothing window')

spinner = uim.widget.Spinner(hAxes, ...
    'Value', 1, 'Minimum', 1, 'Maximum', 101, 'Step', 10, ...
    'Format', '%d', ...
    'Location', 'northeast', ...
    'Margin', [10, 10, 10, 10], ...
    'Tooltip', 'Smoothing window (samples)', ...
    'ValueChangedFcn', ...
    @(src, evt) updateSmoothing(hSmoothLine, noisySignal, evt.NewValue));

updateSmoothing(hSmoothLine, noisySignal, spinner.Value)

function updateSmoothing(hLine, signal, windowSize)
    hLine.YData = movmean(signal, windowSize);
end
