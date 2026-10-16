classdef TableTheme < handle
%TableTheme Colours for the parts of a table
%
%   Supplies the colours of the header, the body, selected rows,
%   modified and unmodified cells, the grid, the border (with its width)
%   and the sort indicators. Subclass this to define a new table
%   palette. Colours are RGB triplets with values from 0 to 1.
%
%   No class in uim reads a TableTheme; it defines the palette contract
%   for table widgets built on uim.
%
%   See also uim.style.TableLight, uim.style.TableDark

    properties (Abstract, Constant)

        HeaderBackgroundColor           % Column header fill
        HeaderForegroundColor           % Column header text
        TableBackgroundColor            % Table body fill
        TableForegroundColor            % Table body text
        TableBackgroundColorSelected    % Fill of selected rows
        TableForegroundColorSelected    % Text of selected rows
        CellColorUnmodified             % Fill of cells whose value has not been edited
        CellColorModified               % Fill of cells whose value has been edited
        GridColor                       % Grid lines between cells
        BorderColor                     % Border around the table
        BorderWidth                     % Border width
        SortArrowForeground             % Colour of the column sort arrow
        SortOrderForeground             % Colour of the sort order indicator
    end
end
