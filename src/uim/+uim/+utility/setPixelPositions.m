function setPixelPositions(h, position, recursive)
%setPixelPositions Set the pixel positions of one or more graphics objects
%
%   uim.utility.setPixelPositions(h, position) sets the position of each
%   object in the handle array h in pixel units. position has one
%   [x, y, width, height] row per handle. Each object's Units are restored
%   afterwards.
%
%   uim.utility.setPixelPositions(h, position, recursive) with recursive
%   true reads the positions relative to the figure instead of the parent.
%   All objects in h must then share a parent.
%
%   Example:
%       f = figure;
%       h = [uicontrol(f), uicontrol(f)];
%       uim.utility.setPixelPositions(h, [10, 10, 80, 20; 10, 40, 80, 20])
%
%   See also getpixelposition, setpixelposition

% Copyright 1984-2006 The MathWorks, Inc.

% Modified by Eivind Hennestad to allow handle to be an array of objects.

% Verify that setpixelposition is given between 2 and 3 arguments
narginchk(2,3)

% Verify that "h" is a handle
if ~all(ishghandle(h))
    error("uim:utility:setPixelPositions:InvalidHandle", ...
        "h must contain only graphics object handles.")
end

numHandles = numel(h);

% Verify that if "position" does exist it is a 1x4 numerical matrix
if ~(size(position,2) == 4 && size(position,1) == numHandles && isnumeric(position))
        error("uim:utility:setPixelPositions:InvalidPosition", ...
            "position is %d-by-%d. Supply one [x, y, width, height] row per " + ...
            "handle in h, a %d-by-4 numeric matrix.", ...
            size(position, 1), size(position, 2), numHandles)
end

if nargin < 3
    recursive = false;
end

if numHandles == 1
    setpixelposition(h, position, recursive)
    return
end

if recursive
    parent = get(h(1),'Parent');
    if ~ishghandle(parent,'figure')
        parentpos = getpixelposition(parent, true);
        position(:,1) = position(:,1) - parentpos(1);
        position(:,2) = position(:,2) - parentpos(2);
    end
end

old_u = get(h,'Units');
set(h,'Units','pixels');
wasError = false;
try
    h = reshape(h,[],1);
    position = mat2cell(position, ones(1,numHandles), 4);
    set(h,{'Position'}, position);
catch ex
    wasError = true;
end
set(h,{'Units'},old_u);
if wasError
    rethrow(ex);
end
end
