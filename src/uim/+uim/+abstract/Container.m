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

            matlabVersion = version('-release');
            doDisableToolbar = str2double(matlabVersion(1:4))>2018 || ...
                                       strcmp(matlabVersion, '2018b');

            if doDisableToolbar
                args = {'Toolbar', []};
            else
                args = {};
            end

            obj.hAxes = axes('Parent', hGraphicsParent, args{:});
            hold(obj.hAxes, 'on');

            set(obj.hAxes, 'XTick', [], 'YTick', [])
            obj.hAxes.Visible = 'off';
            obj.hAxes.Units = 'pixel';
            obj.hAxes.HandleVisibility = 'off';
            obj.hAxes.Tag = sprintf('%s Widget Canvas', obj.Type);

            axis(obj.hAxes, 'equal')

            if all(isfinite(obj.Position))
                obj.hAxes.Position = obj.Position;
                obj.hAxes.YLim = [1, obj.Position(4)];
                obj.hAxes.XLim = [1, obj.Position(3)];
            end

            if doDisableToolbar
                disableDefaultInteractivity(obj.hAxes)
            end

            obj.Canvas = obj.hAxes;
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
