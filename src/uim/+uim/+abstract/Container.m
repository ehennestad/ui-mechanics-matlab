classdef Container < uim.abstract.Component
%Container A container for placing other components within.
%
%   A container's CanvasMode determines where it draws: 'shared' (the
%   default) uses its parent's canvas; 'private' gives it its own
%   dedicated axes, created via createPrivateCanvas.

    properties (Abstract, SetAccess = protected, Transient)
        Children uim.abstract.Component
    end

    methods
        function obj = Container(varargin)
        	obj@uim.abstract.Component(varargin{:})
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
                hGraphicsParent = obj.Parent.Axes.Parent;
            else
                hGraphicsParent = obj.Parent;
            end

            args = uim.utility.getAxesToolbarArgs();

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

            if ~isempty(args)
                disableDefaultInteractivity(obj.CanvasAxes)
            end

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
