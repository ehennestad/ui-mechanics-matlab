classdef TabGroup < uim.abstract.Container
%TabGroup Container with a bar of tab buttons that switch between pages
%
%   A canvas-drawn counterpart of MATLAB's uitabgroup. Its look is more
%   flexible, but it is slower to update on resize, because the tab bar
%   and background are plotted graphics.
%
%   tabGroup = uim.container.TabGroup(hParent) creates a tab group in
%   hParent. Add pages with uim.container.Tab(tabGroup, Title=title).
%   Tabs place their panels in the tab group's Parent, so hParent must
%   be a figure, uipanel or uitab for tabs to be added.
%
%   tabGroup = uim.container.TabGroup(hParent, Name=Value) also sets
%   properties. Besides the properties below, the name-value arguments
%   of uim.abstract.Component apply. The tab group's defaults differ
%   from Component's: Margin [20, 20, 20, 20], CornerRadius 10, an
%   opaque grey BackgroundColor ([0.39, 0.40, 0.41]) and MinimumSize
%   [100, 100].
%
%   The tab bar is a uim.widget.Toolbar, 20 pixels high, along the top
%   edge, with one toggle button per tab. Pressing the button of another
%   tab shows that tab's panel, hides the previous one, raises
%   SelectionChanged and then calls SelectionChangedFcn. Assigning
%   SelectedTab switches tabs the same way without SelectionChanged or
%   SelectionChangedFcn.
%
%   Example:
%       hFigure = figure();
%       tabGroup = uim.container.TabGroup(hFigure);
%       tabOne = uim.container.Tab(tabGroup, Title="One");
%       tabTwo = uim.container.Tab(tabGroup, Title="Two");
%       tabGroup.SelectionChangedFcn = @(src, evt) disp(evt.NewValue.Title);
%
%   See also uim.container.Tab, uim.container.Panel,
%   uim.event.TabSelectionChangedEvent, uitabgroup

    properties (Constant)
        Type = 'TabGroup' % Component type name
    end

    properties (Dependent)
        % Index of the selected tab: 1 once the first tab is added, [] before.
        % Assigning it shows that tab, as pressing its button does.
        SelectedTab
    end

    properties (Access = private)
        SelectedTab_ = [] % Value behind SelectedTab
    end

    properties (SetAccess = protected, Transient)
        Children uim.abstract.Component % Not filled by TabGroup; stays empty
    end

    properties
        % Not used; the tab bar is always drawn along the top edge.
        TabLocation = 'top' % Not priority.

        % Function called as fcn(tabGroup, evt) after the user selects
        % another tab. evt is a uim.event.TabSelectionChangedEvent.
        SelectionChangedFcn = []

        % 'shared' or 'private'. Read at construction only. Private gives
        % the tab button bar its own axes, stacked on top - use for
        % tabgroups whose own canvas is heavily used by other content.
        ToolbarCanvasMode = 'shared'
    end

    properties (Access = private, Hidden, Transient)
        % BackgroundDecoration
        TabToolBar

        TabButtonGroup uim.control.Button
        TabSeparators uim.decorator.Separator
        TabPanels uim.container.Panel

        Tabs uim.container.Tab
    end

    events
        SelectionChanged % User selected another tab. Data: uim.event.TabSelectionChangedEvent
    end

    methods %structor

        function obj = TabGroup(hParent, propertyValues)
        %TabGroup Create a tab group
        %
        %   tabGroup = uim.container.TabGroup(hParent, Name=Value) See the
        %   class help.

            arguments
                hParent
                propertyValues.?uim.container.TabGroup
                propertyValues.CanvasMode
            end

            obj@uim.abstract.Container(hParent, propertyValues)

            obj.IsConstructed = true;

            obj.createComponents()
        end
    end

    methods (Access = private) % Component creation

        function createComponents(obj)

            % Create background

            % Create toolbar / tabbar
            obj.createTabButtonBar()
        end

        function createTabButtonBar(obj)
        %createTabButtonBar Create bar with tab button group

            % Set toolbarheight and calculate margins based on tabgroup
            % container margins.
            toolbarHeight = 20;
            buttonGroupBackgroundColor = [71,73,75]./255;

            toolbarMargin = obj.Margin - [0,0,0,toolbarHeight/2];

            canvasMode = validatestring(obj.ToolbarCanvasMode, {'shared', 'private'});

            switch canvasMode
                case 'shared'
                    toolbarParent = obj.Canvas;
                    canvasModeArgs = {};
                case 'private'
                    toolbarParent = obj.Parent;
                    canvasModeArgs = {'CanvasMode', 'private', 'BarExtensionMode', 'expanded'};
            end

            hToolbar = uim.widget.Toolbar(toolbarParent, canvasModeArgs{:}, ...
                'Size', [inf, toolbarHeight], ...
                'Margin', toolbarMargin, ...
                'Padding', [1, 1, 1, 1], ...
                'Spacing', 1, ...
                'ComponentAlignment', 'left', ...
                'BackgroundColor', buttonGroupBackgroundColor, ...
                'BackgroundAlpha', 0.5, ...
                'NewButtonSize', [100, 18]);

            hToolbar.Location = 'northeast';
            hToolbar.ComponentAlignment = 'center';
            hToolbar.CornerRadius = 4;

            if strcmp(canvasMode, 'private')
                uistack(hToolbar.Canvas, 'top')
            end

            obj.TabToolBar = hToolbar;
        end

        function createTabButton(obj, hTab)
        %createTabButton Create new tab button for given tab

            buttonOptions = {'FontName', 'Lucida Grande', ...
                'Mode', 'togglebutton', ...
                'Style', uim.style.TabButton, ...
                'Padding', [5, 0, 5, 0], ...
                'HorizontalTextAlignment', 'center', ...
                'AutoWrapText', true, ...
                'Callback', @obj.onTabButtonPressed };

            numButtons = numel(obj.Tabs);
            iButton = numButtons + 1; % number for this button

            if iButton > 1 % Add a separator between buttons
                separatorOptions = {'Color', ones(1,3)*0.9, ...
                    'LineWidth', 0.5, 'Height', 0.5};
                hSep = obj.TabToolBar.addSeparator(separatorOptions{:});
                obj.TabSeparators(iButton-1) = hSep;

                % Separators should be invisible when right next to a
                % selected tab button
                if iButton == 2
                    hSep.Visible = 'off';
                end
            end

            % Add the button to the toolbar instance
            hBtn = obj.TabToolBar.addButton('String', hTab.Title, buttonOptions{:});

            % Add the button handle to tabButtonGroup property
            obj.TabButtonGroup(iButton) = hBtn;

            % Select button if it is the first button added.
            if iButton == 1
                obj.SelectedTab_ = 1;
                obj.TabButtonGroup(1).Value = true;
            end
        end
    end

    methods (Hidden)

        % Add tab
        function addTab(obj, hTab)
            obj.createTabButton(hTab)

            % Adjust tab panel size to fit within the tabgroup container.
            toolbarHeight = obj.TabToolBar.Size(2);
            panelMargin = obj.Margin + [5,5,5,5 + toolbarHeight/2];

            hTab.Panel.Margin = panelMargin;

            if numel(obj.Tabs)>=1
                obj.Tabs(end+1) = hTab;
                hTab.Panel.Visible = 'off';
            else
                obj.Tabs = hTab;
            end
        end

        function updateTabTitle(obj, hTab)
            tabNum = find(ismember(obj.Tabs, hTab));

            hBtn = obj.TabButtonGroup(tabNum);
            hBtn.String = hTab.Title;
        end

    end

    methods (Access = private)

        function changeTab(obj, panelNum)
            % need to be adapted. Taken from struct editor

            % Make sure all other tabs are not visible.
            set(obj.main.hPanel, 'Visible', 'off')
            obj.main.hPanel(panelNum).Visible = 'on';
            obj.currentPanel = panelNum;

            % Update header title
            obj.headerTitle.String = sprintf('Edit Preferences for %s', obj.Name{panelNum});

            % Create panel if it is opened for the first time.
            if ~obj.isTabCreated(panelNum)

                 % Create components
                obj.addComponents(panelNum)

                % Scroll to top, or align elements to top if all comps are
                % visible
                obj.visibleHeight(panelNum) = obj.main.hAxes(panelNum).Position(4); % Height of panel
                if obj.virtualHeight(panelNum) > obj.visibleHeight(panelNum)
                    obj.moveElementsToTop()
                end

                delete(obj.main.tmpPanel)
            end
        end

        function onTabButtonPressed(obj, src, ~)
        %onTabButtonPressed Callback handler for when a button is pressed

            % Determine which tab is selected
            nextTab = find(ismember(obj.TabButtonGroup, src));

            if isequal(nextTab, obj.SelectedTab_)
                % Selected same tab
                evtData = uim.event.ToggleEvent(1);
            else
                % Selected new tab
                evtData = uim.event.ToggleEvent(0);
            end

            % Change button state.
            obj.TabButtonGroup(obj.SelectedTab_).toggleState([], evtData)

            if ~isequal(nextTab, obj.SelectedTab_)
                args = {obj.Tabs(obj.SelectedTab_), obj.Tabs(nextTab)};
                evtData = uim.event.TabSelectionChangedEvent(args{:});
                obj.showTab(nextTab)
                obj.notify('SelectionChanged', evtData)

                if ~isempty(obj.SelectionChangedFcn)
                    obj.SelectionChangedFcn(obj, evtData)
                end
            end
        end
    end

    methods % Set/get

        function selectedTab = get.SelectedTab(obj)
            selectedTab = obj.SelectedTab_;
        end

        function set.SelectedTab(obj, newValue)
            assert(isscalar(newValue) && any(newValue == 1:numel(obj.Tabs)), ...
                "uim:TabGroup:InvalidSelectedTab", ...
                "SelectedTab must be the index of an existing tab (1 to %d).", numel(obj.Tabs))
            if isequal(newValue, obj.SelectedTab_); return; end

            % A user press toggles its own button; here both change
            obj.TabButtonGroup(obj.SelectedTab_).Value = false;
            obj.TabButtonGroup(newValue).Value = true;
            obj.showTab(newValue)
        end
    end

    methods (Access = private)

        function showTab(obj, nextTab)
        %showTab Show the panel of nextTab, hide the selected one, and select nextTab
            obj.Tabs(nextTab).Panel.Visible = 'on';
            obj.Tabs(obj.SelectedTab_).Panel.Visible = 'off';

            % Separators next to the selected tab are hidden
            for i = 1:numel(obj.TabSeparators)
                if i == nextTab || i == nextTab-1
                    obj.TabSeparators(i).Visible = 'off';
                else
                    obj.TabSeparators(i).Visible = 'on';
                end
            end

            obj.SelectedTab_ = nextTab;
        end
    end

    methods (Static, Access = protected)

        function S = getDefaultPropertyValues()

% %             S.PositionMode = 'auto';
% %             S.Location = 'northwest';

            S.IsFixedSize = [false, false];
% %             S.Size = [30, 30];

% %             S.HorizontalAlignment = 'left';
% %             S.VerticalAlignment = 'bottom';
% %
% %             S.Padding = [10, 3, 10, 3];

            S.MinimumSize = [100, 100];
            S.MaximumSize = [inf, inf];

            S.Margin = [20,20,20,20];
            S.CornerRadius = 10;
            S.BackgroundColor = [0.3922    0.4000    0.4078];
            S.BackgroundAlpha = 1;
        end
    end
end
