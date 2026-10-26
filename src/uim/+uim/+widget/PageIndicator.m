classdef PageIndicator < uim.abstract.Control
%PageIndicator Row of dots for switching between pages or views
%
%   A page indicator draws one round dot per page on a component canvas.
%   The dot of the current page is filled with BarColor; the others use
%   IndicatorColor. A horizontal bar runs above the dots, a vertical tick
%   joins it to the current dot, and the current page's name is shown as
%   a label. Clicking a dot switches page and calls ChangePageFcn, so the
%   host can show the matching view, as in a wizard or a set of image
%   tabs. Hovering over a dot shows that page's name.
%
%   pages = uim.widget.PageIndicator(parent, pageNames) creates an
%   indicator with one dot per entry in pageNames, a cell array of
%   character vectors or strings, with the first page current. parent is
%   a uim.UIComponentCanvas, a uim container, an axes (an overlay canvas
%   is created or reused), or a graphics container such as a uipanel.
%
%   pages = uim.widget.PageIndicator(parent, pageNames, Name=Value) also
%   sets public properties, including the layout properties inherited
%   from uim.abstract.Component (Location, Margin, Size, ...). Example:
%
%       pages = uim.widget.PageIndicator(canvas, {"One", "Two", "Three"}, ...
%           TextVisibility="hit", BarVisibility="off");
%       pages.ChangePageFcn = @(src, evt) disp(evt.NewPageNumber);
%
%   Change the page from code with changePage or by assigning
%   CurrentPage. PageNames and IndicatorSize are read only when the dots
%   are created. Setting Visible to 'on' shows the dots and applies
%   BarVisibility and TextVisibility again.
%
%   See also uim.UIComponentCanvas, uim.event.EventData

    % Todo: generalize so that it can be used as tab header for tabgroups

    properties (Constant)
        Type = 'PageIndicator' % Component type name
    end

    properties
       PageNames = {''} % Cell array of page names, one dot per name; read when the dots are created

       % CurrentPage - Index of the current page. Assigning it updates the
       % dots, tick and label as changePage does, without ChangePageFcn.
       CurrentPage = 1;

       FontColor = 'k' % Colour of the page name labels
       FontSize = 12 % Font size of the page name labels, in pixels
       IndicatorSize = 10 % Dot diameter in pixels; read when the dots are created
       IndicatorColor = ones(1,3) * 0.5 % Fill colour of the dots of pages other than the current one

       % BarColor - Colour of the bar, the tick, the current page's dot and
       % the outline of a hovered dot
       BarColor = 'k'

       % BarVisibility - 'on' or 'off' (true or false is accepted). With
       % 'off', the bar and tick are hidden and labels are centred
       % vertically on their position instead of sitting above it.
       BarVisibility = 'on'

       % TextVisibility - When page names are shown: 'on' shows the current
       % page's name, or the hovered page's name while a dot is hovered;
       % 'hit' shows a name only while its dot is hovered; 'off' never
       % shows names. true or false is accepted for 'on' or 'off'.
       TextVisibility = 'on';

       % HorizontalTextAlignment - 'left', 'center' or 'right': the labels
       % are aligned to the left end, middle or right end of the bar
       HorizontalTextAlignment = 'center';

       Spacing = 8 % Not used; the gap between dots is 3/8 of IndicatorSize

       % ChangePageFcn - Function called as ChangePageFcn(pages, evtData)
       % when the user clicks a dot, also when BlockChangePage is true.
       % evtData is a uim.event.EventData with fields OldPageNumber and
       % NewPageNumber.
       ChangePageFcn = [];

       % BlockChangePage - If true, clicking a dot does not change the page;
       % ChangePageFcn is still called, so the host can decide and call
       % changePage itself
       BlockChangePage = false;
    end

    properties (Hidden, Access = private, Transient)
        PageButtons = gobjects(0)
        PageLabels = gobjects(0)
        HorizontalBar = gobjects(0)
        VerticalBars = gobjects(0)
    end

    methods

        function obj = PageIndicator(hParent, pageNames, propertyValues)
        %PageIndicator Create a page indicator
        %
        %   pages = uim.widget.PageIndicator(parent, pageNames, Name=Value)
        %
        %   See the class help for the accepted parents and options.

            arguments
                hParent
                pageNames
                propertyValues.?uim.widget.PageIndicator
            end

            obj@uim.abstract.Control(hParent, propertyValues)

            obj.PageNames = pageNames;

            obj.createIndicator()

            obj.IsConstructed = true;
        end

        function delete(obj)
            delete(obj.PageButtons)
            delete(obj.PageLabels)
            delete(obj.HorizontalBar)
            delete(obj.VerticalBars)
        end
    end

    methods % Set property values

        function set.CurrentPage(obj, newValue)
            oldValue = obj.CurrentPage;
            obj.CurrentPage = newValue;
            % Before the dots exist, createIndicator draws the current page
            if obj.IsConstructed
                obj.onCurrentPageChanged(oldValue)
            end
        end

        function set.BarColor(obj, newValue)

            obj.BarColor = newValue;
            obj.onAppearanceChanged()
        end

        function set.BarVisibility(obj, newValue)
            if islogical(newValue)
                if newValue; newValue = 'on'; else; newValue = 'off'; end
            end
            newValue = validatestring(newValue, {'on', 'off'});
            obj.BarVisibility = newValue;
            obj.onBarVisibilityChanged()
        end

        function set.TextVisibility(obj, newValue)
            if islogical(newValue)
                if newValue; newValue = 'on'; else; newValue = 'off'; end
            end

            newValue = validatestring(newValue, {'on', 'hit', 'off'});
            obj.TextVisibility = newValue;
            obj.onTextVisibilitySet()
        end

        function set.HorizontalTextAlignment(obj, newValue)
            newValue = validatestring(newValue, {'left', 'center', 'right'});
            obj.HorizontalTextAlignment = newValue;
            obj.onHorizontalTextAlignmentSet()
        end

        function set.FontColor(obj, newValue)

            obj.FontColor = newValue;
            obj.onAppearanceChanged()
        end

        function set.FontSize(obj, newValue)
            obj.onSetFontSize(newValue)
            obj.FontSize = newValue; % only set prop if above does not fail
        end

        function set.IndicatorColor(obj, newValue)
            obj.IndicatorColor = newValue;
            obj.onAppearanceChanged()
        end
    end

    methods (Access = private)

        function createIndicator(obj)

            R = obj.IndicatorSize/2;
            S = R*3/4;

            pos = obj.Position(1:2);

            xInit = pos(1);

            [X,Y] = uim.shape.circle(R);

            % Coordinates for bars:
            y1 = pos(2) + max(Y);
            y2 = pos(2)+3*R;

            for i = 1:numel(obj.PageNames)

                X_ = X + pos(1);
                Y_ = Y + pos(2);

                obj.PageButtons(i) = patch(obj.CanvasAxes, X_, Y_, obj.IndicatorColor);
                obj.setPointerBehavior(obj.PageButtons(i))
                obj.PageButtons(i).ButtonDownFcn = @obj.onPageButtonPressed;

                % Todo: Use a button
