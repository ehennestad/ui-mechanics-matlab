classdef Container < uim.abstract.Component
%Container Abstract base class for components that hold other components
%
%   A container is a uim.abstract.Component that other components can
%   use as their parent. A component created with a container as its
%   parent is placed in the container's graphics container (see
%   getGraphicsContainer) and positioned relative to it.
%
%   Construction (through a concrete subclass):
%       obj = SubclassName(hParent, Name=Value)
%   accepts the same parents and name-value arguments as
%   uim.abstract.Component, plus CanvasMode:
%       'shared'  - (default) draw on the parent's canvas.
%       'private' - create a dedicated, invisible axes for the container
%                   in the parent's graphics container, sized to
%                   Position. Components created with the container as
%                   parent draw in that axes. Use it when the shared
%                   canvas is heavily used by other content. A
%                   container on an overlay canvas (a canvas covering
%                   an axes) can not use 'private' and raises
%                   uim:Container:PrivateCanvasUnsupportedOnOverlay.
%
%   Subclass contract:
%       - Fulfil the uim.abstract.Component contract.
%       - Define the property Children (SetAccess = protected,
%         Transient, class uim.abstract.Component).
%       - Container also defines the protected methods onChildAdded,
%         onChildRemoved, moveChildren and resizeChildren. They do
%         nothing and Container does not call them; subclasses may
%         override and call them.
%
%   See also uim.abstract.Component, uim.container.Panel,
%   uim.container.TabGroup, uim.widget.Toolbar

    properties (Abstract, SetAccess = protected, Transient)
        Children uim.abstract.Component % Components held by the container
    end

    methods
        function obj = Container(hParent, propertyValues)
        %Container Construct the container part of a subclass instance
        %
        %   obj@uim.abstract.Container(hParent, propertyValues) is called
        %   from a subclass constructor. See the class help.

            arguments
                hParent
                propertyValues (1,1) struct = struct()
            end

            obj@uim.abstract.Component(hParent, propertyValues)
        end
    end

    methods (Access = protected)

        function assignComponentCanvas(obj)
            switch obj.CanvasMode
                case 'shared'
                    assignComponentCanvas@uim.abstract.Component(obj)
                case 'private'
                    obj.createPrivateCanvas()
            end
        end

        function createPrivateCanvas(obj)

            % Create an axes which will be the container for this widget.
            if isa(obj.Parent, 'uim.UIComponentCanvas')
                if ~isempty(obj.Parent.TargetAxes)
                    % Private-canvas layout math assumes the shared canvas
                    % is container-aligned (canvas-local coordinates equal
                    % container pixels), which does not hold when the
                    % shared canvas is an overlay covering a target axes.
                    error('uim:Container:PrivateCanvasUnsupportedOnOverlay', ...
                        ['CanvasMode ''private'' is not supported for ', ...
                         'containers placed on an overlay canvas. Use the ', ...
                         'default shared canvas mode.'])
                end
                hGraphicsParent = obj.Parent.Axes.Parent;
            else
                hGraphicsParent = obj.Parent;
            end

            args = uim.internal.getAxesToolbarArgs();

            obj.CanvasAxes = axes('Parent', hGraphicsParent, args{:});
            hold(obj.CanvasAxes, 'on');

            set(obj.CanvasAxes, 'XTick', [], 'YTick', [])
            obj.CanvasAxes.Visible = 'off';
            obj.CanvasAxes.Units = 'pixel';
            obj.CanvasAxes.HandleVisibility = 'off';
            obj.CanvasAxes.Tag = sprintf('%s Widget Canvas', obj.Type);

            axis(obj.CanvasAxes, 'equal')

            if all(isfinite(obj.Position))
                obj.CanvasAxes.Position = obj.Position;
                obj.CanvasAxes.YLim = [1, obj.Position(4)];
                obj.CanvasAxes.XLim = [1, obj.Position(3)];
            end

            uim.internal.disableAxesInteractivity(obj.CanvasAxes)

            obj.Canvas = obj.CanvasAxes;
        end

        function onChildAdded(~, ~)
        end

        function onChildRemoved(~, ~)
        end

        function moveChildren(~)
        end

        function resizeChildren(~)
        end
    end
end
