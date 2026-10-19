classdef Control < uim.abstract.Component
%Control Abstract base class for interactive components
%
%   A control is a uim.abstract.Component that reacts to the mouse, such
%   as a button or a slider. It always draws on its parent's shared
%   canvas.
%
%   Construction (through a concrete subclass):
%       obj = SubclassName(hParent, Name=Value)
%   accepts the parents and name-value arguments described in
%   uim.abstract.Component. Passing CanvasMode raises an error.
%
%   Once constructed, a control
%       - sets the figure pointer to 'hand' while the pointer is over
%         its background patch, and to 'arrow' when the pointer leaves,
%       - shows Tooltip, if not empty, centered about 15 pixels below
%         its bottom edge while the pointer is over it (a control in a
%         container with a private canvas shows no tooltip),
%       - records mouse presses: onMousePressed sets IsMousePressed and
%         listens for the figure's WindowMouseRelease event, which
%         clears it again.
%
%   Subclass contract:
%       - Fulfil the uim.abstract.Component contract.
%       - Set the ButtonDownFcn of the graphics object that receives
%         clicks to @obj.onMousePressed. An override must call
%         onMousePressed@uim.abstract.Control.
%       - Override the protected method changeAppearance to update the
%         look. It runs on pointer enter and exit, and on mouse press
%         and release.
%       - Call Callback when the control is activated. Each subclass
%         defines the arguments it passes.
%
%   See also uim.abstract.Component, uim.control.Button

    % Add showTooltip and hideTooltip should be methods of this class?

    properties

        Callback = []   % Function handle called when the control is activated. Arguments are defined by the subclass.

        % Text label for subclasses that show one, such as
        % uim.widget.Readout.
        Label (1,:) char = '' % Todo: Create label class

        %HorizontalAlignment
        %VerticalAlignment

        Tooltip (1,:) char = ''     % Text shown below the control while the pointer is over it. '' shows no tooltip.
        ContextMenu = []            % Context menu stored with the control. Control does not attach it to any graphics.
    end

    properties (Hidden)
        TooltipYOffset (1,1) double = 15;
    end

    properties (Hidden, Access = protected, Transient)
        TooltipPosition (1,2) double = [0, 0]

        IsMousePressed (1,1) logical = false
        IsMouseOver (1,1) logical = false

        MouseReleasedListener
        LastPointer
    end

    methods
        function obj = Control(varargin)
        %Control Construct the control part of a subclass instance
        %
        %   obj@uim.abstract.Control(hParent, Name, Value, ...) is called
        %   from a subclass constructor. See uim.abstract.Component.
            obj@uim.abstract.Component( varargin{:} )
        end

        function delete(obj)

            % Reset pointerbehavior
            if ~isempty(obj.Background) && isvalid(obj.Background)
                uim.internal.setPointerBehavior(obj.Background, [])
            end

            if ~isempty(obj.MouseReleasedListener)
                delete(obj.MouseReleasedListener)
            end
        end
    end

    methods
        function set.Tooltip(obj, newValue)
            obj.Tooltip = newValue;
            obj.onTooltipChanged()
        end
    end

    methods (Access = protected)

        function relocate(obj, shift)
            relocate@uim.abstract.Component(obj, shift)
            obj.setTooltipPosition()
        end
    end

    methods (Hidden, Access = private)

        function setPointerBehavior(obj)
        %setPointerBehavior Set pointer behavior of background.

            pointerBehavior.enterFcn    = @obj.onMouseEntered;
            pointerBehavior.exitFcn     = @obj.onMouseExited;
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.internal.setPointerBehavior(obj.Background, pointerBehavior)
        end

        function showTooltip(obj)
            % Tooltips are drawn by a UIComponentCanvas. A control in a
            % container with a private canvas has that container's own
            % axes as Canvas, which has no tooltip.
            if isa(obj.Canvas, 'uim.UIComponentCanvas')
                obj.Canvas.showTooltip(obj.Tooltip, obj.TooltipPosition)
            end
        end

        function hideTooltip(obj)
            if isa(obj.Canvas, 'uim.UIComponentCanvas')
                obj.Canvas.hideTooltip()
            end
        end

        function onTooltipChanged(obj)

            obj.setTooltipPosition()

            if obj.IsMouseOver && ~isempty(obj.Tooltip)
                obj.showTooltip()
            end
        end
    end

    methods (Hidden, Access = protected)

        function setTooltipPosition(obj)
        %setTooltipPosition Set position of tooltip on the canvas axes.

            if isempty(obj.Tooltip); return; end
            if ~obj.IsConstructed; return; end

            centerX = mean(obj.Background.XData);
            centerY = mean(obj.Background.YData);

            obj.TooltipPosition = [centerX, centerY - 0.5*obj.Size(2)-obj.TooltipYOffset];
        end

        function changeAppearance(obj)
        end

        function onMouseEntered(obj, ~, ~)

            if ~isvalid(obj); return; end

            obj.IsMouseOver = true;
            obj.changeAppearance()

            hFig = ancestor(obj.Background, 'figure');
            %obj.LastPointer = hFig.Pointer;
            hFig.Pointer = 'hand';

            if ~isempty(obj.Tooltip)
                obj.showTooltip()
            end
        end

        function onMouseExited(obj, ~, ~)

            % Need this here in case the obj was deleted while the pointer
            % was still on it.
            if ~isvalid(obj); return; end

            obj.IsMouseOver = false;

            obj.changeAppearance()

            hFig = ancestor(obj.Background, 'figure');
            %hFig.Pointer = obj.LastPointer;
            hFig.Pointer = 'arrow';

            if ~isempty(obj.Tooltip)
                obj.hideTooltip()
            end
        end

        function onMousePressed(obj, ~, ~)
        %onButtonPressed Event handler for mouse press on button

            obj.IsMousePressed = true;

            if isempty(obj.MouseReleasedListener)
                hFig = ancestor(obj.Background, 'figure');
                el = addlistener(hFig, 'WindowMouseRelease', @obj.onMouseReleased);
                obj.MouseReleasedListener = el;
            end

            obj.changeAppearance()
        end

        function onMouseReleased(obj, ~, ~)
        % Event handler for mouse release from button

            obj.IsMousePressed = false;

            delete(obj.MouseReleasedListener)
            obj.MouseReleasedListener = [];

            obj.changeAppearance()
        end

        function onConstructed(obj)

            if obj.IsConstructed
                onConstructed@uim.abstract.Component(obj)
                obj.setPointerBehavior()
                obj.setTooltipPosition()
            end
    end
    end

%     methods (Access = protected)
%        function onStyleChanged(obj)
%        end
%     end
end
