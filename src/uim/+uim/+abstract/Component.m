classdef Component < uim.Handle & matlab.mixin.Heterogeneous & uim.mixin.NameValueAssignable
%Component Abstract base class for components drawn on a UIComponentCanvas
%
%   A component is a graphical element plotted in the axes of a
%   uim.UIComponentCanvas. This class gives every component its layout
%   (position and size in pixels, relative to the parent container) and
%   its basic style (a background patch with optional border). Do not
%   subclass Component directly: derive from uim.abstract.Control for
%   interactive elements or uim.abstract.Container for components that
%   hold other components.
%
%   Construction (through a concrete subclass):
%       obj = SubclassName(hParent)
%       obj = SubclassName(hParent, Name=Value)
%
%   hParent is one of:
%       - a uim.UIComponentCanvas: the component draws on that canvas.
%       - a figure, uipanel or uitab: the component draws on the
%         container's canvas, created by
%         uim.UIComponentCanvas.getOrCreate if it does not exist.
%       - an axes: the component draws on an overlay canvas covering the
%         axes (see uim.UIComponentCanvas).
%       - a uim.abstract.Container: the component is placed in the
%         container's graphics container (see getGraphicsContainer) and,
%         when the container has a private canvas, draws in it.
%   Name-value arguments set public properties. Names that do not match
%   a public property are ignored. Defaults returned by the subclass's
%   getTypeDefaults are merged with the name-value arguments; an argument
%   for the same property replaces the default. The merged values are
%   assigned in the order the properties are declared, not in argument
%   order.
%
%   Layout:
%   All positions and sizes are in pixels. Position is
%   [x, y, width, height] relative to the parent container, with [1, 1]
%   at the bottom left.
%
%   With PositionMode 'auto', the location is computed from Location,
%   Margin, HorizontalAlignment and VerticalAlignment, and recomputed when
%   the parent is resized. Location picks a reference point in the
%   parent: a corner, the middle of an edge, or the center. Margin keeps
%   the component away from the edges named by Location; at a centered
%   reference point, Margin(1) shifts it right ('center' also shifts it
%   up by Margin(2)). Then HorizontalAlignment 'center' or 'right' shifts
%   it left by half or all of its width, and VerticalAlignment 'middle'
%   or 'top' shifts it down by half or all of its height. Setting
%   Position switches PositionMode to 'manual'. After construction,
%   setting Location, Margin, HorizontalAlignment or VerticalAlignment
%   switches it back to 'auto'.
%
%   With SizeMode 'auto', the width and height follow the parent size
%   minus the Margin on both sides, except in the dimensions where
%   IsFixedSize is true. Setting Size switches SizeMode to 'manual';
%   setting Position does not change SizeMode. Every size is clamped to
%   the range [MinimumSize, MaximumSize].
%
%   Illustration showing layout of a component:
%
% % % % % % % Parent Container  % % % % % % % % % % % %
% o                     o                           o %
%    Margin Area                                      %
%                                                     %
%    x------------------x-------------------x Border  %
%    |  Padded Area    Top                  |         %
%    |        _ _ _ _ _ _ _ _ _ _ _         |         %      y ^
%    |       | \ \ \ \ \ \ \ \ \ \ |        |         %        |
% o  x Left  | \ \ \ Content \ \ \ | Right  x       o %        |
%    |       |_\_\_\_\_\_\_\_\_\_\_|        |         %        |
%    |                                      |         %        o-----> x
%    |               Bottom                 |         %
%    x------------------x-------------------x         %
%                                                     %
% o                     o                           o %
% % % % % % % % % % % % % % % % % % % % % % % % % % % %
%
%  x = Anchor points ( Horizontal/Vertical Alignment )
%  o = Location (south, east, north, west)
%
%
%   A Control is always drawn in the parent's (shared) canvas, while a
%   Container can create its own private canvas. See
%   uim.abstract.Container for details.
%
%   Events:
%       SizeChanged     - Size changed. Data: uim.event.SizeChangedData.
%       LocationChanged - Position(1:2) changed. Data:
%                         uim.event.LocationChangedData.
%   Both are raised only while CanvasMode is 'shared'.
%
%   Subclass contract:
%       - Define the constant property Type, a character vector naming
%         the component type.
%       - Pass hParent and the name-value arguments on to the superclass
%         constructor, create the subclass graphics, then set
%         obj.IsConstructed = true. That runs the first layout, style
%         and draw pass (onConstructed).
%       - Optionally override the protected methods createBackground,
%         redraw, resize, relocate, onStyleChanged, onShapeChanged and
%         onVisibleChanged, and the static method getTypeDefaults.
%
%   See also uim.abstract.Control, uim.abstract.Container,
%   uim.UIComponentCanvas

