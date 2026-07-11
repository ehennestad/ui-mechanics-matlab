classdef panel < uim.abstract.Container

    properties (Constant)
        Type = 'Panel'
    end

    properties (SetAccess = protected, Transient)
        Children uim.abstract.Component
    end

    properties
        hPanel = []
    end

    methods % Structors
        function obj = panel(hParent, varargin)
            obj@uim.abstract.Container(hParent, varargin{:})
            obj.IsConstructed = true;
        end
    end

    methods (Access = protected)
        function createBackground(obj)
            obj.hPanel = uipanel(obj.Parent);
            obj.hPanel.BorderType = 'none';
            obj.hPanel.Units = 'pixel';
        end
    end

    methods
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end

            updateSize@uim.abstract.Component(obj, mode)
            if ~isequal(obj.hPanel.Position, obj.Position)
                obj.hPanel.Position = obj.Position;
            end
        end

        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end

            updateLocation@uim.abstract.Component(obj, mode)
            if ~isequal(obj.hPanel.Position, obj.Position)
                obj.hPanel.Position = obj.Position;
            end
        end
    end

    methods (Access = protected)
        function onStyleChanged(obj)
            if obj.IsConstructed
                obj.hPanel.BackgroundColor = obj.BackgroundColor;
            end
        end

        function onVisibleChanged(obj, newValue)
            obj.hPanel.Visible = newValue;
        end
    end

    methods
        function hContainer = getGraphicsContainer(obj)
            hContainer = obj.hPanel;
        end
    end
end
