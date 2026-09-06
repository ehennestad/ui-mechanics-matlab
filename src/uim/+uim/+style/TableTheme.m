classdef TableTheme < handle
%TableTheme Colours for the parts of a table
%
%   Supplies header, body, selection and disabled colours, plus the
%   colours marking modified and unmodified cells. Subclass this to
%   define a new table palette.
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
