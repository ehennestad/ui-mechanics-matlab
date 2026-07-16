classdef Waitbar < uim.mixin.NameValueAssignable

    properties (Dependent)
        Position (1,4) double
    end

    properties
        Message = ''
        Status = 0 % Number in range 0 - 1;

        Enabled matlab.lang.OnOffSwitchState = 'on'
        Visible matlab.lang.OnOffSwitchState = 'on'

        BarWidthCompleted = 2;
        BarWidthRemaining = 1;
        BarColorCompleted = [74,86,99]/125
        BarColorRemaining = [0.5, 0.5, 0.5];

        Margins = 1; % pixels in length direction.
    end

    properties (Access = private)
        Axes
        Position_ = [1,1,100,10]
        BarRemaining
        BarCompleted
        ParentSizeChangedListener
    end

    methods % Structors

        function obj = Waitbar(hParent, varargin)

            if isa(hParent, 'matlab.graphics.axis.Axes')
                obj.Axes = hParent;
                obj.ParentSizeChangedListener = listener(obj.Axes, ...
                    'SizeChanged', @obj.onParentSizeChanged);

            else
                error('Parent must be an axes for now.')
            end

            obj.parseInputs(varargin{:})

            obj.drawWaitbar()
            obj.onVisibleChanged()
        end

        function delete(obj)
            delete(obj.BarRemaining)
            delete(obj.BarCompleted)
            delete(obj.ParentSizeChangedListener)
        end
    end

    methods (Access = public)
    end

    methods % Set/get Methods
        function set.Position(obj, newPos)
            assert(isnumeric(newPos) && numel(newPos) == 4, 'Value must be a 4 element vector')
            assert(all(newPos(3:4) > 1), 'This widget does not support normalized position units')
            obj.Position_ = newPos;
        end

        function pos = get.Position(obj)
            pos = obj.Position_;
        end

        function set.Position_(obj, newPosition)
            obj.Position_= newPosition;
            obj.onPositionChanged()
        end

        function set.Status(obj, newValue)
            assert(isnumeric(newValue) && newValue >= 0 && newValue <= 1, ...
                'Status must be a number between 0 and 1')

            obj.Status = newValue;
            obj.drawWaitbar()
        end

        function set.Visible(obj, newValue)
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end
    end

    methods (Access = private) % Create and update widget components

        function drawWaitbar(obj)

            [Xa, Ya] = obj.getBarCoordinates('completed');
            [Xb, Yb] = obj.getBarCoordinates('remaining');

            if isempty(obj.BarCompleted)

                % Keep hold on while creating the bars so a caller-supplied
                % axes with NextPlot 'replace' does not delete the first
                % bar when the second one is plotted.
                wasHoldOn = ishold(obj.Axes);
                hold(obj.Axes, 'on')

                obj.BarRemaining = plot(obj.Axes, Xb,Yb);
                obj.BarCompleted = plot(obj.Axes, Xa,Ya);

                if ~wasHoldOn
                    hold(obj.Axes, 'off')
                end

                set([obj.BarCompleted, obj.BarRemaining], 'HitTest', ...
                    'off', 'PickableParts', 'none', 'Clipping', 'off')

                obj.onAppearanceChanged()
            else
                obj.BarCompleted.XData = Xa;
                obj.BarRemaining.XData = Xb;
                drawnow limitrate
            end
        end

        function [X, Y] = getBarCoordinates(obj, barName)

            x0 = obj.Position(1) + obj.Margins;
            y0 = obj.Position(2) + obj.BarWidthCompleted/2;

            length = obj.Position(3) - obj.Margins*2;

            switch barName
                case 'remaining'
                    X = x0 + [0; length];
                    Y = y0 - obj.BarWidthCompleted/2 .* [1; 1];
                case 'completed'
                    X = x0 + [0; length*obj.Status];
                    Y = y0 - obj.BarWidthRemaining/2 .* [1; 1];
            end

            [X, Y] = uim.utility.px2du(obj.Axes, [X, Y]);
        end
    end

    methods (Access = private) % Property set callbacks

        function onAppearanceChanged(obj)

            if isempty(obj.BarCompleted); return; end

            obj.BarRemaining.LineWidth = obj.BarWidthRemaining;
            obj.BarCompleted.LineWidth = obj.BarWidthCompleted;

            obj.BarRemaining.Color = obj.BarColorRemaining;
            obj.BarCompleted.Color = obj.BarColorCompleted;
        end

        function onEnableChanged(obj)
        end

        function onVisibleChanged(obj)
            obj.BarRemaining.Visible = obj.Visible;
            obj.BarCompleted.Visible = obj.Visible;
        end

        function onParentSizeChanged(obj, ~, ~)
            obj.drawWaitbar()
        end

        function onPositionChanged(obj)
            obj.drawWaitbar()
        end
    end
end
