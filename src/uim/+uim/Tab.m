classdef Tab < uim.Handle & uim.mixin.NameValueAssignable
%Tab Logical wrapper registering a titled panel with a tabgroup.
%
%   A tab has no position/style of its own - all drawing is delegated to
%   its Panel. Parent refers to the owning tabgroup object (not a
%   graphics handle), since a tab needs to call tabgroup-specific
%   methods (addTab, updateTabTitle) on it.

    properties
        Parent = []
        Title = ''
        Panel = []
        BackgroundColor = [0.94, 0.94, 0.94] % uipanel does not support 'none'
    end

    properties (Access = protected)
        IsConstructed = false
    end

    methods
        function obj = Tab(hParent, varargin)

            % Assert that parent is a tabgroup.
            assertMsg = 'Parent must be an instance of uim.TabGroup';
            assert(isa(hParent, 'uim.TabGroup'), assertMsg)

            obj.Parent = hParent;
            obj.parseInputs(varargin{:});

            % Create tab panel (todo: Add more properties?)
            % Since tabgroup itself is a virtual container, need to add the
            % panel in the tabgroups parent handle
            obj.Panel = uim.Panel(obj.Parent.Parent, ...
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
            hContainer = obj.Panel.hPanel;
        end
    end
end
