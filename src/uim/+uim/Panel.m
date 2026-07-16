classdef Panel < uim.abstract.Container

    properties (Constant)
        Type = 'Panel'
    end

    properties (SetAccess = protected, Transient)
        Children uim.abstract.Component
    end

    properties (Access = private)
        PanelHandle = []
    end

    methods % Structors
        function obj = Panel(hParent, varargin)
            obj@uim.abstract.Container(hParent, varargin{:})
            obj.IsConstructed = true;
        end
    end

    methods (Access = protected)
        function createBackground(obj)
            if isa(obj.Parent, 'uim.UIComponentCanvas')
                % The panel background is a real uipanel, which can not
                % live on a canvas (canvases only host plotted graphics).
                error('uim:Panel:CanvasParentNotSupported', ...
                    ['uim.Panel wraps a real uipanel and requires a ', ...
                     'figure, panel or tab parent. It can not be placed ', ...
                     'on a UIComponentCanvas or inside an axes.'])
            end
            obj.PanelHandle = uipanel(obj.Parent);
            obj.PanelHandle.BorderType = 'none';
            obj.PanelHandle.Units = 'pixel';
        end
    end

    methods (Access = protected)
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end

            updateSize@uim.abstract.Component(obj, mode)
            if ~isequal(obj.PanelHandle.Position, obj.Position)
                obj.PanelHandle.Position = obj.Position;
            end
        end

        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end

            updateLocation@uim.abstract.Component(obj, mode)
            if ~isequal(obj.PanelHandle.Position, obj.Position)
                obj.PanelHandle.Position = obj.Position;
            end
        end
    end

    methods (Access = protected)
        function onStyleChanged(obj)
            if obj.IsConstructed
                obj.PanelHandle.BackgroundColor = obj.BackgroundColor;
            end
        end

        function onVisibleChanged(obj, newValue)
            obj.PanelHandle.Visible = newValue;
        end
    end

    methods
        function hContainer = getGraphicsContainer(obj)
            hContainer = obj.PanelHandle;
        end
    end
end
