function anchor = boundingBoxAnchor(boundingBox, horizontalAlignment, verticalAlignment)
%boundingBoxAnchor Point of a bounding box named by an alignment pair
%
%   anchor = uim.graphics.internal.boundingBoxAnchor(boundingBox, ...
%       horizontalAlignment, verticalAlignment) returns the [x, y] of the
%   box ([x, y, width, height]) at the given alignment: 'left', 'center'
%   or 'right' horizontally and 'bottom', 'middle' or 'top' vertically.
%   Vector images are positioned by moving this anchor point.

    arguments
        boundingBox (1,4) double
        horizontalAlignment {mustBeTextScalar}
        verticalAlignment {mustBeTextScalar}
    end

    switch lower(char(horizontalAlignment))
        case 'left'
            x = boundingBox(1);
        case 'center'
            x = boundingBox(1) + boundingBox(3)/2;
        case 'right'
            x = boundingBox(1) + boundingBox(3);
        otherwise
            error("uim:graphics:InvalidAlignment", ...
                "Horizontal alignment must be 'left', 'center' or 'right'; got ""%s"".", ...
                char(horizontalAlignment))
    end

    switch lower(char(verticalAlignment))
        case 'bottom'
            y = boundingBox(2);
        case 'middle'
            y = boundingBox(2) + boundingBox(4)/2;
        case 'top'
            y = boundingBox(2) + boundingBox(4);
        otherwise
            error("uim:graphics:InvalidAlignment", ...
                "Vertical alignment must be 'bottom', 'middle' or 'top'; got ""%s"".", ...
                char(verticalAlignment))
    end

    anchor = [x, y];
end
