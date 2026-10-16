classdef Tab < uim.Handle & uim.mixin.NameValueAssignable
%Tab Titled page of a uim.container.TabGroup
%
%   tab = uim.container.Tab(tabGroup) adds a tab to tabGroup.
%
%   tab = uim.container.Tab(tabGroup, Title=title, BackgroundColor=color)
%   also sets the button text and the color of the tab's panel.
%
%   Adding a tab creates a button in the tab group's button bar and a
%   uim.container.Panel for the tab's content. The panel is created in
%   the tab group's Parent, which must therefore be a figure, uipanel or
%   uitab, with margins that place it inside the tab group below the
%   button bar. The first tab added is shown; later tabs are hidden
%   until their button is pressed.
%
%   A tab has no position or style of its own; all drawing is delegated
%   to its Panel. Place content in the tab through the panel, either as
%   a component parent (uim.control.Button(tab.Panel, ...)) or through
%   tab.getGraphicsContainer(), which returns the panel's uipanel.
%
%   Parent refers to the owning tab group object (not a graphics
%   handle), since a tab needs to call tab-group methods (addTab,
%   updateTabTitle) on it. A parent that is not a
%   uim.container.TabGroup raises an assertion error.
%
%   Example:
%       hFigure = figure();
%       tabGroup = uim.container.TabGroup(hFigure);
%       tabOne = uim.container.Tab(tabGroup, Title="One");
%       tabTwo = uim.container.Tab(tabGroup, Title="Two");
%
%   See also uim.container.TabGroup, uim.container.Panel

    properties
        Parent = []     % Owning uim.container.TabGroup
        Title = ''      % Text of the tab button. Setting it updates the button.
        Panel = []      % uim.container.Panel holding the tab content, created by the constructor

        % Color of the tab's panel, applied at construction. uipanel does
        % not support 'none'.
        BackgroundColor = [0.94, 0.94, 0.94]
    end

    properties (Access = protected)
        IsConstructed = false
    end

    methods
        function obj = Tab(hParent, varargin)
        %Tab Create a tab in a tab group
        %
        %   tab = uim.container.Tab(tabGroup, Title=title) See the class
        %   help.

            % Assert that parent is a tabgroup.
            assertMsg = 'Parent must be an instance of uim.container.TabGroup';
            assert(isa(hParent, 'uim.container.TabGroup'), assertMsg)

            obj.Parent = hParent;
            obj.parseInputs(varargin{:});

            % Create tab panel (todo: Add more properties?)
            % Since tabgroup itself is a virtual container, need to add the
            % panel in the tabgroups parent handle
            obj.Panel = uim.container.Panel(obj.Parent.Parent, ...
                'BackgroundColor', obj.BackgroundColor);

            % Add tab to the tabgroup
            obj.Parent.addTab(obj)

            obj.IsConstructed = true;
        end

        function delete(obj)
            delete(obj.Panel)
        end
    end

    methods
        function set.Title(obj, newValue)
            obj.Title = newValue;

            if obj.IsConstructed
                obj.Parent.updateTabTitle(obj)
            end
        end
    end

    methods % Wrappers for placing matlab components
        function hContainer = getGraphicsContainer(obj)
        %getGraphicsContainer Return the uipanel that holds the tab content
        %
        %   hContainer = tab.getGraphicsContainer() returns the uipanel
        %   wrapped by the tab's Panel.
            hContainer = obj.Panel.getGraphicsContainer();
        end
    end
end
