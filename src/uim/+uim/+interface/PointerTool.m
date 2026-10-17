classdef PointerTool < handle & matlab.mixin.Heterogeneous
%PointerTool Abstract base class for a mouse tool that acts on an axes
%
%   A pointer tool turns mouse input in one axes into an action such as
%   zooming or panning. A uim.interface.PointerManager owns a set of
%   tools, makes one of them current, and calls its callbacks with the
%   figure's window mouse events.
%
%   Subclasses construct with obj = ToolClass(hAxes) and call
%   obj@uim.interface.PointerTool(hAxes), which sets Axes and Figure.
%   They must define:
%     ExitMode         - Constant: 'default' or 'previous'. Decides which
%                        tool the manager makes current when this one
%                        is toggled off (see PointerManager
%                        togglePointerMode).
%     setPointerSymbol - Set the figure pointer for this tool.
%     onButtonDown(obj, src, event)   - Mouse press in the axes. event
%                        has the fields Button (1 left, 2 middle,
%                        3 right), HitObject, Point and
%                        IntersectionPoint.
%     onButtonMotion(obj, src, event) - Mouse motion in the figure.
%     onButtonUp(obj, src, event)     - Mouse release in the figure.
%   Subclasses may override activate, suspend, deactivate, onKeyPress,
%   onKeyRelease, onPointerEnteredAxes and onPointerExitedAxes.
%
%   PointerTool properties:
%     IsActive        - True while the tool is in the middle of an action
%     ButtonDownFcn   - Host callback; see each tool for its use
%     ButtonUpFcn     - Host callback; see each tool for its use
%     ButtonMotionFcn - Host callback; see each tool for its use
%     Figure          - Figure that contains Axes
%     Axes            - Axes the tool acts on
%
%   PointerTool events:
%     ToggledPointerTool - Fires with a uim.event.ToggleEvent whose Value
%                          is 1 on activate and 0 on suspend and
%                          deactivate.
%
%   See also uim.interface.PointerManager, uim.interface.pointertools.ZoomIn

% Todo: Implement callbacks for MousePressed, MouseMotion, MouseReleased,
% MouseScrolled etc that can be configured from gui that requests/creates
% the pointertools. At the moment, many of the tools has knowledge about
% the functions that need to be activated from the parent gui, and that is
% not good style!

    properties (Abstract, Constant)
        % 'default' or 'previous': on toggle-off the manager makes its
        % DefaultPointerTool or the suspended previous tool current.
        ExitMode
    end

    properties
        IsActive (1,1) logical = false % True while the tool is in the middle of an action, e.g. a drag

        % Host callbacks. Each tool decides whether and how it calls them
        % (for example Pan calls ButtonMotionFcn(shift) instead of panning).
        ButtonDownFcn % protected?
        ButtonUpFcn % protected?
        ButtonMotionFcn % protected?

%         activatedCallback  Just use toggle event instead??
%         deactivatedCallback
    end

    properties (SetAccess = protected)
        Figure matlab.ui.Figure % Figure that contains Axes
        Axes matlab.graphics.axis.Axes % Axes the tool acts on
    end

    properties (Access = protected)
        State (1,:) char {mustBeMember(State, {'on', 'on_hold', 'off'})} = 'off';      % on | on hold | off
        PointerCData = [];
    end

    events
        ToggledPointerTool % Tool turned on (ToggleEvent Value 1) or off (Value 0)
    end

    methods (Abstract) % Todo: don't have to be abstract

        setPointerSymbol(obj)
        onButtonDown(obj, src, event)
        onButtonMotion(obj, src, event)
        onButtonUp(obj, src, event)
    end

    methods

        function obj = PointerTool(hAxes)
        %PointerTool Attach hAxes and its parent figure to the tool
        %
        %   obj@uim.interface.PointerTool(hAxes) from a subclass
        %   constructor. Without hAxes, Axes and Figure stay empty.

            if nargin > 0
                obj.Axes = hAxes;
                obj.Figure = ancestor(hAxes, 'figure');
            end
        end
    end

    methods % Public methods

        function wasCaptured = onKeyPress(~, ~, ~)
        %onKeyPress Handle a key press; return true if the tool used it
        %
        %   wasCaptured = tool.onKeyPress(src, event) returns false. Tools
        %   that respond to keys override it.
            wasCaptured = false;
        end

        function wasCaptured = onKeyRelease(~, ~, ~)
        %onKeyRelease Handle a key release; return true if the tool used it
        %
        %   wasCaptured = tool.onKeyRelease(src, event) returns false. Tools
        %   that respond to keys override it.
            wasCaptured = false;
        end

        function activate(obj)
        %activate Turn the tool on
        %
        %   tool.activate() sets the figure pointer and notifies
        %   ToggledPointerTool with Value 1.
            obj.setPointerSymbol()
            obj.State = 'on';

%             if ~isempty(obj.activatedCallback)
%                 obj.activatedCallback()
%             end

            eventData = uim.event.ToggleEvent(1);
            obj.notify('ToggledPointerTool', eventData)
        end

        function suspend(obj)
        %suspend Put the tool on hold while another tool is current
        %
        %   tool.suspend() notifies ToggledPointerTool with Value 0. The
        %   manager reactivates the tool when the other tool turns off.
            eventData = uim.event.ToggleEvent(0);
            obj.notify('ToggledPointerTool', eventData)
            obj.State = 'on_hold';
        end

        function deactivate(obj)
        %deactivate Turn the tool off
        %
        %   tool.deactivate() notifies ToggledPointerTool with Value 0.
            obj.State = 'off';
            eventData = uim.event.ToggleEvent(0);
            obj.notify('ToggledPointerTool', eventData)
        end

        function tf = isPointerInsideAxes(obj, currentPoint)
        %isPointerInsideAxes True if a point lies within the axes limits
        %
        %   tf = tool.isPointerInsideAxes() tests the axes CurrentPoint.
        %   tf = tool.isPointerInsideAxes(currentPoint) tests an [x, y]
        %   point in data units.

            if nargin < 2
                currentPoint = obj.Axes.CurrentPoint(1, 1:2);
            end

            tf = uim.geometry.isPointInsideLimits(...
                currentPoint, obj.Axes.XLim, obj.Axes.YLim);
        end

        function onPointerExitedAxes(obj)
        %onPointerExitedAxes Called by the manager when the pointer leaves the axes
            % Subclasses may override
        end

        function onPointerEnteredAxes(obj)
        %onPointerEnteredAxes Called by the manager when the pointer enters the axes
            % Subclasses may override
        end
    end

    methods (Access = protected)

        function point = getCurrentPointInPixels(obj)
        %getCurrentPointInPixels Figure CurrentPoint in pixels
        %
        %   point = tool.getCurrentPointInPixels() returns the figure
        %   CurrentPoint as [x, y] in pixels, whatever the figure Units
        %   are. Tools that convert a pointer distance with an axes size
        %   in pixels need both in the same unit.

            point = obj.Figure.CurrentPoint;
            if ~strcmp(obj.Figure.Units, 'pixels')
                pointPosition = hgconvertunits(obj.Figure, [point, 0, 0], ...
                    obj.Figure.Units, 'pixels', obj.Figure);
                point = pointPosition(1:2);
            end
        end
    end

% %     methods (Access = public) % These should not be public... Or there
% %         %should be one method that can be accessed from Pointermanager and
% %         %one method that can be overridden by subclasses...
% %
% %         function onPointerExitedAxes(obj)
% %             % Subclasses may override
% %         end
% %
% %         function onPointerEnteredAxes(obj)
% %             % Subclasses may override
% %         end
% %
% %     end
end