% %                 h = uim.control.Button(obj.Parent, ...
% %                     'Position', [pos(1:2)+10, 10*R, 10*R], 'Size', [2*R, 2*R], ...
% %                     'PositionMode', 'manual', 'CornerRadius', 6, 'Style', uim.style.ButtonScheme);

                obj.PageLabels(i) = text(obj.CanvasAxes, pos(1), pos(2)+3*R, obj.PageNames{i}, 'Color', obj.FontColor);
                obj.PageLabels(i).FontUnits = 'pixel';

                obj.VerticalBars(i) = plot(obj.CanvasAxes, ones(1,2)*(pos(1)+R), [y1, y2]);

                if i == obj.CurrentPage
                    obj.PageButtons(i).FaceColor = obj.BarColor;
                else
                    obj.PageLabels(i).Visible = 'off';
                    obj.VerticalBars(i).Visible = 'off';
                end

                pos(1) = pos(1) + 2*R + S;
            end

            xEnd = pos(1) - S;
            obj.HorizontalBar = plot(obj.CanvasAxes, [xInit, xEnd], ones(1,2) * y2 );

            set([obj.HorizontalBar, obj.VerticalBars], 'Color', obj.BarColor)
            set([obj.HorizontalBar, obj.VerticalBars], 'LineWidth', 1.5)
            set([obj.PageButtons, obj.VerticalBars], 'LineWidth', 1)

            set(obj.PageLabels, 'FontSize', obj.FontSize)

            obj.placeTextHorizontal()
            obj.placeTextVertical()
            obj.updateBarVisibility()
            obj.updateTextVisibility()
        end

        function shiftComponents(obj, shift)

            for i = 1:numel(obj.PageNames)
                obj.PageButtons(i).XData = obj.PageButtons(i).XData + shift(1);
                obj.PageButtons(i).YData = obj.PageButtons(i).YData + shift(2);
                obj.VerticalBars(i).XData = obj.VerticalBars(i).XData + shift(1);
                obj.VerticalBars(i).YData = obj.VerticalBars(i).YData + shift(2);
                obj.PageLabels(i).Position(1:2) = obj.PageLabels(i).Position(1:2) + shift(1:2);
            end

            obj.HorizontalBar.XData = obj.HorizontalBar.XData + shift(1);
            obj.HorizontalBar.YData = obj.HorizontalBar.YData + shift(2);
        end

        function placeTextHorizontal(obj)

            xData = obj.HorizontalBar.XData;

            switch obj.HorizontalTextAlignment
                case 'left'
                    xPos = min(xData);
                case 'center'
                    xData = obj.HorizontalBar.XData;
                    xPos = min(xData) + (max(xData)-min(xData)) / 2;
                case 'right'
                    xPos = max(xData);
            end

            for i = 1:numel(obj.PageLabels)
                obj.PageLabels(i).Position(1) = xPos;
            end

            set(obj.PageLabels, 'HorizontalAlignment', obj.HorizontalTextAlignment)
        end

        function placeTextVertical(obj)

            if strcmp(obj.BarVisibility, 'on')
                set(obj.PageLabels, 'VerticalAlignment', 'Bottom')
            elseif strcmp(obj.BarVisibility, 'off')
                set(obj.PageLabels, 'VerticalAlignment', 'Middle')
            end
        end
    end

    methods

        function updateBarVisibility(obj)
        %updateBarVisibility Show or hide the bar and tick from BarVisibility
        %
        %   pages.updateBarVisibility() hides the bar and all ticks when
        %   BarVisibility is 'off', and otherwise shows the bar and the
        %   tick of the current page only.

            if strcmp(obj.BarVisibility, 'off')
                set([obj.HorizontalBar, obj.VerticalBars], 'Visible', obj.BarVisibility)
            else
                set(obj.HorizontalBar, 'Visible', 'on')
                set(obj.VerticalBars, 'Visible', 'off')
                obj.VerticalBars(obj.CurrentPage).Visible = 'on';
            end
        end

        function updateTextVisibility(obj)
        %updateTextVisibility Show or hide page labels from TextVisibility
        %
        %   pages.updateTextVisibility() shows only the current page's
        %   label when TextVisibility is 'on', and hides all labels when it
        %   is 'hit' or 'off'.

            if strcmp(obj.TextVisibility, 'off')
                set(obj.PageLabels, 'Visible', 'off')

            elseif strcmp(obj.TextVisibility, 'on')
                set(obj.PageLabels, 'Visible', 'off')
                obj.PageLabels(obj.CurrentPage).Visible = 'on';

            elseif strcmp(obj.TextVisibility, 'hit')
                set(obj.PageLabels, 'Visible', 'off')
            end
        end

        function changePage(obj, newPageNumber)
        %changePage Make another page the current page
        %
        %   pages.changePage(pageNumber) makes page pageNumber current: its
        %   dot is filled with BarColor, and the tick and label follow the
        %   TextVisibility and BarVisibility settings.
        %
        %   pages.changePage("next") and pages.changePage("previous") step
        %   one page forward or back.
        %
        %   A page number outside 1 to numel(PageNames) is ignored, so
        %   "next" on the last page does nothing. changePage does not call
        %   ChangePageFcn.


            switch newPageNumber
                case 'next'
                    newPageNumber = obj.CurrentPage + 1;
                case 'previous'
                    newPageNumber = obj.CurrentPage - 1;
            end

            if newPageNumber < 1 || newPageNumber > numel(obj.PageNames)
                return
            end

            obj.CurrentPage = newPageNumber;
        end

        function onAppearanceChanged(obj)
        %onAppearanceChanged Reapply the colour properties to the graphics
        %
        %   pages.onAppearanceChanged() applies IndicatorColor, FontColor
        %   and BarColor. The set methods of these properties call it.

            if ~obj.IsConstructed; return; end

            set(obj.PageButtons, 'FaceColor', obj.IndicatorColor)
            set(obj.PageLabels, 'Color', obj.FontColor)
            set([obj.HorizontalBar, obj.VerticalBars], 'Color', obj.BarColor)
            obj.PageButtons(obj.CurrentPage).FaceColor = obj.BarColor;
        end

        function onBarVisibilityChanged(obj)
        %onBarVisibilityChanged Apply a new BarVisibility value
        %
        %   Called by the BarVisibility set method. Updates the vertical
        %   label alignment and the bar and tick visibility.
            if ~obj.IsConstructed; return; end
            obj.placeTextVertical()
            obj.updateBarVisibility()
        end

        function onTextVisibilitySet(obj)
        %onTextVisibilitySet Apply a new TextVisibility value
        %
        %   Called by the TextVisibility set method; see
        %   updateTextVisibility.
            if ~obj.IsConstructed; return; end
            if strcmp(obj.TextVisibility, 'hit')
                set(obj.PageLabels, 'Visible', 'off')
            end
            obj.updateTextVisibility()
        end

        function onHorizontalTextAlignmentSet(obj)
        %onHorizontalTextAlignmentSet Apply a new HorizontalTextAlignment value
        %
        %   Called by the HorizontalTextAlignment set method. Moves the
        %   labels to the left end, middle or right end of the bar.
            if ~obj.IsConstructed; return; end
            obj.placeTextHorizontal()
        end

        function onSetFontSize(obj, newValue)
        %onSetFontSize Apply a new font size to the page labels
        %
        %   pages.onSetFontSize(newValue) sets the label font size in
        %   pixels. Called by the FontSize set method.
            if ~obj.IsConstructed; return; end
            set(obj.PageLabels, 'FontSize', newValue)
        end

        function setPointerBehavior(obj, h)
        %setPointerBehavior Attach hover callbacks to a page dot
        %
        %   pages.setPointerBehavior(h) makes the pointer entering and
        %   leaving the graphics object h call the indicator's hover
        %   handlers, which highlight the dot and show its label.

            pointerBehavior.enterFcn    = @(s,e) obj.onMouseEntered(s, h);
            pointerBehavior.exitFcn     = @(s,e) obj.onMouseExited(s, h);
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.internal.setPointerBehavior(h, pointerBehavior)
        end

        function onPageButtonPressed(obj, src, ~)
        %onPageButtonPressed Handle a click on a page dot
        %
        %   pages.onPageButtonPressed(src, ~) is the ButtonDownFcn of each
        %   dot. It changes to the clicked page unless BlockChangePage is
        %   true, then calls ChangePageFcn with the old and the requested
        %   page number.

            oldPageNumber = obj.CurrentPage;
            newPageNumber = find( ismember(obj.PageButtons, src) );

            if ~obj.BlockChangePage
                obj.changePage(newPageNumber)
            end

            evtData = uim.event.EventData('OldPageNumber', oldPageNumber, ...
                'NewPageNumber', newPageNumber);

            if ~isempty(obj.ChangePageFcn)
                obj.ChangePageFcn(obj, evtData);
            end
        end
    end

    methods (Access = protected)
        function relocate(obj, shift)
            relocate@uim.abstract.Control(obj, shift)
            obj.shiftComponents(shift)
        end
    end

    methods (Access = private)

        function onCurrentPageChanged(obj, oldPageNumber)
        %onCurrentPageChanged Fill the current page's dot and show its tick and label
            if oldPageNumber <= numel(obj.PageButtons)
                obj.PageButtons(oldPageNumber).FaceColor = obj.IndicatorColor;
            end
            obj.PageButtons(obj.CurrentPage).FaceColor = obj.BarColor;
            % A hidden indicator stays hidden; onVisibleChanged applies
            % the bar and label settings when it is shown
            if strcmp(obj.Visible, 'on')
                obj.updateBarVisibility()
                obj.updateTextVisibility()
            end
        end
    end

    methods (Hidden, Access = protected)

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end

            if strcmp(obj.Visible, 'on')
                set(obj.PageButtons, 'Visible', 'on')
                % The bar, ticks and labels follow their own settings
                obj.updateBarVisibility()
                obj.updateTextVisibility()
            else
                set([obj.HorizontalBar, obj.VerticalBars, obj.PageButtons, obj.PageLabels], ...
                    'Visible', 'off')
            end
        end

        function onMouseEntered(obj, hFig, h)
            h.EdgeColor = obj.BarColor;
            hFig.Pointer = 'hand';

            isCurrent = ismember(obj.PageButtons, h);
            obj.PageLabels(obj.CurrentPage).Visible = 'off';
            if ~strcmp(obj.TextVisibility, 'off')
                obj.PageLabels(isCurrent).Visible = 'on';
            end
        end

        function onMouseExited(obj, hFig, h)
            h.EdgeColor = 'k';
            hFig.Pointer = 'arrow';

            isCurrent = ismember(obj.PageButtons, h);
            obj.PageLabels(isCurrent).Visible = 'off';
            if strcmp(obj.TextVisibility, 'on')
                obj.PageLabels(obj.CurrentPage).Visible = 'on';
            end
        end
    end
end
