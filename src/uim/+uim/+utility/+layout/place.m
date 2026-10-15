function place(hFigure, location, offset)
%place Move a figure to an edge, corner or the centre of its monitor
%
%   uim.utility.layout.place(hFigure, location) moves the figure, keeping
%   its size, on the monitor that uim.utility.getCurrentScreenSize reports
%   for it. location is one of:
%       'bottom', 'top'    - Align that edge; x is unchanged
%       'left', 'right'    - Align that edge; y is unchanged
%       'southwest', 'southeast', 'northwest', 'northeast'
%                          - Align the matching corner
%       'center'           - Centre the figure on the monitor
%   Any other value leaves the figure where it is. hFigure.Position must
%   be in pixels.
%
%   uim.utility.layout.place(hFigure, location, offset) adds offset
%   ([dx, dy], or a scalar for both) to the aligned position. The offset
%   is added for every location, so a positive offset moves a figure
%   placed at the top or right edge past that edge. 'center' ignores
%   offset.
%
%   Example:
%       uim.utility.layout.place(hFigure, "southwest", [3, 4])
%
%   See also uim.utility.centerFigureOnScreen,
%   uim.utility.getCurrentScreenSize

    if nargin < 3; offset = [0, 0]; end

    if isscalar(offset)
        offset = [offset, offset];
    end

    screenSize = uim.utility.getCurrentScreenSize(hFigure);

    switch location

        case 'bottom'
            hFigure.Position(2) = screenSize(2) + offset(2);

        case 'top'
            hFigure.Position(2) = screenSize(2) + screenSize(4) - hFigure.Position(4) + offset(2);

        case 'center'
            uim.utility.centerFigureOnScreen(hFigure)

        case 'left'
            hFigure.Position(1) = screenSize(1) + offset(1);

        case 'right'
            hFigure.Position(1) = screenSize(1) + screenSize(3) - hFigure.Position(3) + offset(1);

        case 'southeast'
            uim.utility.layout.place(hFigure, 'bottom', offset)
            uim.utility.layout.place(hFigure, 'right', offset)

        case 'southwest'
            uim.utility.layout.place(hFigure, 'bottom', offset)
            uim.utility.layout.place(hFigure, 'left', offset)

        case 'northeast'
            uim.utility.layout.place(hFigure, 'top', offset)
            uim.utility.layout.place(hFigure, 'right', offset)

        case 'northwest'
            uim.utility.layout.place(hFigure, 'top', offset)
            uim.utility.layout.place(hFigure, 'left', offset)
    end
end
