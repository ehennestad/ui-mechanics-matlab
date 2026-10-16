classdef TableDark < uim.style.TableTheme
%TableDark Table palette for dark backgrounds
%
%   Near-black body with light text, and a slate blue selection.

    properties (Constant)

        % Column header fill
        HeaderBackgroundColor = [0.15, 0.15, 0.15]
        % Column header text
        HeaderForegroundColor = [0.95, 0.95, 0.95]
        % Table body fill
        TableBackgroundColor = [0.05, 0.05, 0.05]
        % Table body text
        TableForegroundColor = [0.85, 0.85, 0.85]
        % Fill of selected rows
        TableBackgroundColorSelected = [48,62,76]/255; %[240,171,15] ./ 255
        % Text of selected rows
        TableForegroundColorSelected = [0.95, 0.95, 0.95]
        % Table body fill while the table is disabled (not part of TableTheme)
        TableBackgroundColorDisabled = [0.15, 0.15, 0.15]
        % Table body text while the table is disabled (not part of TableTheme)
        TableForegroundColorDisabled = [0.75, 0.75, 0.75]
        % Fill of cells whose value has not been edited
        CellColorUnmodified = [0.15, 0.15, 0.15]
        % Fill of cells whose value has been edited
        CellColorModified = [0.15, 0.15, 0.15]
        % Grid lines between cells
        GridColor = [0.3, 0.3, 0.3]
        % Border around the table
        BorderColor = [240,171,15] ./ 255
        % Border width
        BorderWidth = 0
        % Colour of the column sort arrow
        SortArrowForeground = [240,171,15] ./ 255
        % Colour of the sort order indicator
        SortOrderForeground = [240,171,15] ./ 255
    end
end