% Questions:
%       [ ] Should there be an allowed subclasses attribute? I.e Control and
%           Container would be allowed subclasses?
%       [ ] Should PositionMode and SizeMode be protected properties
%       [ ] Should PositionMode be renamed to LocationMode

% Todo:
%       [ ] Simplify positioning. ie remove size and use position(3:4)?         (Not sure if this is needed).
%       [x] Remove hAxes property and replace with CanvasAxes
%       [ ] Implement a set.Parent method
%       [ ] Implement a set.IsFixedSize method
%       [x] Implement a getpixelposition method.
%       [ ] Implement a set methods for PositionMode, SizeMode
%       [x] Implement a set methods for MinimumSize, MaximumSize
%       [ ] Make a component style... which is basically all the
%           backgroundstyles...

    properties (Abstract, Constant)
        % Name of the component type, a character vector defined by each
        % subclass.
        Type % Should rename to name????
    end

    properties (Transient) % Todo, this should not be transient. Actually, why not...
        % UIComponentCanvas the component draws on, or the private canvas
        % axes of its parent container. Set by the constructor.
        Canvas = [] % Rename to virtualParent? Hide?

        % Graphics container or UIComponentCanvas the component is placed
        % in. Set by the constructor; assigning a new value does not move
        % the component.
        Parent = [] % Rename / make sure this is a matlab graphical container
    end

    properties (Dependent)
        % [x, y, width, height] in pixels, relative to the parent
        % container. Setting it switches PositionMode to 'manual'.
        Position (1,4) double = [1,1,10,10]     % Dependent?
    end

    properties (Dependent) % SetAccess = private?
        % [width, height] in pixels. Setting it switches SizeMode to
        % 'manual'.
        Size (1,2) double = [0, 0] % necessary??
    end

    properties % Position properties

        % 'auto' computes the location from Location, Margin and the
        % alignment properties; 'manual' keeps Position(1:2).
        PositionMode (1,:) char {mustBeMember(PositionMode, {'auto', 'manual'})} = 'auto'

        % 'auto' fills the parent minus Margin (see IsFixedSize);
        % 'manual' keeps Size.
        SizeMode (1,:) char {mustBeMember(SizeMode, {'auto', 'manual'})} = 'auto'

        Margin (1,4) double = [0,0,0,0]           % Space around the component, [left, bottom, right, top] in pixels

        % Space inside the border, [left, bottom, right, top] in pixels.
        % Used by subclasses that lay out content.
        Padding (1,4) double = [0,0,0,0]

        % Location of component in the parent container. See layout
        % description above. Compass points (compound or bare) plus 'center'.
        Location (1,:) char {mustBeMember(Location, {'north', 'south', ...
            'east', 'west', 'northeast', 'northwest', 'southeast', ...
            'southwest', 'center'})} = 'southwest'

        % Horizontal anchor point of the component: 'left', 'center' or
        % 'right'. 'center' and 'right' shift the component left by half
        % or all of its width. See layout description above.
        HorizontalAlignment (1,:) char {mustBeMember(HorizontalAlignment, {'left', 'center', 'right'})} = 'left'

        % Vertical anchor point of the component: 'bottom', 'middle' or
        % 'top'. 'middle' and 'top' shift the component down by half or
        % all of its height. See layout description above.
        VerticalAlignment (1,:) char {mustBeMember(VerticalAlignment, {'bottom', 'middle', 'top'})} = 'bottom'

        IsFixedSize (1,2) logical = [false, false]     % [x, y] true keeps the current width/height when SizeMode is 'auto'

        MinimumSize (1,2) double = [10, 10]     % Smallest allowed [width, height] in pixels
        MaximumSize (1,2) double = [inf, inf]   % Largest allowed [width, height] in pixels
    end

    properties % Style properties
        BackgroundColor = 'none'    % Fill color of the background (color name, RGB triplet or 'none')
        ForegroundColor = 'w'       % Color of content drawn by subclasses (text, icons)
        % Background opacity, from 0 (transparent) to 1 (opaque)
        BackgroundAlpha (1,1) double {mustBeGreaterThanOrEqual(BackgroundAlpha, 0), mustBeLessThanOrEqual(BackgroundAlpha, 1)} = 0.3
        BorderColor = 'none'        % Color of the background outline, or 'none' for no border

        % Line width of the background outline. A new value is drawn at
        % the next style update, e.g. when a color property changes.
        BorderWidth (1,1) double {mustBeNonnegative} = 0.5

        CornerRadius (1,1) double {mustBeNonnegative} = 0   % Corner radius of the background, in pixels
    end

    properties % Graphics objects properties
        % 'on' or 'off'. Subclasses apply it to their graphics.
        Visible (1,:) char {mustBeMember(Visible, {'on', 'off'})} = 'on'
        Tag (1,:) char = ''     % Identifier for the component
        UserData = []           % Any data to store with the component
    end

    properties (SetAccess = protected)
        % 'shared' draws on the parent's canvas; 'private' gives a
        % container its own canvas axes. Set with the CanvasMode
        % name-value argument at construction; only containers accept
        % 'private'.
        CanvasMode (1,:) char = 'shared' % vs 'private' % Should be container property.
    end

    properties (Access = protected, Dependent, Transient)
        CanvasPosition (1,4) double % Position in Canvas
    end

    properties (Access = protected, Transient) % Internal properties
        Position_ (1,4) double = [1,1,80,20]  % Internally used position
    end

    properties (Hidden, Access = protected, Transient)
        ParentContainerSizeChangedListener event.listener
        ParentContainerLocationChangedListener event.listener
        ParentContainerDestroyedListener event.listener
        CanvasDestroyedListener event.listener
        IsConstructed (1,1) logical = false
        IsDrawCompleted (1,1) logical = false
        CanvasAxes matlab.graphics.axis.Axes
        Background
        Border
    end

    properties (Hidden, Access = private, Transient)
        IsConstructed_ (1,1) logical = false % Constructed flag internal to the component superclass
    end

    events
        LocationChanged % Position(1:2) changed (shared canvas mode only). Data: uim.event.LocationChangedData
        SizeChanged     % Size changed (shared canvas mode only). Data: uim.event.SizeChangedData
        StyleChanged    % Declared but never raised by Component
    end

    methods % Structors

        function obj = Component(hParent, varargin)
        %Component Construct the component part of a subclass instance
        %
        %   obj@uim.abstract.Component(hParent, Name, Value, ...) is called
        %   from a subclass constructor. See the class help for hParent
        %   and the name-value arguments.

            if isa(hParent, 'uim.abstract.Container')
                obj.Parent = hParent.getGraphicsContainer();
                if strcmp(hParent.CanvasMode, 'private')
                    % Draw in the same private axes as the parent
                    % container, rather than its outer graphics parent.
                    obj.Canvas = hParent.Canvas;
                end
            elseif isa(hParent, 'uim.UIComponentCanvas')
                obj.Parent = hParent;
            elseif isa(hParent, 'matlab.graphics.axis.Axes')
                % An axes can not contain the component directly; use (or
                % create) an overlay canvas covering the axes' pixel rect.
                obj.Parent = uim.UIComponentCanvas.getOrCreate(hParent);
            elseif isgraphics(hParent)
                obj.Parent = hParent;
            else
                error('Parent must be this or that')
            end

            obj.createListeners()

            obj.parseInputs(varargin{:})

            obj.assignComponentCanvas()

            obj.CanvasDestroyedListener = addlistener(obj.Canvas, ...
                'ObjectBeingDestroyed', @(s,e) obj.delete());

            obj.createBackground()

            obj.IsConstructed_ = true;

            % Call updateSize to trigger size update (call before location)
            obj.updateSize(obj.SizeMode)

            % Call updateLocation to trigger location update
            obj.updateLocation(obj.PositionMode)

            if isa(obj.Canvas, 'uim.UIComponentCanvas')
                obj.Canvas.registerChild(obj)
            end
        end

        function delete(obj)

            if isa(obj.Canvas, 'uim.UIComponentCanvas') && isvalid(obj.Canvas)
                obj.Canvas.unregisterChild(obj)
            end

            if ~isempty(obj.Background) && isvalid(obj.Background)
                delete(obj.Background)
            end

            if ~isempty(obj.Border) && isvalid(obj.Border)
                delete(obj.Border)
            end
        end
    end

    methods (Access = protected) % Creation

        function createListeners(obj)
        %createListeners Create listeners relevant for component
            el = listener(obj.Parent, 'SizeChanged', ...
                @obj.onParentContainerSizeChanged);

            obj.ParentContainerSizeChangedListener = el;

            obj.ParentContainerDestroyedListener = addlistener(obj.Parent, ...
                'ObjectBeingDestroyed', @(s,e) obj.delete());
        end

        function parseInputs(obj, varargin)
        %parseInputs Collect type defaults and name-value pairs and assign.

            S = obj.getTypeDefaults();

            callerArgs = varargin;
            callerNames = cellfun(@char, callerArgs(1:2:end), 'UniformOutput', false);
            callerArgs(1:2:end) = callerNames;

            % Special treatment because this has protected setAccess
            isCanvasMode = strcmp(callerNames, 'CanvasMode');
            if any(isCanvasMode)
                obj.CanvasMode = callerArgs{find(isCanvasMode, 1, 'last')*2};
            elseif isfield(S, 'CanvasMode')
                obj.CanvasMode = S.CanvasMode;
            end
            callerArgs(sort([find(isCanvasMode)*2-1, find(isCanvasMode)*2])) = [];
            if isfield(S, 'CanvasMode'); S = rmfield(S, 'CanvasMode'); end

            % Assign the type defaults first and the caller's options
            % second. An option can set other properties in its set
            % method (a Toolbar's Orientation sets IsFixedSize), and a
            % type default assigned after it would undo that.
            S = rmfield(S, intersect(fieldnames(S), callerNames));
            defaultArgs = cat(1, fieldnames(S)', struct2cell(S)');
            parseInputs@uim.mixin.NameValueAssignable(obj, defaultArgs{:})
            parseInputs@uim.mixin.NameValueAssignable(obj, callerArgs{:})
        end

        function assignComponentCanvas(obj)
        %assignComponentCanvas Assign component canvas
            if ~isempty(obj.Canvas)
                % Canvas already inherited from a private-canvas parent
                % Container (see Component's constructor).
            elseif isa(obj.Parent, 'uim.UIComponentCanvas')
                obj.Canvas = obj.Parent;
            else
                obj.Canvas = uim.UIComponentCanvas.getOrCreate(obj.Parent);
            end

            if isa(obj.Canvas, 'matlab.graphics.axis.Axes')
                obj.CanvasAxes = obj.Canvas;
            else
                obj.CanvasAxes = obj.Canvas.Axes;
            end
        end

        function createBackground(obj) % Subclasses can override
        %createBackground Plot the component background

            % Make a patch, without spatial extent
            obj.Background = patch(obj.CanvasAxes, nan, nan, 'w');

            % Set interactive properties
            obj.Background.HitTest = 'off';
            obj.Background.PickableParts = 'none';

            % Set style properties
            obj.Background.EdgeColor = 'none';
            obj.Background.FaceAlpha = 0;
        end

        function createBorder(obj) % Subclasses can override
        %createBorder Plot the component border

            % Why not just use the edge of the patch??
            %   -If we want to create more advanced borders...
        end
    end

    methods % Set/Get

        function set.IsConstructed(obj, newValue)
            obj.IsConstructed = newValue;

            if obj.IsConstructed
                obj.onConstructed()
            end
        end

        function set.CanvasMode(obj, newValue)

            % Canvasmode can only be changed for containers.
            if isa(obj, 'uim.abstract.Control')
                error('Can not set CanvasMode for components derived from Control')
            elseif isa(obj, 'uim.abstract.Container')
                newValue = validatestring(newValue, {'shared', 'private'});
                obj.CanvasMode = newValue;
            end
        end

        function pos = get.CanvasPosition(obj)
            switch obj.CanvasMode
                case 'shared'
                    pos = obj.Position;
                case 'private'
                    pos = [0,0,obj.Position(3:4)];
            end
        end

        function set.Size(obj, newValue)
            % An explicit size assignment opts out of auto-layout;
            % otherwise the next parent resize recomputes and clobbers it.
            obj.switchSizeMode('manual')
            obj.Position_(3:4) = newValue;
            if strcmp(obj.PositionMode, 'auto')
                obj.setAutoLocation()
            end
        end

        function size = get.Size(obj)
            size = obj.Position_(3:4);
        end

        function set.Position(obj, newPosition)
            obj.switchPositionMode('manual')
            obj.Position_ = newPosition;
        end

        function position = get.Position(obj)
            position = obj.Position_;
        end

        function set.Position_(obj, newPosition)

            oldPosition = obj.Position_;

            % Clamp size to the allowed range. This is the single path
            % every size change (set.Size, set.Position, updateSize's
            % auto-computation) ultimately flows through.
            newPosition(3:4) = min(max(newPosition(3:4), obj.MinimumSize), obj.MaximumSize);

            % Check if it was size and/or location that changed.
            isSizeChanged = any(newPosition(3:4) ~= obj.Position_(3:4));
            isLocationChanged = any(newPosition(1:2) ~= obj.Position_(1:2));

            obj.Position_= newPosition;

            % if isSizeChanged && isLocationChanged
            %   obj.onPositionChanged
            % elseif isSizeChanged
            %   obj.onSizeChanged
            % elseif isLocationChanged
            %   obj.onLocationChanged
            % end

            % Update size first
            if isSizeChanged
                obj.onSizeChanged(oldPosition, newPosition)
            end

            % Update location second
            if isLocationChanged
                obj.onLocationChanged(oldPosition, newPosition)
            end
        end

        function set.Location(obj, newValue)
            obj.Location = newValue;
            %obj.switchPositionMode('auto')
            obj.updateLocation('auto')
        end

        function set.Margin(obj, newValue)
            obj.Margin = newValue;
            obj.updateSize()
            obj.updateLocation('auto')
        end

        function set.Padding(obj, newValue)
            obj.Padding = newValue;
            obj.redraw() % todo...
        end

        function set.HorizontalAlignment(obj, newValue)
            obj.HorizontalAlignment = newValue;
            obj.updateLocation('auto')
        end

        function set.VerticalAlignment(obj, newValue)
            obj.VerticalAlignment = newValue;
            obj.updateLocation('auto')
        end

        function set.BackgroundColor(obj, newValue)
            obj.BackgroundColor = newValue;
            obj.onStyleChanged()
        end

        function set.ForegroundColor(obj, newValue)
            obj.ForegroundColor = newValue;
            obj.onStyleChanged()
        end

        function set.BackgroundAlpha(obj, newValue)
            obj.BackgroundAlpha = newValue;
            obj.onStyleChanged()
        end

        function set.BorderColor(obj, newValue)
            obj.BorderColor = newValue;
            obj.onStyleChanged()
        end

        function set.CornerRadius(obj, newValue)
            obj.CornerRadius = newValue;
            obj.onShapeChanged()
        end

        function set.MinimumSize(obj, newValue)
            obj.MinimumSize = newValue;
            % Re-clamp through Position_ (not Size): set.Size would also
            % switch an auto-sized component to manual size mode.
            obj.Position_ = obj.Position_;
        end

        function set.MaximumSize(obj, newValue)
            obj.MaximumSize = newValue;
            % Re-clamp through Position_ (not Size): set.Size would also
            % switch an auto-sized component to manual size mode.
            obj.Position_ = obj.Position_;
        end

        function set.Visible(obj, newValue)
            if ~isequal(obj.Visible, newValue)
                obj.Visible = newValue;
                obj.onVisibleChanged(newValue)
            end
        end

    end

    methods (Access = protected) % Update position / size / appearance

        function redraw(obj)
            if obj.IsConstructed
                if ~obj.IsDrawCompleted; obj.IsDrawCompleted = true; end
                obj.redrawBackground()
            end
        end

        function resize(obj)
        	obj.redrawBackground()
            obj.redrawBorder()
        end

        function relocate(obj, ~)
            obj.redrawBackground()
            %obj.moveBackground(shift)
        end

        function move(obj, shift)
            obj.relocate(shift)
        end

        function updateSize(obj, mode)
        %updateSize Handler of conditions that update component size
        %
        %   Calculate new size based on size of parent container and
        %   internal properties (margins) that determine the size.

            % Abort if component has not finished construction. No need to
            % go through this before all position-related properties are set.
            if ~obj.IsConstructed_; return; end

            if nargin == 2; obj.switchSizeMode(mode); end
            if strcmp(obj.SizeMode, 'manual'); return; end

            if isa(obj.Parent, 'uim.UIComponentCanvas')
                parentSize = obj.Parent.Size;
            elseif isa(obj.Parent, 'uim.abstract.Component')
                parentSize = obj.Parent.Position(3:4);
            elseif isa(obj.Parent, 'matlab.graphics.Graphics')
                parentPosition = uim.utility.getContentPixelPosition(obj.Parent);
                parentSize = parentPosition(3:4);
% %             elseif isa(obj.Parent, 'matlab.graphics.axis.Axes')
% %                 parentSize = obj.Parent.Position(3:4);
% %             elseif isa(obj.Parent, 'matlab.ui.Figure')
% %                 parentSize = obj.Parent.Position(3:4);
            else
                parentSize = obj.Parent.Position(3:4);
            end

            % Initialize newSize based on current size
            newSize = obj.Size;

            % Then recalculate based on parent size and margins.
            if ~obj.IsFixedSize(1)
                newSize(1) = parentSize(1) - sum(obj.Margin([1,3]));
            end

            if ~obj.IsFixedSize(2)
                newSize(2) = parentSize(2) - sum(obj.Margin([2,4]));
            end

            obj.Position_(3:4) = newSize;
        end

        function updateLocation(obj, mode)
        %updateLocation Handler of conditions that change component location
        %
        % This method is triggered either if the parent size changes or if
        % any of the location related properties are set to new values.
        %
        % If PositionMode is auto, the position of the component is
        % calculated based on Location, Anchorpoint and margins.
        % If PositionMode is manual, the values of the position property is
        % used.

            % Abort if component has not finished construction. No need to
            % go through this before all position-related properties are set.
            if ~obj.IsConstructed_; return; end

            if nargin == 2
                obj.PositionMode = mode;
            end

            switch obj.PositionMode
                case 'auto'
                    obj.setAutoLocation()
                case 'manual'
                    % Location should stay the same.
            end
        end
    end

    methods (Access = private) % Internal Updates

        function setAutoLocation(obj)
        %setAutoLocation Calculate component's location based on properties

            % Find the reference point in the parent container based on the
            % value of the Location property.
            if isa(obj.Parent, 'uim.UIComponentCanvas')
                %parentSize = obj.Parent.Size;
                locationPoint = obj.Parent.getLocationPoint(obj.Location);

            elseif obj.isMatlabGraphicsParent(obj.Parent)
                parentPos = uim.utility.getContentPixelPosition(obj.Parent);
                parentSize = parentPos(3:4);
                locationPoint = obj.location2point(parentSize, obj.Location);
            else
                warning('Parent of type %s is not supported', class(obj.Parent))
                locationPoint = [1,1];
            end

            % Find the new location (Position(1:2)) based on the values of
            % anchoring properties (Horizontal/Vertical alignment)
            newLocation = locationPoint;

            % Todo: Is this needed ???
            if contains(obj.Location, 'west')
                newLocation(1) = locationPoint(1) + obj.Margin(1);
            elseif contains(obj.Location, 'east')
                newLocation(1) = locationPoint(1) - obj.Size(1) - obj.Margin(3);
            end

            if contains(obj.Location, 'south')
                newLocation(2) = locationPoint(2) + obj.Margin(2);
            elseif contains(obj.Location, 'north')
                newLocation(2) = locationPoint(2) - obj.Size(2) - obj.Margin(4);
            end

            % Set horizontal offset based on margin properties
            if strcmp(obj.Location, 'south') || strcmp(obj.Location, 'north')
                newLocation(1) = locationPoint(1) + obj.Margin(1);
            end

            if strcmp(obj.Location, 'center')
                newLocation(1) = locationPoint(1) + obj.Margin(1);
                newLocation(2) = locationPoint(2) + obj.Margin(2);
            end

% %             % Centered along horizontal dimension
% %             if strcmp(obj.Location, 'south') || strcmp(obj.Location, 'north')
% %                 newLocation(1) = (parentSize(1)-obj.Size(1)) / 2;
% %             end
% %
% %             % Centered along vertical dimension
% %             if strcmp(obj.Location, 'east') || strcmp(obj.Location, 'west')
% %                 newLocation(2) = (parentSize(2)-obj.Size(2)) / 2;
% %             end

            switch obj.HorizontalAlignment
                case 'left'
                    % Do nothing
                case 'center'
                    newLocation(1) = newLocation(1) - obj.Size(1)/2;
                case 'right'
                    newLocation(1) = newLocation(1) - obj.Size(1);
            end

            switch obj.VerticalAlignment
                case 'bottom'
                    % Do nothing
                case 'middle'
                    newLocation(2) = newLocation(2) - obj.Size(2)/2;
                case 'top'
                    newLocation(2) = newLocation(2) - obj.Size(2);
            end

            obj.Position_(1:2) = newLocation;
        end

        function switchPositionMode(obj, newMode)
        %switchPositionMode Update position mode
            obj.PositionMode = newMode;
            %obj.SizeMode = newMode; Todo: Need to test this.
        end % protected?

        function switchSizeMode(obj, newMode)
        %switchSizeMode Update position mode
            obj.SizeMode = newMode;
        end % protected?

        function redrawBorder(obj)
            % Should this be done together with redrawBackground
        end

        function moveBackground(obj, shift)
            if ~isempty(obj.Background) && obj.IsConstructed
                if shift(1) ~= 0
                    obj.Background.XData = obj.Background.XData + shift(1);
                end
                if shift(2) ~= 0
                    obj.Background.YData = obj.Background.YData + shift(2);
                end
            end
            %drawnow limitrate
        end

    end

    methods (Access = protected)

        function redrawBackground(obj)

            if ~isempty(obj.Background) && obj.IsConstructed

                [X, Y] = uim.shape.rectangle(obj.Size, obj.CornerRadius);

                if strcmp(obj.CanvasMode, 'shared')
                    X = X + obj.Position_(1);
                    Y = Y + obj.Position_(2);
                end

                set(obj.Background, 'XData', X, 'YData', Y)
            end
        end

        function onConstructed(obj)

            if obj.IsConstructed

            	% Todo: This is not perfect. Sometimes size depends on
                % location...

                % Check if position was set different than default. if so, mode is manual

                % Call updateSize to trigger size update (call before location)
                obj.updateSize(obj.SizeMode)

                % Call updateLocation to trigger location update
                obj.updateLocation(obj.PositionMode)

                % Set style
                obj.onStyleChanged()

                if ~obj.IsDrawCompleted
                    obj.redraw()
                end
            end
        end

        function onSizeChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end

            switch obj.CanvasMode
                case 'shared'
                    obj.resize()
                    evtData = uim.event.SizeChangedData(oldPosition(3:4), newPosition(3:4));
                    obj.notify('SizeChanged', evtData)
                case 'private'
                    obj.CanvasAxes.Position = newPosition;
                    obj.CanvasAxes.XLim = [1, newPosition(3)];
                    obj.CanvasAxes.YLim = [1, newPosition(4)];
                    obj.resize()
            end
        end

        function onLocationChanged(obj, oldPosition, newPosition)
            if ~obj.IsConstructed; return; end

            switch obj.CanvasMode
                case 'shared'
                    obj.relocate(newPosition-oldPosition)
                    evtData = uim.event.LocationChangedData(oldPosition(1:2), newPosition(1:2));
                    obj.notify('LocationChanged', evtData)
                case 'private'
                    % Only need to set new position of axes in parent
                    setpixelposition(obj.CanvasAxes, newPosition)
                    %obj.CanvasAxes.Position = newPosition;
            end
        end

        function onStyleChanged(obj)
            if ~isempty(obj.Background) && obj.IsConstructed
                obj.Background.FaceColor = obj.BackgroundColor;
                obj.Background.FaceAlpha = obj.BackgroundAlpha;
                obj.Background.EdgeColor = obj.BorderColor;
                obj.Background.LineWidth = obj.BorderWidth;
            end
        end

        function onShapeChanged(obj)
            % todo: create an updateBackground method in addition to
            % updateSize

            obj.redrawBackground()
            %obj.redrawBorder() Not implemented yet
        end
    end

    methods (Hidden, Access = protected)

        function onVisibleChanged(~, ~)
            % Subclass should override
        end
    end

    methods (Access = private) % Callbacks for listeners on parent container

        function onParentContainerSizeChanged(obj, ~, ~)
            obj.updateSize()
            obj.updateLocation()
        end

        function onParentContainerLocationChanged(obj, ~, evt)
            shift = evt.NewLocation - evt.oldLocation;
            obj.Position_(1:2) = obj.Position_(1:2) + shift;
        end
    end

    methods % Wrappers for placing matlab components

        function hContainer = getGraphicsContainer(obj)
        %getGraphicsContainer Return the graphics container for child components
        %
        %   hContainer = obj.getGraphicsContainer() returns the object that
        %   components created with obj as their parent are placed in.
        %   Component returns its own Parent; subclasses that own a
        %   graphics container, such as uim.container.Panel, return that.
            hContainer = obj.Parent;
        end

        function pos = getpixelposition(obj, recursive)
        %getpixelposition Return the component position in pixels
        %
        %   pos = obj.getpixelposition() returns Position, offset by the
        %   pixel position of the graphics container returned by
        %   getGraphicsContainer (for a UIComponentCanvas, by the position
        %   of its axes) within that container's parent.
        %
        %   pos = obj.getpixelposition(recursive) with recursive true
        %   offsets by the container's position relative to the figure
        %   instead. pos is [x, y, width, height] in pixels.
        %
        %   See also getpixelposition
            if nargin < 2; recursive=false; end

            hContainer = obj.getGraphicsContainer();
            if isa(hContainer, 'uim.UIComponentCanvas')
                % Component positions are canvas-local; the canvas axes
                % rect is the pixel frame they live in (this also holds
                % for overlay canvases covering a data axes).
                parentPos = getpixelposition(hContainer.Axes, recursive);
            else
                parentPos = getpixelposition(hContainer, recursive);
            end

            pos = obj.Position;
            pos(1:2) = pos(1:2) + parentPos(1:2);
        end
    end

    methods (Hidden) % Wrappers for placing matlab components (shadow builtins)

        function h = uicontrol(obj, varargin)
            h = uicontrol(obj.getGraphicsPlacementParent(), varargin{:});
        end

        function h = uitable(obj, varargin)
            h = uitable(obj.getGraphicsPlacementParent(), varargin{:});
        end

        function h = axes(obj, varargin)
            h = axes(obj.getGraphicsPlacementParent(), varargin{:});
        end
    end

    methods (Access = private)

        function hParent = getGraphicsPlacementParent(obj)
        %getGraphicsPlacementParent Real graphics object that can parent controls
        %
        %   A component's graphics container may be a UIComponentCanvas,
        %   which can not parent MATLAB controls; resolve to the container
        %   hosting the canvas axes in that case.
            hParent = obj.getGraphicsContainer();
            if isa(hParent, 'uim.UIComponentCanvas')
                hParent = hParent.Axes.Parent;
            end
        end
    end

    methods (Static)

        function S = getTypeDefaults() % Subclasses can override
        %getTypeDefaults Return default property values for the component type
        %
        %   S = uim.abstract.Component.getTypeDefaults() returns a struct
        %   whose field names are property names and whose values are the
        %   defaults the constructor uses. A name-value argument for the
        %   same property replaces the default. Component returns an empty struct; subclasses
        %   override it to give type-specific defaults.
            S = struct();
        end

        function locationPoint = location2point(containerSize, locationKey)
        %location2point Convert a location key to a point in a container
        %
        %   locationPoint = uim.abstract.Component.location2point(
        %       containerSize, locationKey) returns the [x, y] reference
        %   point, in pixels and rounded to integers, that locationKey
        %   names in a container of size containerSize ([width, height]).
        %   Keys containing 'north' give y = height and keys containing
        %   'east' give x = width; otherwise x and y are 1. 'north' and
        %   'south' center x, 'east' and 'west' center y, and 'center'
        %   returns containerSize/2.
        %
        %   Also used by uim.UIComponentCanvas.getLocationPoint.

            locationPoint = [1,1]; % Southwest

            if contains(locationKey, 'north')
                locationPoint(2) = containerSize(2);
            end

            if contains(locationKey, 'east')
                locationPoint(1) = containerSize(1);
            end

            % Center along x-dimension
            if strcmp(locationKey, 'south') || strcmp(locationKey, 'north')
                locationPoint(1) = containerSize(1)/2;
            end

            % Center along y-dimension
            if strcmp(locationKey, 'west') || strcmp(locationKey, 'east')
                locationPoint(2) = containerSize(2)/2;
            end

            if strcmp(locationKey, 'center')
                locationPoint = containerSize/2;
            end

            locationPoint = round( locationPoint );
        end

        function tf = isMatlabGraphicsParent(h)
        %isMatlabGraphicsParent Test if a handle is a supported graphics container
        %
        %   tf = uim.abstract.Component.isMatlabGraphicsParent(h) returns
        %   true if h is a figure, axes, uipanel or uitab, and false
        %   otherwise.

        % Todo: Can I generalize this... Is there a shared superclass? Are
        % there any obvious types missing from the list?

            validGraphicsParents = {...
                'matlab.ui.Figure', ...
                'matlab.graphics.axis.Axes', ...
                'matlab.ui.container.Panel', ...
                'matlab.ui.container.Tab' ...
                };

            tf = false;

            % Check if given handle is any of the allowed parents
            for i = 1:numel(validGraphicsParents)

                if isa(h, validGraphicsParents{i})
                    tf = true;
                    return
                end
            end
        end
    end
end

% Dones
%       [x] Make this into a component super class. (from virtualContainer
%       [x] Remove Children property, and add that to a container subclass.
%       [x] Rename adjustSize to updateSize
%       [-] Inherit structadapter
%       [x] Add anchoring position mode. (Think this is done)
%       [-] Add a sizeChangedFcn prop? Like matlab containers have? Why???
%       [-] Add/implement units property? NO! This is pixelbased!
%
%       [x] Split into component and container.
%
%       [x] rename onSizeChanged & onLocationChanged to updateSize &
%           updateLocation. onSizeChanged should be called after the
%           position is set...
%       [x] Add a abstract static method called getTypeDefaults?
%       This would be a method that when implemented returns default values
%       for a specific type. Alternative to make all properties abstract,
%       and give option for having different default values of subclass
%       properties.
