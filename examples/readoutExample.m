%readoutExample Live pixel readout anchored inside an image axes
%
%   A uim.widget.Readout in the southwest corner of a data axes shows
%   the pixel value under the cursor, updated from the figure's
%   WindowButtonMotionFcn. The readout is display-only: the host pushes
%   values in through the Value property.
%
%   Run from anywhere in the repository; the script puts the toolbox
%   source first on the path.

% Put this repository's source first on the path: an older uim package
% (e.g. NANSEN's bundled copy) may otherwise shadow it.
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')))

imageData = peaks(200);

hFigure = figure('Name', 'Readout example', 'Color', 'w');
hAxes = axes(hFigure);
imagesc(hAxes, imageData)
title(hAxes, 'Move the cursor over the image')

readout = uim.widget.Readout(hAxes, ...
    'Label', 'Value', 'Format', '%.2f', ...
    'Location', 'southwest', ...
    'Margin', [10, 10, 10, 10], ...
    'Size', [110, 22]);

hFigure.WindowButtonMotionFcn = ...
    @(src, evt) updateReadout(readout, hAxes, imageData);

function updateReadout(readout, hAxes, imageData)
    point = round(hAxes.CurrentPoint(1, 1:2));
    if any(point < 1) || any(point > flip(size(imageData)))
        readout.Value = []; % Cursor outside the image
    else
        readout.Value = imageData(point(2), point(1));
    end
end
