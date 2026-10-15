function [pos, siz] = subdividePosition(posInit, lengthInit, componentLengths, spacing, alignment)
%subdividePosition Lay out components along one dimension of a container
%
%   [pos, siz] = uim.utility.layout.subdividePosition(posInit,
%   lengthInit, componentLengths) distributes components along one
%   dimension of a container and returns the start position (pos) and
%   length (siz) of each, in pixels, as row vectors.
%
%   [pos, siz] = uim.utility.layout.subdividePosition(..., spacing,
%   alignment) also sets the gap between components and their alignment.
%
%   Input arguments:
%       posInit          - Position of the container start, in pixels.
%                          With 'left' alignment the first component
%                          starts at posInit + 1.
%       lengthInit       - Length available in the container, in pixels
%       componentLengths - Length of each component. A value above 1 is
%                          a length in pixels; a value of 1 or less is a
%                          fraction of the length left after the pixel
%                          lengths and the spacing are taken.
%       spacing          - (Optional) Gap between components in pixels.
%                          Default 10.
%       alignment        - (Optional) 'left' (default), 'center' or
%                          'right'. Moves the whole group. With 'right',
%                          pos(end) + siz(end) equals posInit +
%                          lengthInit, one pixel short of where a
%                          left-aligned group that fills the length ends
%                          (posInit + lengthInit + 1).
%
%   Lengths are rounded down to whole pixels. When fractional lengths are
%   present and the rounding leaves pixels unused, one pixel each is
%   added to the leading components so the group fills the length.
%
%   Example:
%       [pos, siz] = uim.utility.layout.subdividePosition(0, 100, [30, 1], 10)
%       % pos = [1, 41], siz = [30, 60]

    if nargin < 5; alignment = 'left'; end  % 'left', 'center', 'right'
    if nargin < 4; spacing = 10; end

    % Count number of panels
    numDivisions = numel(componentLengths);

    % Remove panel spacing from the available length
    availableLength = lengthInit - spacing*(numDivisions-1);

    if isempty(componentLengths)
        lengthPix = ones(1, numDivisions) .* availableLength ./ numDivisions;
    else
        if iscolumn(componentLengths); componentLengths = componentLengths'; end
        % Convert to pixels...

        % Initialize vector for panel lengths in pixels
        lengthPix = zeros(1, numDivisions);

        % Check if any size specs are in pixels
        isPixelSize = componentLengths > 1;
        lengthPix(isPixelSize) = componentLengths(isPixelSize);

        remainingLength = availableLength - sum(lengthPix);

        % Distribute remaining for panels specified in normalized
        % units
        lengthPix(~isPixelSize) = componentLengths(~isPixelSize) .* remainingLength;
    end

    % Get lengths for each panel and correct for rounding errors
    % by adding 1 pixel to each panel starting at first panel
    % and ending at the nth panel as needed to make sure panels
    % correctly fill the available length.

    lengthPix = floor( lengthPix ); % Round down
    rem = floor( availableLength - sum(lengthPix) ); % Get remainders

    % Only add these corrections if components "almost" fill entire length
    if rem < numDivisions && any(~isPixelSize)

        extra = zeros(1, numDivisions);
        extra(1:rem) = 1; % Distribute remainders

        siz = lengthPix + extra; % Add remainders to lengths

    else
        siz = lengthPix;
    end

    % Calculate the location values for all panels
    pos = cumsum( [1, siz(1:end-1)] ) + (0:numDivisions-1) .* spacing;

    switch alignment
        case 'left'
            % posInit is already left-aligned
        case 'center'
            totalSpacing = (numDivisions-1) .* spacing;
            totalComponentWidth = sum(siz);
            posInit = posInit + lengthInit/2 - (totalSpacing + totalComponentWidth)/2;
        case 'right'
            totalSpacing = (numDivisions-1) .* spacing;
            totalComponentWidth = sum(siz);
            posInit = posInit + (lengthInit - totalSpacing - totalComponentWidth) - 1;
    end

    pos = pos + posInit;

    if nargout == 1
        clear siz
    end
end
