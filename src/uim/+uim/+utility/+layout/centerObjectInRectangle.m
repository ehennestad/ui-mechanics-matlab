function centerObjectInRectangle(hContainer, position)
%centerObjectInRectangle Center a graphics object in a rectangle
%
%   uim.utility.layout.centerObjectInRectangle(hContainer, position)
%   moves hContainer, keeping its size, so it is centred in position.
%   hContainer is a graphics object with a Position property. position is
%   [x, y, width, height] with [x, y] the lower-left corner, in the same
%   units as hContainer.Position, or an object whose Position property
%   gives that rectangle.
%
%   When hContainer is a figure, its lower-left corner is kept on the
%   monitor that uim.utility.getCurrentScreenSize reports for it; the top
%   and right edges are not checked.
%
%   A non-numeric position without a Position property raises
%   uim:centerObjectInRectangle:InvalidPosition.
%
%   See also uim.utility.centerFigureOnScreen, uim.utility.layout.place

    if ~isnumeric(position)
        try
            position = position.Position;
        catch
            error("uim:centerObjectInRectangle:InvalidPosition", ...
                'Second argument should be a position or a graphical object with a Position property.')
        end
    end

    centerPoint = position(1:2) + position(3:4) / 2;
    newLocation = centerPoint - hContainer.Position(3:4) / 2;

    if isa(hContainer, 'matlab.ui.Figure')
        [screenSize, ~] = uim.utility.getCurrentScreenSize(hContainer);

        if any(newLocation < screenSize(1:2))
            newLocation = max([newLocation; screenSize(1:2)]);
        end
    end

    hContainer.Position(1:2) = newLocation;
end
