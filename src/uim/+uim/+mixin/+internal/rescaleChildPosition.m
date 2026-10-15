function childPosition = rescaleChildPosition(childPosition, oldPosition, newPosition)
%rescaleChildPosition Move and scale a child rectangle with its resized parent
%
%   childPosition = uim.mixin.internal.rescaleChildPosition(...
%       childPosition, oldPosition, newPosition) returns the [x, y, w, h]
%   a child should take so that it keeps its proportional place inside a
%   parent that changed from oldPosition to newPosition. A pure move of
%   the parent moves the child by the same amount; a resize scales the
%   child's size and its offset from the parent's origin.

    arguments
        childPosition (1,4) double
        oldPosition (1,4) double
        newPosition (1,4) double
    end

    relativeGrowth = (newPosition(3:4) - oldPosition(3:4)) ./ oldPosition(3:4);
    shift = newPosition(1:2) - oldPosition(1:2);

    for dim = 1:2
        growth = relativeGrowth(dim);
        childPosition(dim + 2) = childPosition(dim + 2) + growth*childPosition(dim + 2);

        if shift(dim) == 0
            childPosition(dim) = childPosition(dim) ...
                + growth*(childPosition(dim) - newPosition(dim));
        else
            childPosition(dim) = childPosition(dim) + shift(dim) ...
                + growth*(childPosition(dim) + shift(dim) - newPosition(dim));
        end
    end
end
