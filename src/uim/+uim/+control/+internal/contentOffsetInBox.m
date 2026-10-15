function offset = contentOffsetInBox(boxSize, contentSize, padding, horizontalAlignment, verticalAlignment)
%contentOffsetInBox Offset of aligned content (text, icon) inside a padded box
%
%   offset = uim.control.internal.contentOffsetInBox(boxSize, contentSize,
%       padding, horizontalAlignment, verticalAlignment) returns the [dx,
%   dy] of the content's lower-left corner relative to the box's
%   lower-left corner. padding is [left, bottom, right, top] in pixels.
%   horizontalAlignment is 'left', 'center' or 'right';
%   verticalAlignment is 'bottom', 'middle' or 'top'. Centred content
%   ignores the padding.

    arguments
        boxSize (1,2) double
        contentSize (1,2) double
        padding (1,4) double
        horizontalAlignment {mustBeTextScalar}
        verticalAlignment {mustBeTextScalar}
    end

    switch lower(char(horizontalAlignment))
        case 'left'
            dx = padding(1);
        case 'center'
            dx = (boxSize(1) - contentSize(1)) / 2;
        case 'right'
            dx = boxSize(1) - padding(3) - contentSize(1);
        otherwise
            error("uim:control:InvalidAlignment", ...
                "Horizontal alignment must be 'left', 'center' or 'right'; got ""%s"".", ...
                char(horizontalAlignment))
    end

    switch lower(char(verticalAlignment))
        case 'bottom'
            dy = padding(2);
        case 'middle'
            dy = (boxSize(2) - contentSize(2)) / 2;
        case 'top'
            dy = boxSize(2) - padding(4) - contentSize(2);
        otherwise
            error("uim:control:InvalidAlignment", ...
                "Vertical alignment must be 'bottom', 'middle' or 'top'; got ""%s"".", ...
                char(verticalAlignment))
    end

    offset = [dx, dy];
end
