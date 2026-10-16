classdef Panel < uim.abstract.Container
%Panel Container that wraps a uipanel and follows the component layout
%
%   obj = uim.container.Panel(hParent, BackgroundColor=color) creates a
%   borderless uipanel (pixel units) in hParent and positions it with the
%   layout of uim.abstract.Component (Location, Margin, alignment,
%   auto size). hParent must be a figure, uipanel or uitab; an axes or a
%   uim.UIComponentCanvas raises uim:Panel:CanvasParentNotSupported.
%   Other name-value arguments set the properties described in
%   uim.abstract.Component.
%
%   Components created with the panel as parent are placed inside the
%   uipanel and draw on the uipanel's UIComponentCanvas.
%
%   Usage notes:
%       - Pass BackgroundColor at construction. The inherited default,
%         'none', is not a valid uipanel color, and construction fails
%         without it. Of the style properties, only BackgroundColor and
%         Visible affect the uipanel.
%       - Set Margin, Location, HorizontalAlignment and
%         VerticalAlignment after construction; passing them as
%         name-value arguments raises an error.
%       - The uipanel follows the automatic layout. Setting Position or
%         Size changes the property but does not move or resize the
%         uipanel.
%
%   Example:
%       hFigure = figure();
%       panel = uim.container.Panel(hFigure, BackgroundColor="w");
%       panel.Margin = [10, 10, 10, 10];
%
%   See also uim.abstract.Container, uim.container.Tab, uipanel

    properties (Constant)
        Type = 'Panel' % Component type name
    end

    properties (SetAccess = protected, Transient)
        Children uim.abstract.Component % Not filled by Panel; stays empty
    end

    properties (Access = private)
        PanelHandle = []
    end

    methods % Structors
        function obj = Panel(hParent, varargin)
        %Panel Create a panel container
        %
        %   obj = uim.container.Panel(hParent, BackgroundColor=color)
        %   See the class help for hParent and the name-value arguments.
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
                    ['uim.container.Panel wraps a real uipanel and requires a ', ...
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
        %getGraphicsContainer Return the uipanel that holds child components
        %
        %   hContainer = obj.getGraphicsContainer() returns the wrapped
        %   uipanel.
            hContainer = obj.PanelHandle;
        end
    end
end
