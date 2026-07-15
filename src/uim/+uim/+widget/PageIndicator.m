classdef PageIndicator < uim.abstract.Control
%PageIndicator Widget to switch between pages / views.
%
%   Creates a "button group" where each button has a label, and pressing
%   the button will invoke a callback with the index of the selected
%   button. Can be used for multi tab views or similar.

    % Todo: generalize so that it can be used as tab header for tabgroups

    properties (Constant)
        Type = 'PageIndicator'
    end

    properties
       PageNames = {''}
       CurrentPage = 1;
       FontColor = 'k'
       FontSize = 12
       IndicatorSize = 10
       IndicatorColor = ones(1,3) * 0.5
       BarColor = 'k'
       BarVisibility = 'on'
       TextVisibility = 'on'; % 'on', 'hit', 'off'
       HorizontalTextAlignment = 'center';
       Spacing = 8
       ChangePageFcn = [];
       BlockChangePage = false;
    end

    properties (Hidden, Access = private, Transient)
        PageButtons = gobjects(0)
        PageLabels = gobjects(0)
        HorizontalBar = gobjects(0)
        VerticalBars = gobjects(0)
    end

    methods

        function obj = PageIndicator(hParent, pageNames, varargin)
        %PageIndicator Construct instance of page indicator widget.

            obj@uim.abstract.Control(hParent, varargin{:})

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
            y1 = max(Y);
            y2 = pos(2)+3*R;

            for i = 1:numel(obj.PageNames)

                X_ = X + pos(1);
                Y_ = Y;

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

                if i == 1
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

        function restyle(obj)
        end

        function updateBarVisibility(obj)

            if strcmp(obj.BarVisibility, 'off')
                set([obj.HorizontalBar, obj.VerticalBars], 'Visible', obj.BarVisibility)
            else
                set(obj.HorizontalBar, 'Visible', 'on')
                set(obj.VerticalBars, 'Visible', 'off')
                obj.VerticalBars(obj.CurrentPage).Visible = 'on';
            end
        end

        function updateTextVisibility(obj)
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

            switch newPageNumber
                case 'next'
                    newPageNumber = obj.CurrentPage + 1;
                case 'previous'
                    newPageNumber = obj.CurrentPage - 1;
            end

            if newPageNumber < 1 || newPageNumber > numel(obj.PageNames)
                return
            end

            % Deactivate current page
            obj.PageButtons(obj.CurrentPage).FaceColor = obj.IndicatorColor;

            % Activate new page
            obj.PageButtons(newPageNumber).FaceColor = obj.BarColor;

            obj.CurrentPage = newPageNumber;
            obj.updateBarVisibility()
            obj.updateTextVisibility()
        end

        function onMouseOverIndicator(obj)
        end

        function onAppearanceChanged(obj)

            if ~obj.IsConstructed; return; end

            set(obj.PageButtons, 'FaceColor', obj.IndicatorColor)
            set(obj.PageLabels, 'Color', obj.FontColor)
            set([obj.HorizontalBar, obj.VerticalBars], 'Color', obj.BarColor)
            obj.PageButtons(obj.CurrentPage).FaceColor = obj.BarColor;
        end

        function onBarVisibilityChanged(obj)
            if ~obj.IsConstructed; return; end
            obj.placeTextVertical()
            obj.updateBarVisibility()
        end

        function onTextVisibilitySet(obj)
            if ~obj.IsConstructed; return; end
            if strcmp(obj.TextVisibility, 'hit')
                set(obj.PageLabels, 'Visible', 'off')
            end
            obj.updateTextVisibility()
        end

        function onHorizontalTextAlignmentSet(obj)
            if ~obj.IsConstructed; return; end
            obj.placeTextHorizontal()
        end

        function onSetFontSize(obj, newValue)
            if ~obj.IsConstructed; return; end
            set(obj.PageLabels, 'FontSize', newValue)
        end

        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of background.

            pointerBehavior.enterFcn    = @(s,e) obj.onMouseEntered(s, h);
            pointerBehavior.exitFcn     = @(s,e) obj.onMouseExited(s, h);
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.utility.setPointerBehavior(h, pointerBehavior)
        end

        function onPageButtonPressed(obj, src, ~)

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
        function onStyleChanged(obj)
        end

        function redraw(obj)
        end

        function relocate(obj, shift)
            relocate@uim.abstract.Control(obj, shift)
            obj.shiftComponents(shift)
        end
    end

    methods (Hidden, Access = protected)

        function onVisibleChanged(obj, ~)
            if obj.IsConstructed
                set(obj.HorizontalBar, 'Visible', obj.Visible)
                set(obj.PageButtons, 'Visible', obj.Visible)

                set(obj.VerticalBars(obj.CurrentPage), 'Visible', obj.Visible)
                set(obj.PageLabels(obj.CurrentPage), 'Visible', obj.Visible)
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
