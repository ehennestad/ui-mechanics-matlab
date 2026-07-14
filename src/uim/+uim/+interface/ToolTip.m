classdef ToolTip < uim.Handle
%ToolTip A tooltip display for a component canvas.
%
%   tooltip = uim.interface.ToolTip(canvasObj) creates a tooltip that
%   draws into the axes of the given uim.UIComponentCanvas. The tooltip
%   deletes itself when the axes it draws into is destroyed.
%
%   Style properties (colors, font) can be changed at any time and take
%   effect immediately.

    properties
        BackgroundColor = ones(1,3) * 0.2
        ForegroundColor = ones(1,3) * 0.8
        EdgeColor = 'none'

        % Note: Falls back to MATLAB's default font on systems where this
        % font is unavailable. Todo: Move default to a shared style/theme.
        FontName = 'Avenir Next'
        FontSize = 12
    end

    properties (Access = private)
        Axes
        TooltipHandle
    end

    properties (Hidden, Access = private)
        SiblingCreatedListener % Listener for creation of new objects in the parent axes.
        ParentDestroyedListener
    end

    methods

        function obj = ToolTip(canvasObj)

            obj.Axes = canvasObj.Axes;

            obj.createTooltipHandle()
            obj.ensureAlwaysOnTop()

            deleteFunc = @(src,evt) delete(obj);
            el = addlistener(obj.Axes, 'ObjectBeingDestroyed', deleteFunc);
            obj.ParentDestroyedListener = el;
        end

        function delete(obj)
            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)
                delete(obj.TooltipHandle)
            end
            if ~isempty(obj.SiblingCreatedListener) && isvalid(obj.SiblingCreatedListener)
                delete(obj.SiblingCreatedListener)
            end
            if ~isempty(obj.ParentDestroyedListener) && isvalid(obj.ParentDestroyedListener)
                delete(obj.ParentDestroyedListener)
            end
        end
    end

    methods

        function showTooltip(obj, text, position)

            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)

                obj.TooltipHandle.String = text;
                obj.TooltipHandle.Visible = 'on';

                % Nudge the tooltip back inside the axes limits if it
                % would extend past either edge.
                extent = obj.TooltipHandle.Extent;
                lim = {'XLim', 'YLim'};
                for i = 1:2
                    if position(i) < obj.Axes.(lim{i})(1)
                        position(i) = obj.Axes.(lim{i})(1) + obj.TooltipHandle.Margin*2;
                    elseif position(i) + extent(i+2) > obj.Axes.(lim{i})(2)
                        position(i) = obj.Axes.(lim{i})(2) - extent(i+2)*1.1;
                    end
                end

                obj.TooltipHandle.Position(1:2) = position;
            end
        end

        function hideTooltip(obj)
            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)
                obj.TooltipHandle.String = '';
                obj.TooltipHandle.Visible = 'off';
            end
        end
    end

    methods % Set methods for style properties

        function set.BackgroundColor(obj, newValue)
            obj.BackgroundColor = newValue;
            obj.onStyleChanged()
        end

        function set.ForegroundColor(obj, newValue)
            obj.ForegroundColor = newValue;
            obj.onStyleChanged()
        end

        function set.EdgeColor(obj, newValue)
            obj.EdgeColor = newValue;
            obj.onStyleChanged()
        end

        function set.FontName(obj, newValue)
            obj.FontName = newValue;
            obj.onStyleChanged()
        end

        function set.FontSize(obj, newValue)
            obj.FontSize = newValue;
            obj.onStyleChanged()
        end
    end

    methods (Access = private)

        function createTooltipHandle(obj)

            obj.TooltipHandle = text(obj.Axes, 1, 1, '');
            obj.TooltipHandle.HorizontalAlignment = 'left';
            obj.TooltipHandle.VerticalAlignment = 'top';
            obj.TooltipHandle.Visible = 'off';
            obj.TooltipHandle.HitTest = 'off';
            obj.TooltipHandle.PickableParts = 'none';

            obj.onStyleChanged()
        end

        function onStyleChanged(obj)
            if isempty(obj.TooltipHandle) || ~isvalid(obj.TooltipHandle)
                return
            end
            obj.TooltipHandle.BackgroundColor = obj.BackgroundColor;
            obj.TooltipHandle.Color = obj.ForegroundColor;
            obj.TooltipHandle.EdgeColor = obj.EdgeColor;
            obj.TooltipHandle.FontName = obj.FontName;
            obj.TooltipHandle.FontSize = obj.FontSize;
        end

        function ensureAlwaysOnTop(obj)
        %ensureAlwaysOnTop Create event callback to always keep tooltip on top

            % Note: ChildAdded is an undocumented event on graphics
            % containers; if it disappears in a future release, the
            % tooltip may end up below later-created siblings.
            onChildAddedFunc = @(s,e) obj.bringTooltipToFront;
            el = addlistener(obj.Axes, 'ChildAdded', onChildAddedFunc);
            obj.SiblingCreatedListener = el;
        end

        function bringTooltipToFront(obj)
            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)
                uistack(obj.TooltipHandle, 'top')
            end
        end
    end
end
