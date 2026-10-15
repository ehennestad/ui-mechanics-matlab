classdef TableTheme < handle
%TableTheme Colours for the parts of a table
%
%   Supplies the colours of the header, the body, selected rows,
%   modified and unmodified cells, the grid, the border (with its width)
%   and the sort indicators. Subclass this to define a new table
%   palette.
%
%   See also uim.style.TableLight, uim.style.TableDark

    properties (Abstract, Constant)

        HeaderBackgroundColor
        HeaderForegroundColor
        TableBackgroundColor
        TableForegroundColor
        TableBackgroundColorSelected
        TableForegroundColorSelected
        CellColorUnmodified
        CellColorModified
        GridColor
        BorderColor
        BorderWidth
        SortArrowForeground
        SortOrderForeground
    end
end
