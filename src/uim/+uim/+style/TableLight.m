classdef TableLight < uim.style.TableTheme
%TableLight Table palette for light backgrounds
%
%   Near-white header and body with dark text, and an amber selection.

    properties (Constant)

        % Column header fill
        HeaderBackgroundColor = [0.95, 0.95, 0.95]
        % Column header text
        HeaderForegroundColor = [0.05, 0.05, 0.05]
        % Table body fill
        TableBackgroundColor = [0.95, 0.95, 0.95]
        % Table body text
        TableForegroundColor = [0.05, 0.05, 0.05]
        % Fill of selected rows
        TableBackgroundColorSelected = [240,171,15] ./ 255
        % Text of selected rows
        TableForegroundColorSelected = [0.95, 0.95, 0.95]
        % Table body fill while the table is disabled (not part of TableTheme)
        TableBackgroundColorDisabled = [0.85, 0.85, 0.85]
        % Table body text while the table is disabled (not part of TableTheme)
        TableForegroundColorDisabled = [0.15, 0.15, 0.15]
        % Fill of cells whose value has not been edited
        CellColorUnmodified = [1, 1, 1]
        % Fill of cells whose value has been edited
        CellColorModified = [1, 1, 1]
        % Grid lines between cells
        GridColor = [0.9, 0.9, 0.9]
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
