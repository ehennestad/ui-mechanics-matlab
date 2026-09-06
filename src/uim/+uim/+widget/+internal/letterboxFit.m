function [scale, frameSize] = letterboxFit(dataSize, maxFrameSize)
%letterboxFit Largest aspect-preserving frame that fits inside a box
%
%   [scale, frameSize] = uim.widget.internal.letterboxFit(dataSize, ...
%       maxFrameSize) returns the pixels-per-data-unit scale that fits a
%   data extent of dataSize ([width, height]) inside maxFrameSize ([width,
%   height]) without distortion, and the resulting frameSize. One
%   dimension fills the box; the other is letterboxed.

    arguments
        dataSize (1,2) double {mustBePositive}
        maxFrameSize (1,2) double {mustBeNonnegative}
    end

    scale = min(maxFrameSize ./ dataSize);
    frameSize = dataSize .* scale;
end
