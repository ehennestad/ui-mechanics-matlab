classdef Toolbar < uim.abstract.Container
%Toolbar Row of buttons and separators drawn on a component canvas
%
%   A toolbar lays out buttons (uim.control.Button) and separators
%   (uim.decorator.Separator) in a row, one after the other, and draws a
%   translucent background behind them. Use it to put tool buttons over
%   an image or plot, for example to switch pointer tools (see
%   uim.interface.PointerToolBinding).
%
%   toolbar = uim.widget.Toolbar(parent) creates an empty toolbar in
%   parent: a uim.UIComponentCanvas, a uim container, an axes (an overlay
%   canvas is created or reused), or a graphics container such as a
%   uipanel. By default the toolbar is horizontal, anchored at the
%   'northwest' location, 30 pixels high, and shrinks along its length
%   to fit its buttons.
%
%   toolbar = uim.widget.Toolbar(parent, Name=Value) also sets public
%   properties, including those inherited from uim.abstract.Component
%   (Location, Margin, Padding, BackgroundAlpha, ...). CanvasMode="private"
%   draws the toolbar in its own axes instead of the parent's canvas; this
%   is not supported when parent is an axes and raises
%   uim:Container:PrivateCanvasUnsupportedOnOverlay.
%
%   Two options do not take full effect at construction, because the type
%   defaults (see getTypeDefaults) are assigned after them: Orientation is
%   overridden by the IsFixedSize default, and the background colours that
%   DarkMode="off" sets are overridden by the BackgroundColor and
%   BackgroundAlpha defaults. Set these two properties after
%   construction, and set Orientation before adding buttons.
%
%   Example:
%       toolbar = uim.widget.Toolbar(hAxes, Location="northeast");
%       button = toolbar.addButton(Text="Run", Tag="RunButton");
%       toolbar.addSeparator();
%
%   Main properties:
%       Spacing, ComponentAlignment, DarkMode, BackgroundMode,
%       BarExtensionMode, NewButtonSize, Orientation, NumButtons
%
%   Main methods:
%       addButton    - Add a button at the end of the toolbar
%       addSeparator - Add a separator at the end of the toolbar
%       removeButton - Remove a button or separator
%       getHandle    - Find buttons and separators by tag
%
%   See also uim.control.Button, uim.decorator.Separator,
%   uim.interface.PointerToolBinding, uim.widget.TabBar

    % Check out dropbox paper toolbar.

    % todo:
    %
    %   [x] add separator... I think this is done
    %   [ ] Implement orientation functionality. See uim.widget.Toolbar
    %   [ ] Make sure button size is adapted to toolbar size + padding.
    %   [x] Rename BackgroundMode to ContainerMode (move to container?)
    %   [ ] Remove DarkMode property. Use Style
    %   [ ] Move dimL_ and dimS_ to component or container??
    %   [ ] Move spacing to Container
    %   [ ] Move componentAlignment to component? Actually, is this the
    %       same as reference points??? Componentalignment is only relevant
    %       if containermode is "wrap"
    %   [ ] Simplify orientation-related properties. I.e now, there is
    %       IsFixedSize, dimL_, dimS, Orientation. COmment later: YES, this
    %       is confusing!
    %   [ ] Style
    %   [ ] Make it clearer what shiftChildren and repositionButtons do,
    %   and how they are different...
    %   [x] Resolve how to combine backgroundmode 'wrap' and canvasMode 'private'

    properties (Constant, Transient)
        Type = 'Toolbar' % Component type name
    end

    properties (SetAccess = protected, Transient)
        Children uim.abstract.Component % Buttons added with addButton (separators are not included)
    end

    properties
        % Spacing - Gap between neighbouring buttons and separators, in pixels
        Spacing = 8 % move to widget container

        % DarkMode - 'on' (dark translucent background, light buttons) or
        % 'off' (white translucent background, dark buttons). Setting it
        % restyles the background and gives existing buttons
        % uim.style.ButtonDarkMode ('on') or
        % uim.style.ButtonLightModeTranslucent ('off'); buttons added
        % later get the Style value.
        DarkMode = 'on'

        % ComponentAlignment - Where the buttons sit along the toolbar:
        % 'left' (or 'top'), 'center' (or 'middle'), or 'right' (or 'bottom')
        ComponentAlignment = 'left'

        % Style - Button style for buttons added with addButton. Reading it
        % returns uim.style.ButtonDarkMode when DarkMode is 'on' and
        % uim.style.ButtonLightMode when it is 'off'; assigned values are
        % not used.
        Style = []

        % BackgroundMode - 'wrap' draws the background only around the
        % buttons; 'full' fills the whole toolbar position
        BackgroundMode = 'wrap'

        % BarExtensionMode - 'tight' sizes the toolbar to fit its buttons
        % along its length, and across it unless IsFixedSize fixes that
        % side; 'expanded' lets the toolbar take the size computed by the
        % layout along its length
        BarExtensionMode = 'tight'
    end

    properties (Dependent)
        % Height - Toolbar height in pixels (Size(2)); setting it switches
        % SizeMode to 'manual'
        Height % move to widget container

        % Width - Toolbar width in pixels (Size(1)); setting it switches
        % SizeMode to 'manual'
        Width % move to widget container

        % Orientation - 'horizontal' or 'vertical'. Derived from IsFixedSize:
        % a horizontal toolbar has a fixed height, a vertical one a fixed
        % width. Set it before adding buttons; existing buttons are not
        % moved.
        Orientation
    end

    properties (Dependent, Transient, Access = private)
        DimL_ (1,1) double  % Long Dimension
        DimS_ (1,1) double  % Short dimension
    end

    properties (Access = public)
        NewButtonSize double = 25; % Width and height in pixels of buttons added next, unless addButton is given a Size
    end

    properties (Access = protected)
        NextButtonPosition (1,4) double = zeros(1,4) % Position (x,y) of next button
        AllButtonPosition = zeros(0,4) % for faster repositioning
    end

    properties (SetAccess = protected)
        NumButtons (1,1) double = 0 % Number of buttons and separators in the toolbar
    end

    properties (Access = protected, Transient)
        Buttons uim.abstract.Component
        ButtonSizeChangedListener event.listener
    end

    methods % Structors

        function obj = Toolbar(hParent, varargin)
        %Toolbar Create an empty toolbar
        %
        %   toolbar = uim.widget.Toolbar(parent)
        %   toolbar = uim.widget.Toolbar(parent, Name=Value)
        %
        %   See the class help for the accepted parents and options.

            obj@uim.abstract.Container(hParent, varargin{:})

            % Toolbar specific construction....

            obj.IsConstructed = true;

            obj.setNextButtonPosition()
        end

        function delete(obj)
            % Delete all buttons and separators.
            delete(obj.Buttons)
            delete(obj.ButtonSizeChangedListener)
        end
    end

    methods % Methods to add toolbar objects

        function hSep = addSeparator(obj, varargin)
        %addSeparator Add a separator at the end of the toolbar
        %
        %   toolbar.addSeparator() adds a uim.decorator.Separator after the
        %   last button. The separator has zero width and the height of a
        %   new button (NewButtonSize), and is followed by the usual
        %   Spacing.
        %
        %   hSep = toolbar.addSeparator(Name=Value) passes the options to
        %   uim.decorator.Separator (for example Color or LineWidth) and
        %   returns the separator. Its Visible value always follows the
        %   toolbar.
        %
        %   See also uim.decorator.Separator

            separatorPosition = obj.NextButtonPosition;

            % todo: switch orientation...
            separatorPosition(3) = 0;

            varargin = [{'Position', separatorPosition, ...
                         'Size', separatorPosition(3:4), ...
                         'PositionMode', 'manual', ...
                         'SizeMode', 'manual'}, varargin, ...
                         'Visible', obj.Visible];

            hSep = uim.decorator.Separator(obj, varargin{:});

            % Add listener for SizeChanged event on button
            el = addlistener(hSep, 'SizeChanged', @obj.onButtonSizeChanged);
            obj.ButtonSizeChangedListener(end+1) = el;

            obj.AllButtonPosition(end+1, :) = hSep.Position;

            obj.Buttons(end+1) = hSep;

            obj.NumButtons = obj.NumButtons+1;

            obj.adjustButtonPositions()
            obj.setNextButtonPosition()

            if ~nargout
                clear hSep
            end
        end

        function hButton = addButton(obj, varargin)
        %addButton Add a button at the end of the toolbar
        %
        %   hButton = toolbar.addButton(Name=Value) creates a
        %   uim.control.Button after the last button and returns it. The
        %   options are passed to uim.control.Button, for example Text,
        %   Icon, Tag, Tooltip, Mode or Callback.
        %
        %   The toolbar supplies these defaults, which the options can
        %   override: Position at the next free slot, Size of
        %   [NewButtonSize, NewButtonSize] pixels, Padding [3, 3, 3, 3],
        %   Style from the toolbar's Style property, and Visible from the
        %   toolbar. PositionMode is always 'manual': the toolbar places
        %   its buttons. With BarExtensionMode 'tight' the toolbar grows
        %   to fit the new button.
        %
        %   Example:
        %       icons = uim.style.getDefaultIcons();
        %       button = toolbar.addButton(Icon=icons.zoomIn, ...
        %           Mode="togglebutton", Tooltip="Zoom in");
        %
        %   See also uim.control.Button

            % Specify some toolbar defaults for toolbar button.
            varargin = [{'Position', obj.NextButtonPosition, ...
                        'Style', obj.Style}, ...
                        'Size', obj.NextButtonPosition(3:4), ...
                        'Padding', [3,3,3,3], ...
                        'Visible', obj.Visible, varargin, ...
                        'PositionMode', 'manual'];

            % Concatenate with varargin at the end. Input parser will
            % choose the last entry (if there are duplicates) during parsing.

            hButton = uim.control.Button(obj, varargin{:});

            % Add listener for SizeChanged event on button
            el = addlistener(hButton, 'SizeChanged', @obj.onButtonSizeChanged);
            obj.ButtonSizeChangedListener(end+1) = el;

            obj.AllButtonPosition(end+1, :) = hButton.Position;
            obj.Buttons(end+1) = hButton;
            obj.Children(end+1) = hButton;

            obj.NumButtons = obj.NumButtons+1;

            obj.adjustButtonPositions()
            obj.setNextButtonPosition()

            if strcmp(obj.BarExtensionMode, 'tight')
                obj.updateSize()
            end

            % Update location after buttons are created..
            if strcmp(obj.PositionMode, 'auto')
                %todo: how to do this?
                %obj.updateLocation()
            end

            if ~nargout
                clear hButton
            end
        end

        function h = getHandle(obj, tagValue)
        %getHandle Find buttons and separators by tag
        %
        %   h = toolbar.getHandle(tagValue) returns the buttons and
        %   separators whose Tag contains tagValue. The match is a
        %   case-sensitive substring match, so h can hold several handles
        %   ("zoomIn" also matches "zoomInFast") or none.

            tags = {obj.Buttons.Tag};
            ind = contains(tags, tagValue);
            h = obj.Buttons(ind);
        end

        function removeButton(obj, hButton)
        %removeButton Remove a button or separator from the toolbar
        %
        %   removeButton(obj, hButton) detaches hButton from the
        %   toolbar's bookkeeping, deletes it, and re-lays-out the
        %   remaining buttons. Handles not added to this toolbar are
        %   ignored.

            arguments
                obj (1,1) uim.widget.Toolbar
                hButton (1,1) uim.abstract.Component
            end

            isMatch = obj.Buttons == hButton;
            if ~any(isMatch); return; end

            delete(obj.ButtonSizeChangedListener(isMatch))
            obj.ButtonSizeChangedListener(isMatch) = [];

            obj.Buttons(isMatch) = [];
            obj.AllButtonPosition(isMatch, :) = [];
            obj.NumButtons = obj.NumButtons - nnz(isMatch);
            obj.Children(obj.Children == hButton) = [];

            if isvalid(hButton)
                delete(hButton)
            end

            obj.repositionButtons()
            obj.setNextButtonPosition()

            if strcmp(obj.BarExtensionMode, 'tight')
                obj.updateSize()
            end
        end
    end

    methods (Access = protected)

        function relocate(obj, shift)
            relocate@uim.abstract.Component(obj, shift)
            obj.shiftChildren(shift)
        end

        function onButtonSizeChanged(obj, src, ~)
        %onButtonSizeChanged Update buttonsize and reposition all other buttons

            isButton = ismember(obj.Buttons, src);
            obj.AllButtonPosition(isButton, :) = src.Position;
            obj.repositionButtons()
        end

        function updateLocation(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            updateLocation@uim.abstract.Component(obj, mode)

            switch obj.BarExtensionMode
                case 'expanded'
                    obj.adjustButtonPositions()
            end
        end

        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            if ~obj.IsConstructed; return; end

            switch obj.BarExtensionMode
                case 'expanded'
                    updateSize@uim.abstract.Component(obj, mode)
                    obj.adjustButtonPositions()

                case 'tight'
                    obj.setBarSizeToTight()
            end
        end
    end

    methods (Access = protected)

        function setBarSizeToTight(obj)
        % setBarSizeToTight - Make toolbar size tight around buttons.

            dimS = obj.DimS_;

            [~, extent] = obj.getButtonExtentAlongLength();

            % A short side fixed by IsFixedSize keeps its set size, so
            % Size [inf, 20] stays a 20 px high bar
            if obj.IsFixedSize(dimS)
                extent(dimS) = obj.Position_(dimS+2);
            elseif obj.NumButtons == 0
                extent(dimS) = obj.CanvasPosition(dimS+2);
            else
                extent(dimS) = max(obj.AllButtonPosition(:, dimS+2), [], 1);
            end

            obj.Position_(3:4) = extent;

            % Re-anchor after the size change: writing Position_ directly
            % bypasses set.Size, so a location-anchored toolbar (e.g.
            % 'northeast') would otherwise grow away from its anchor.
            % (updateLocation is a no-op when PositionMode is 'manual'.)
            % The buttons then need an absolute reposition from the new
            % bar origin — moving the bar does not move its buttons.
            obj.updateLocation()
            obj.repositionButtons()
        end

        function [minPositionL, extent] = getButtonExtentAlongLength(obj)
        % getButtonExtentAlongLength - Get button min position and total
        % extent along the toolbar's length dimension (DimL_).

            dimL = obj.DimL_;

            if obj.NumButtons == 0
                minPositionL = 0;
                maxPositionL = 0;
            else
                minPositionL = min(obj.AllButtonPosition(:, dimL), [], 1);
                maxPositionL = max( sum(obj.AllButtonPosition(:, [dimL, dimL+2]),2), [], 1);
            end

            extent = zeros(1,2);
            extent(dimL) = maxPositionL - minPositionL + sum(obj.Padding([dimL, dimL+2]));
        end

        function setNextButtonPosition(obj)

            if isempty(obj.AllButtonPosition) % Initialize
                lastButtonPosition = [obj.CanvasPosition(1:2) + obj.Padding(1:2), 0, 0];
            else
                lastButtonPosition = obj.AllButtonPosition(end, :);
            end

            i = obj.DimL_;
            j = obj.DimS_;

            spacing = obj.Spacing .* double(obj.NumButtons>0);

            pos(i) = sum(lastButtonPosition([i,i+2])) + spacing;
            pos(j) = obj.CanvasPosition(j) + obj.Padding(j);
            pos(3:4) = obj.NewButtonSize;

            obj.NextButtonPosition = pos;
        end

        function adjustButtonPositions(obj)
        %adjustButtonPositions Adjust positions of buttons
        %
        %   Use when adding more buttons (i.e if they are centered or
        %   right-aligned)

            if ~obj.IsConstructed; return; end
            if obj.NumButtons == 0; return; end

            % Resolve what is the long and short dimension (x=1, y=2)
            dimL = obj.DimL_;
            dimS = obj.DimS_;

            shift = [0, 0];

            minPosition = min(obj.AllButtonPosition(:, dimL), [], 1);
            maxPosition = max( sum(obj.AllButtonPosition(:, [dimL, dimL+2]),2), [], 1);
            extent = maxPosition - minPosition;

            if any( strcmp(obj.ComponentAlignment, {'left', 'top'}) )
                targetPosition = obj.CanvasPosition(dimL) + obj.Padding(dimL);
                offset = targetPosition - minPosition;

            elseif any( strcmp(obj.ComponentAlignment, {'center', 'middle'}) )
                centerPosition = obj.CanvasPosition(dimL) + obj.Position(dimL+2)/2;
                offset = centerPosition - (minPosition + extent/2);

%                 if strcmp(obj.CanvasMode, 'private') % Todo: Debug
%                     offset = offset/2;
%                 end
            end

            if  any( strcmp(obj.ComponentAlignment, {'right', 'bottom'}) )
                targetPosition = sum(obj.CanvasPosition([dimL, dimL+2])) - obj.Padding(dimL+2) - extent;
                offset = targetPosition-minPosition;
            end

            shift(dimL) = offset;
            shift(dimS) = obj.CanvasPosition(dimS) - obj.AllButtonPosition(1, dimS) + obj.Padding(dimS);

            if any(shift ~= 0)
                obj.shiftChildren(shift)
            end

            %shift

            obj.setNextButtonPosition()

            switch obj.CanvasMode
                case 'shared'

                    if strcmp(obj.BackgroundMode, 'wrap')
                        obj.redrawBackground()
                    end

                    %obj.setNextButtonPosition()

                case 'private'

                    axPosition = getpixelposition(obj.CanvasAxes);
                    axPosition(1:2) = axPosition(1:2) + shift;
                    setpixelposition(obj.CanvasAxes, axPosition);
            end
        end

        function repositionButtons(obj)
        % Use when one or more button sizes change
            if ~obj.IsConstructed; return; end
            if obj.NumButtons == 0; return; end

            % The run is the buttons plus Spacing between neighbours
            numItems = size(obj.AllButtonPosition, 1);
            runLength = sum(obj.AllButtonPosition(:, obj.DimL_+2), 1) + ...
                (numItems - 1) * obj.Spacing;

            toolbarLocation = obj.Position(obj.DimL_) + obj.Padding(obj.DimL_);
            toolbarSize = obj.Position(obj.DimL_+2) - obj.Padding(obj.DimL_) - obj.Padding(obj.DimL_+2);

            anchorPoint = uim.widget.internal.alignRunStart(...
                toolbarLocation, toolbarSize, runLength, obj.ComponentAlignment);

            % Start replacing buttons starting from left/top
            for i = 1:numel(obj.Buttons)
                obj.Buttons(i).Position(obj.DimL_) = anchorPoint;
                obj.AllButtonPosition(i,obj.DimL_) = anchorPoint;
                anchorPoint = anchorPoint + obj.Buttons(i).Position(obj.DimL_+2) + obj.Spacing;
            end

            if strcmp(obj.BackgroundMode, 'wrap')
                obj.redrawBackground()
            end

            setNextButtonPosition(obj)
        end

        function onSpacingChanged(obj, deltaSpacing)

            if ~obj.IsConstructed; return; end

            shifts = zeros(obj.NumButtons, 2);
            shifts(:, obj.DimL_) = deltaSpacing .* (0:obj.NumButtons-1);

            for i = 1:obj.NumButtons
                obj.Buttons(i).Position(1:2) = obj.Buttons(i).Position(1:2) + shifts(i,:);
                obj.AllButtonPosition(i,:) = obj.Buttons(i).Position;
            end

            if strcmp(obj.BackgroundMode, 'wrap')
                obj.redrawBackground()
            end

            obj.setNextButtonPosition()
        end

        function shiftChildren(obj, shift)

            for i = 1:obj.NumButtons
                obj.Buttons(i).Position(1:2) = obj.Buttons(i).Position(1:2) + shift(1:2);
                obj.AllButtonPosition(i,:) = obj.Buttons(i).Position;
            end
        end

        function redrawBackground(obj)

            if ~isempty(obj.Background) && obj.IsConstructed
                switch obj.BackgroundMode
                    case 'full'
                        redrawBackground@uim.abstract.Component(obj)
                    case 'wrap'

                        [minPositionL, extent] = obj.getButtonExtentAlongLength();
                        extent(obj.DimS_) = obj.CanvasPosition(obj.DimS_+2);

                        minPos = zeros(1,2);
                        minPos(obj.DimL_) = minPositionL - obj.Padding(obj.DimL_);
                        minPos(obj.DimS_) = obj.CanvasPosition(obj.DimS_);

                        [X, Y] = uim.shape.rectangle(extent, obj.CornerRadius);
                        X = X + minPos(1);
                        Y = Y + minPos(2);

                        set(obj.Background, 'XData', X, 'YData', Y)

                    otherwise
                        error('This should not happen!')
                end
            end

            %drawnow limitrate
        end

        function updateButtonStyle(obj)

            if ~obj.IsConstructed; return; end

            switch obj.DarkMode
                case 'on'
                    style = uim.style.ButtonDarkMode;
                case 'off'
                    style = uim.style.ButtonLightModeTranslucent;
            end

            for i = 1:numel(obj.Buttons)
                if isa(obj.Buttons(i), 'uim.control.Button')
                    obj.Buttons(i).Style = style;
                end
            end
        end

        function updateBackgroundAppearance(obj)

            switch obj.DarkMode
                case 'on'
                    obj.BackgroundAlpha = 0.2;
                    obj.BackgroundColor = 'k';
                case 'off'
                    obj.BackgroundAlpha = 0.7;
                    obj.BackgroundColor = 'w';
            end

            obj.Background.FaceAlpha = obj.BackgroundAlpha;
            obj.Background.FaceColor = obj.BackgroundColor;
        end

        function onVisibleChanged(obj, newValue)
            obj.Background.Visible = newValue;
            for i = 1:obj.NumButtons
                obj.Buttons(i).Visible = newValue;
            end
        end
    end

    methods % Set/get

        function style = get.Style(obj)
            switch obj.DarkMode
                case 'on'
                    style = uim.style.ButtonDarkMode;
                case 'off'
                    style = uim.style.ButtonLightMode;
            end
        end

        function set.DarkMode(obj, newValue)
            validatestring(newValue, {'on', 'off'}, 'Value must be on or off');
            obj.DarkMode = newValue;
            obj.updateBackgroundAppearance()
            obj.updateButtonStyle()
        end

        function set.Spacing(obj, newValue)

            if newValue ~= obj.Spacing
                deltaSpacing = newValue - obj.Spacing;
                % Assign first: onSpacingChanged places the next button
                % with the new Spacing
                obj.Spacing = newValue;
                obj.onSpacingChanged(deltaSpacing);
            end
        end

        function set.ComponentAlignment(obj, newValue)
            if ~isequal(newValue, obj.ComponentAlignment)
                obj.ComponentAlignment = newValue;
                obj.adjustButtonPositions()
            end
        end

        function set.BarExtensionMode(obj, newValue)
            validatestring(newValue, {'tight', 'expanded'});
            obj.BarExtensionMode = newValue;
            obj.updateLocation(obj.PositionMode)
            obj.updateSize()
        end

        function set.BackgroundMode(obj, newValue)

            validatestring(newValue, {'full', 'wrap'});

            if ~isequal(newValue, obj.BackgroundMode)
                obj.BackgroundMode = newValue;
                obj.redrawBackground()
            end
        end

        function set.Height(obj, newValue)
            obj.Size(2) = newValue;
        end

        function height = get.Height(obj)
            height = obj.Size(2);
        end

        function set.Width(obj, newValue)
            obj.Size(1) = newValue;
        end

        function width = get.Width(obj)
            width = obj.Size(1);
        end

        function value = get.DimL_(obj)
            if obj.IsFixedSize(1) && ~obj.IsFixedSize(2) % X is fixed
                value = 2;
            elseif obj.IsFixedSize(2) && ~obj.IsFixedSize(1) % Y is fixed
                value = 1;
            else
                error('Something is wrong with toolbar configuration')
            end
        end

        function value = get.DimS_(obj)
            if obj.IsFixedSize(2) && ~obj.IsFixedSize(1) % Y is fixed
                value = 2;
            elseif obj.IsFixedSize(1) && ~obj.IsFixedSize(2) % X is fixed
                value = 1;
            else
                error('Something is wrong with toolbar configuration')
            end
        end

        function set.Orientation(obj, newValue)
            switch newValue
                case 'horizontal'
                    obj.IsFixedSize = [false, true];
                case 'vertical'
                    obj.IsFixedSize = [true, false];
            end
        end

        function value = get.Orientation(obj)
            longDim = obj.DimL_;
            if longDim == 1 % x
                value = 'horizontal';
            elseif longDim == 2 % y
                value = 'vertical';
            end
        end
    end

    methods (Static)
        function S = getTypeDefaults()
        %getTypeDefaults Default layout and style values for a new toolbar
        %
        %   S = uim.widget.Toolbar.getTypeDefaults() returns a struct of
        %   property values used at construction; a name-value option for
        %   the same property replaces the default. The defaults describe
        %   a horizontal bar (IsFixedSize [false, true]) of 30 by 30
        %   pixels at the 'northwest' location, Padding [10, 3, 10, 3],
        %   and a black background with BackgroundAlpha 0.2. MinimumSize
        %   is the component default, [10, 10].

            S.PositionMode = 'auto';
            S.Location = 'northwest';
            S.Margin = [0, 0, 0, 0];

            S.IsFixedSize = [false, true];
            S.Size = [30, 30];

            S.HorizontalAlignment = 'left';
            S.VerticalAlignment = 'bottom';

            S.Padding = [10, 3, 10, 3];

            S.MaximumSize = [inf, inf];

            S.BackgroundColor = 'k';
            S.BackgroundAlpha = 0.2;
        end
    end
end
