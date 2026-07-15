classdef DropDown < uim.abstract.Control
%DropDown A popup selector for choosing one item from a list
%
%   dropdown = uim.widget.DropDown(hParent, Name, Value, ...) creates a
%   dropdown in hParent (a figure, panel, axes or uim canvas), e.g.:
%
%       dropdown = uim.widget.DropDown(hAxes, ...
%           'Items', ["gray", "jet", "parula"], 'Value', "gray", ...
%           'Location', 'northwest', ...
%           'ValueChangedFcn', @(src, evt) colormap(hAxes, evt.NewValue));
%
%   Clicking the control opens a list below it; clicking an item selects
%   it, closes the list, and notifies the host through ValueChangedFcn
%   with a uim.event.ValueChangedEventData (OldValue/NewValue).
%   Clicking anywhere else closes the list. The list can also be driven
%   programmatically with open() and close(). Programmatic assignment to
%   Value updates the display without firing the callback.
%
%   The open list is drawn on the widget's canvas with clipping off, so
%   it may extend below the canvas bounds (e.g. outside an overlay
%   canvas covering a data axes).
%
%   Todo:
%       [ ] Open upward when there is no room below the control.

    properties (Constant) % Inherited from Component
        Type = 'DropDown'
    end

    properties
        Items (1,:) string = string.empty  % The selectable items
        Value (1,1) string = ""            % The selected item (member of Items)

        ItemHeight (1,1) double {mustBePositive} = 20 % Row height of the open list, in pixels

        ValueChangedFcn = []    % Fired when the user selects an item. (src, uim.event.ValueChangedEventData)

        FontName = 'helvetica'
        FontSize = 12
    end

    properties (Dependent, Transient)
        ValueIndex  % Index of Value in Items (read-only)
        IsOpen      % True while the item list is showing (read-only)
    end

    properties (Access = protected, Transient)
        ValueText = gobjects(0,1)
        ArrowHandle = gobjects(0,1)

        ListBackground = gobjects(0,1)
        ItemPatches = gobjects(0,1)
        ItemTexts = gobjects(0,1)

        WindowMousePressListener
    end

    methods % Structors

        function obj = DropDown(hParent, varargin)

            obj@uim.abstract.Control(hParent, varargin{:})

            obj.plotClosedComponents()

            obj.IsConstructed = true;

            obj.updateValueText()
            obj.onVisibleChanged()

            % The background is the click target for opening the list.
            obj.Background.ButtonDownFcn = @(~, ~) obj.toggleList();
            obj.Background.HitTest = 'on';
            obj.Background.PickableParts = 'all';
        end

        function delete(obj)
            obj.close()

            handles = [obj.ValueText, obj.ArrowHandle];
            delete(handles(isvalid(handles)))
        end
    end

    methods % Public

        function open(obj)
        %open Show the item list below the control

            if obj.IsOpen || isempty(obj.Items); return; end

            obj.plotItemList()

            % Close when the user clicks anywhere outside the list.
            hFigure = ancestor(obj.Background, 'figure');
            obj.WindowMousePressListener = addlistener(hFigure, ...
                'WindowMousePress', @obj.onWindowMousePress);
        end

        function close(obj)
        %close Remove the item list

            if ~isempty(obj.WindowMousePressListener)
                delete(obj.WindowMousePressListener)
                obj.WindowMousePressListener = [];
            end

            % Deregister hover behavior before deleting the rows: the
            % pointer manager holds on to the registered callbacks, and
            % would keep invoking them on the deleted patches with every
            % mouse move otherwise.
            for i = 1:numel(obj.ItemPatches)
                if isvalid(obj.ItemPatches(i))
                    uim.utility.setPointerBehavior(obj.ItemPatches(i), [])
                end
            end

            handles = [obj.ListBackground, obj.ItemPatches, obj.ItemTexts];
            delete(handles(isvalid(handles)))

            obj.ListBackground = gobjects(0,1);
            obj.ItemPatches = gobjects(0,1);
            obj.ItemTexts = gobjects(0,1);
        end
    end

    methods % Set/Get

        function set.Items(obj, newValue)
            obj.Items = newValue;
            obj.validateValueInItems()
            obj.close()
        end

        function set.Value(obj, newValue)
            obj.assertValueIsMemberOfItems(newValue)
            obj.Value = newValue;
            obj.updateValueText()
        end

        function index = get.ValueIndex(obj)
            index = find(obj.Items == obj.Value, 1);
        end

        function tf = get.IsOpen(obj)
            tf = ~isempty(obj.ListBackground) && all(isvalid(obj.ListBackground));
        end
    end

    methods (Hidden, Access = protected)

        function plotClosedComponents(obj)

            obj.ValueText = text(obj.CanvasAxes, 0, 0, '');
            obj.ValueText.Interpreter = 'none';
            obj.ValueText.Color = obj.ForegroundColor;
            obj.ValueText.FontUnits = 'pixels';
            obj.ValueText.FontName = obj.FontName;
            obj.ValueText.FontSize = obj.FontSize;
            obj.ValueText.VerticalAlignment = 'middle';
            obj.ValueText.PickableParts = 'none';
            obj.ValueText.HitTest = 'off';

            obj.ArrowHandle = patch(obj.CanvasAxes, nan, nan, ...
                obj.ForegroundColor);
            obj.ArrowHandle.EdgeColor = 'none';
            obj.ArrowHandle.PickableParts = 'none';
            obj.ArrowHandle.HitTest = 'off';

            obj.updateComponentLocations()
        end

        function updateValueText(obj)
            if ~obj.IsConstructed || isempty(obj.ValueText); return; end
            obj.ValueText.String = char(obj.Value);
        end

        function updateComponentLocations(obj)

            if isempty(obj.ValueText); return; end

            x0 = obj.Position(1);
            yCenter = obj.Position(2) + obj.Position(4)/2;
            width = obj.Position(3);

            obj.ValueText.Position(1:2) = [x0 + obj.Padding(1), yCenter];

            % Downward-pointing triangle at the right edge.
            arrowHalfWidth = 4;
            arrowCenterX = x0 + width - obj.Padding(3) - arrowHalfWidth;
            obj.ArrowHandle.XData = arrowCenterX + [-1, 1, 0]*arrowHalfWidth;
            obj.ArrowHandle.YData = yCenter + [2, 2, -3];
        end

        function plotItemList(obj)

            x0 = obj.Position(1);
            width = obj.Position(3);
            listTop = obj.Position(2);
            listHeight = numel(obj.Items) * obj.ItemHeight;

            faceColor = obj.BackgroundColor;
            if strcmp(faceColor, 'none'); faceColor = [0.2, 0.2, 0.2]; end

            obj.ListBackground = patch(obj.CanvasAxes, ...
                x0 + [0, width, width, 0], ...
                listTop - [listHeight, listHeight, 0, 0], faceColor);
            obj.ListBackground.FaceAlpha = 0.9;
            obj.ListBackground.EdgeColor = obj.ForegroundColor;
            obj.ListBackground.LineWidth = 0.5;
            obj.ListBackground.Clipping = 'off';
            obj.ListBackground.HitTest = 'on';
            obj.ListBackground.PickableParts = 'all';

            numItems = numel(obj.Items);
            obj.ItemPatches = gobjects(1, numItems);
            obj.ItemTexts = gobjects(1, numItems);

            for i = 1:numItems
                rowTop = listTop - (i-1)*obj.ItemHeight;

                hRow = patch(obj.CanvasAxes, ...
                    x0 + [0, width, width, 0], ...
                    rowTop - [obj.ItemHeight, obj.ItemHeight, 0, 0], 'w');
                hRow.EdgeColor = 'none';
                hRow.FaceAlpha = 0.15 * (i == obj.ValueIndex);
                hRow.Clipping = 'off';
                hRow.HitTest = 'on';
                hRow.PickableParts = 'all';
                hRow.Tag = 'DropDownItem';
                hRow.UserData = i; % Item index, for hosts/tests locating rows
                hRow.ButtonDownFcn = @(~, ~) obj.onItemClicked(i);

                hText = text(obj.CanvasAxes, ...
                    x0 + obj.Padding(1), rowTop - obj.ItemHeight/2, ...
                    char(obj.Items(i)));
                hText.Interpreter = 'none';
                hText.Color = obj.ForegroundColor;
                hText.FontUnits = 'pixels';
                hText.FontName = obj.FontName;
                hText.FontSize = obj.FontSize;
                hText.VerticalAlignment = 'middle';
                hText.Clipping = 'off';
                hText.PickableParts = 'none';
                hText.HitTest = 'off';

                obj.setItemHoverBehavior(hRow, i)

                obj.ItemPatches(i) = hRow;
                obj.ItemTexts(i) = hText;
            end
        end

        function setItemHoverBehavior(obj, hRow, itemIndex)
        %setItemHoverBehavior Highlight rows on hover (needs IPT; optional)

            % Validity guards: the pointer manager can fire an exit
            % callback for the row the cursor was on while that row is
            % being deleted (e.g. clicking an item closes the list).
            pointerBehavior.enterFcn = @(~, ~) setRowFaceAlpha(hRow, 0.35);
            pointerBehavior.exitFcn = @(~, ~) setRowFaceAlpha(hRow, ...
                0.15 * (itemIndex == obj.ValueIndex));
            pointerBehavior.traverseFcn = [];

            uim.utility.setPointerBehavior(hRow, pointerBehavior)
        end

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end

            if strcmp(obj.Visible, 'off'); obj.close(); end

            obj.Background.Visible = obj.Visible;
            handles = [obj.ValueText, obj.ArrowHandle];
            set(handles(isvalid(handles)), 'Visible', obj.Visible)
        end
    end

    methods (Access = private) % User interactions

        function toggleList(obj)
            if obj.IsOpen
                obj.close()
            else
                obj.open()
            end
        end

        function onItemClicked(obj, itemIndex)

            oldValue = obj.Value;
            newValue = obj.Items(itemIndex);

            obj.close()

            if newValue == oldValue; return; end

            obj.Value = newValue;

            if ~isempty(obj.ValueChangedFcn)
                evtData = uim.event.ValueChangedEventData(oldValue, newValue);
                obj.ValueChangedFcn(obj, evtData)
            end
        end

        function onWindowMousePress(obj, ~, evt)
        %onWindowMousePress Close the list on clicks outside the widget

            ownGraphics = [obj.Background, obj.ListBackground, ...
                obj.ItemPatches];
            if any(evt.HitObject == ownGraphics); return; end

            obj.close()
        end

        function assertValueIsMemberOfItems(obj, newValue)
            if ~isempty(obj.Items) && ~any(obj.Items == newValue)
                error('uim:DropDown:InvalidValue', ...
                    ['"%s" is not a member of Items. Set Items first, ', ...
                     'then set Value to one of its elements.'], newValue)
            end
        end

        function validateValueInItems(obj)
        %validateValueInItems Reconcile Value with a new Items list

            if isempty(obj.Items); return; end

            if obj.Value == ""
                obj.Value = obj.Items(1);
            elseif ~any(obj.Items == obj.Value)
                error('uim:DropDown:InvalidValue', ...
                    ['The current Value ("%s") is not a member of the ', ...
                     'new Items list. Set Value to one of the new items ', ...
                     'first, or include it in Items.'], obj.Value)
            end
        end
    end

    methods (Access = protected)

        function onStyleChanged(obj)
            onStyleChanged@uim.abstract.Component(obj)

            if obj.IsConstructed && ~isempty(obj.ValueText)
                obj.ValueText.Color = obj.ForegroundColor;
                obj.ArrowHandle.FaceColor = obj.ForegroundColor;
            end
        end

        function onSizeChanged(obj, oldPosition, newPosition)
            onSizeChanged@uim.abstract.Control(obj, oldPosition, newPosition)
            obj.close()
            obj.updateComponentLocations()
        end

        function relocate(obj, shift)
            relocate@uim.abstract.Control(obj, shift)
            obj.close()
            obj.updateComponentLocations()
        end
    end

    methods (Static)

        function S = getTypeDefaults()
            S.IsFixedSize = [true, true];
            S.BackgroundColor = 'k';
            S.BackgroundAlpha = 0.6;
            S.CornerRadius = 3;
        end
    end
end

function setRowFaceAlpha(hRow, faceAlpha)
    if isvalid(hRow)
        hRow.FaceAlpha = faceAlpha;
    end
end
