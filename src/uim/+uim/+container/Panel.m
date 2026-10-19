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
%   Of the style properties, only BackgroundColor and Visible affect the
%   uipanel. With the inherited default BackgroundColor 'none', the
%   uipanel keeps its own default colour. The uipanel follows the layout
%   and any assigned Position or Size.
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
            if nargin < 2; mode = obj.SizeMode; end

            updateSize@uim.abstract.Component(obj, mode)
            obj.syncPanelPosition()
        end

        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end

            updateLocation@uim.abstract.Component(obj, mode)
            obj.syncPanelPosition()
        end

        function resize(obj)
        %resize Resize the uipanel when Size or Position is assigned
            resize@uim.abstract.Container(obj)
            obj.syncPanelPosition()
        end

        function relocate(obj, shift)
        %relocate Move the uipanel when Position is assigned
            relocate@uim.abstract.Container(obj, shift)
            obj.syncPanelPosition()
        end
    end

    methods (Access = private)
        function syncPanelPosition(obj)
        %syncPanelPosition Give the uipanel the component Position
        %
        %   Layout options can be assigned before createBackground makes
        %   the uipanel; the constructor's layout pass syncs it then.
            if isempty(obj.PanelHandle); return; end
            if ~isequal(obj.PanelHandle.Position, obj.Position)
                obj.PanelHandle.Position = obj.Position;
            end
        end
    end

    methods (Access = protected)
        function onStyleChanged(obj)
            % A uipanel has no 'none' colour; it keeps its own default
            color = obj.BackgroundColor;
            isNone = (ischar(color) || isstring(color)) && strcmpi(color, 'none');
            if obj.IsConstructed && ~isNone
                obj.PanelHandle.BackgroundColor = color;
            end
        end

        function onVisibleChanged(obj, newValue)
            if isempty(obj.PanelHandle); return; end
            obj.PanelHandle.Visible = newValue;
        end
    end

    methods
        function pos = getpixelposition(obj, recursive)
        %getpixelposition Return the panel position in pixels
        %
        %   pos = obj.getpixelposition() returns the uipanel's pixel
        %   position in its parent. pos = obj.getpixelposition(true)
        %   returns it relative to the figure.
        %
        %   See also getpixelposition
            if nargin < 2; recursive = false; end
            % Component.getpixelposition offsets Position by the graphics
            % container, which for a panel is the panel's own uipanel, so
            % the panel reports the uipanel's position directly
            pos = getpixelposition(obj.PanelHandle, recursive);
        end

        function hContainer = getGraphicsContainer(obj)
        %getGraphicsContainer Return the uipanel that holds child components
        %
        %   hContainer = obj.getGraphicsContainer() returns the wrapped
        %   uipanel.
            hContainer = obj.PanelHandle;
        end
    end
end
