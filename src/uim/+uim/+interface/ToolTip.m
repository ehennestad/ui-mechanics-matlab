classdef ToolTip < uim.Handle
%ToolTip Tooltip text box drawn in the axes of a component canvas
%
%   tooltip = uim.interface.ToolTip(canvasObj) creates a hidden tooltip
%   that draws into the axes of the given uim.UIComponentCanvas. The
%   tooltip deletes itself when the axes it draws into is destroyed.
%   uim.UIComponentCanvas creates one for its controls; use its
%   showTooltip method rather than constructing a ToolTip directly.
%
%   The tooltip is a text object that ignores mouse clicks and is moved
%   to the top of the axes children whenever a child is added, so it
%   stays above other graphics.
%
%   Style properties (colors, font) can be changed at any time and take
%   effect immediately.
%
%   ToolTip methods:
%     showTooltip - Show text at a position in the axes
%     hideTooltip - Hide the tooltip
%
%   See also uim.UIComponentCanvas

    properties
        BackgroundColor = ones(1,3) * 0.2 % Box fill color; any text BackgroundColor value
        ForegroundColor = ones(1,3) * 0.8 % Text color
        EdgeColor = 'none' % Box outline color, or 'none'

        % Note: Falls back to MATLAB's default font on systems where this
        % font is unavailable. Todo: Move default to a shared style/theme.
        FontName = 'Avenir Next' % Font name
        FontSize = 12 % Font size in points
    end

    properties (Access = private)
        Axes
        TooltipHandle

        % Set when a ChildAdded hoist failed (re-entrant uistack); the
        % next showTooltip retries, so a failure on the last ChildAdded
        % event cannot leave the tooltip buried for good.
        IsHoistPending (1,1) logical = false
    end

    properties (Hidden, Access = private)
        SiblingCreatedListener % Listener for creation of new objects in the parent axes.
        ParentDestroyedListener
    end

    methods

        function obj = ToolTip(canvasObj)
        %ToolTip Create a hidden tooltip in the canvas axes
        %
        %   tooltip = uim.interface.ToolTip(canvasObj)

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
        %showTooltip Show text with its upper-left corner at a position
        %
        %   tooltip.showTooltip(text, position) shows text (character
        %   vector, string or cell array of lines) with its upper-left
        %   corner at position, an [x, y] point in data units of the
        %   canvas axes. The position is adjusted so the text stays inside
        %   the axes limits.

            if ~isempty(obj.TooltipHandle) && isvalid(obj.TooltipHandle)

                if obj.IsHoistPending
                    obj.bringTooltipToFront()
                end

                obj.TooltipHandle.String = text;
                obj.TooltipHandle.Visible = 'on';

                % Nudge the tooltip back inside the axes limits if it
                % would extend past an edge. The text extends right of
                % position and, being top-aligned, down from it.
                extent = obj.TooltipHandle.Extent;
                xLim = obj.Axes.XLim;
                yLim = obj.Axes.YLim;
                margin = obj.TooltipHandle.Margin*2;

                if position(1) < xLim(1)
                    position(1) = xLim(1) + margin;
                elseif position(1) + extent(3) > xLim(2)
                    position(1) = xLim(2) - extent(3)*1.1;
                end

                if position(2) - extent(4) < yLim(1)
                    position(2) = yLim(1) + extent(4)*1.1;
                elseif position(2) > yLim(2)
                    position(2) = yLim(2) - margin;
                end

                obj.TooltipHandle.Position(1:2) = position;
            end
        end

        function hideTooltip(obj)
        %hideTooltip Hide the tooltip and clear its text
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
                try
                    uistack(obj.TooltipHandle, 'top')
                    obj.IsHoistPending = false;
                catch
                    % This runs from a ChildAdded listener, which also
                    % fires while OTHER code is restacking the axes
                    % children (e.g. a widget calling uistack); the
                    % re-entrant uistack can fail on that transient
                    % state. Safe to skip: the hoist is retried on the
                    % next ChildAdded and — since no further child may
                    % ever be added — when the tooltip is next shown.
                    obj.IsHoistPending = true;
                end
            end
        end
    end
end
