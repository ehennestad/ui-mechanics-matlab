classdef ChannelIndicator < uim.mixin.NameValueAssignable

    % Copied some properties and methods from PlaybackControl. Should make
    % a super class for simple widgets for placing in an axes, or
    % generalize and inherit from the uim.abstract.Component class....
    %
    %   Should inherit from the abstract widget container class

% - - - - - - - - - - - TODO - - - - - - - - - - - -
%   [ ] Mouse over effect on indicators
%   [ ] Toggle on/off for "buttons"
%   [ ] Add orientation property
%   [ ]
%   [ ]

% - - - - - - - - - - PROPERTIES - - - - - - - - - -

    properties (Dependent)
        Position (1,4) double
    end

    properties (Access = public)
        Visible matlab.lang.OnOffSwitchState = 'on'
        NumChannels = 1
        CurrentChannels = 1
    end

    properties % Appearance
        BackgroundColor = [0.94, 0.94, 0.94];

        ChannelIndicatorSize = 12;
        ChannelIndicatorSpacing = 3;
        ChannelColors = {'r', 'g', 'b', 'c', 'm', 'y'};

        Callback = []
        ChannelColorCallback = []
        % ChangeDefaultsCallback - Callback function that can be attached
        % to respond to changes in default color selection. The function
        % should take a single input, a cell array with numChannels
        % element, where each element is one rgb value, i.e
        %   changeDefaultFcn(cellArrayWithRgbPerChannel)
        ChangeDefaultsCallback = []
    end

    properties (Access = protected)

        ParentApp
        Figure % Window which figure is located in. % Make dependent...
        Axes

        IsAxesInternal

        ChannelIndicators = gobjects(0)
        ChannelForeground = gobjects(0)
    end

    properties (Access = private) % Widget states and internals
        IsConstructed = false
        IsMouseOnButton = false
        IsMouseButtonPressed = false

        LastChannelPressed

        Position_ = [1, 1, 20, 200]; %Initial position

        WindowMouseMotionListener
        WindowMouseReleaseListener
        FrameChangedListener

        ContextMenu
    end

% - - - - - - - - - - - METHODS - - - - - - - - - -

    methods % Structor

        function obj = ChannelIndicator(parentGui, hParent, varargin)

            obj.ParentApp = parentGui;
            obj.Figure = obj.ParentApp.Figure;

            obj.resolveParent(hParent)

            obj.parseInputs(varargin{:})
            obj.createContextMenu()

            obj.IsConstructed = true;

            obj.updateSize()
            obj.createWidgetComponents()
        end
    end

    methods % Set/Get

        function set.Position(obj, newPos)

            assert(isnumeric(newPos) && numel(newPos) == 4, 'Value must be a 4 element vector')
            assert(all(newPos(3:4) > 1), 'This widget does not support normalized position units')
            obj.Position_ = newPos;
        end

        function set.Position_(obj, newPosition)

            % Check if it was size and/or location that changed.
            isSizeChanged = any(newPosition(3:4) ~= obj.Position_(3:4));
            isLocationChanged = any(newPosition(1:2) ~= obj.Position_(1:2));

            obj.Position_ = newPosition;

            % Update size first
            if isSizeChanged
                obj.onSizeChanged()
            end

            % Update location second
            if isLocationChanged
                obj.onLocationChanged()
            end
        end

        function pos = get.Position(obj)
            pos = obj.Position_;
        end

        function set.Visible(obj, newValue)
            obj.Visible = newValue;
            obj.onVisibleChanged()
        end

        function set.NumChannels(obj, newValue)
            obj.NumChannels = newValue;
            obj.onNumChannelsChanged()
        end

        function set.CurrentChannels(obj, newValue)
            obj.CurrentChannels = newValue;
            obj.onCurrentChannelsChanged()
        end

        function set.ChannelColors(obj, value)
            % Todo: Validate input
            oldColors = obj.ChannelColors;
            obj.ChannelColors = value;
            obj.postSetChannelColors(oldColors)
        end
        function postSetChannelColors(obj, oldColors)
            if ~isempty(obj.ChannelIndicators)
                for i = 1:numel(oldColors)
                    if ~isequal(oldColors{i}, obj.ChannelColors{i})
                        obj.updateIndicatorColor(i, obj.ChannelColors{i})
                    end
                end
            end
        end
    end

    methods
        function changeChannelColor(obj, src, ~)
            chNum = obj.LastChannelPressed;

            [colorLabels, colorValues] = obj.getColorOptions();

            switch src.Text
                case colorLabels
                    isMatch = strcmp(colorLabels, src.Text);
                    rgb = colorValues{isMatch};

                case 'Select Color...'
                    rgb = uisetcolor('Select scalebar color');
                    if isequal( rgb, 0)
                        return % User canceled
                    end

                case 'Enter Wavelength...'
                    answer = inputdlg('Enter wavelength (nm)', 'Set Color', 1);
                    if isempty(answer); return; end
                    lambda = str2double(answer{1});
                    rgb = uim.utility.wavelengthToRgb(lambda);
            end
            evtData = uim.event.EventData('ChannelNumber', chNum, ...
                'RgbColor', rgb);

            if ~isempty(obj.ChannelColorCallback)
                obj.ChannelColorCallback(obj, evtData)
            end

            obj.ChannelColors{chNum} = rgb;
        end

        function onChangeDefaultsMenuItemClicked(obj, ~, ~)
            if ~isempty(obj.ChangeDefaultsCallback)
                channelColors = obj.ChannelColors;
                obj.ChangeDefaultsCallback(channelColors)
            end
        end

        function selectChannel(obj, channelNum)
            set(obj.ChannelIndicators, 'EdgeColor', ones(1,3)*0.8);
            set(obj.ChannelIndicators(channelNum), 'LineWidth', 0.5);
            set(obj.ChannelIndicators(channelNum), 'EdgeColor', ones(1,3));
            set(obj.ChannelIndicators(channelNum), 'LineWidth', 1);
        end
    end

    methods (Access = protected) % Widget creation & updates

        function resolveParent(obj, hParent)

            if isa(hParent, 'matlab.graphics.axis.Axes')
                obj.Axes = hParent;
                obj.IsAxesInternal = false;
            else
                obj.createAxes(hParent)
                obj.IsAxesInternal = true;
            end
        end

        function createAxes(obj, hParent)
            obj.Axes = uim.UIComponentCanvas.createComponentAxes(hParent);
        end

        function createWidgetComponents(obj)

            obj.drawIndicators()
            obj.drawIndicatorState()
        end

        function drawIndicators(obj)

            dx = obj.Position(1);

            r = obj.ChannelIndicatorSize/2;
            pad = 3;

            for i = 1:obj.NumChannels

                [X, Y] = uim.shape.circle(r);

                X = X - r + dx + (pad + 2*r) * (i-1);
                Y = Y - r;

                if numel(obj.ChannelIndicators) < i
                    obj.ChannelIndicators(i) = patch(obj.Axes, X, Y, 'w');
                    obj.ChannelIndicators(i).EdgeColor = ones(1,3)*0.8;
                    obj.ChannelIndicators(i).FaceColor = obj.ChannelColors{i};
                    obj.ChannelIndicators(i).FaceAlpha = 0.7;
                    obj.ChannelIndicators(i).ButtonDownFcn = @(s, e) obj.onChannelIndicatorPressed(i);
                    obj.setPointerBehavior(obj.ChannelIndicators(i))
                    obj.ChannelIndicators(i).Tag = 'ChannelIndicator';
                    obj.ChannelIndicators(i).ContextMenu = obj.ContextMenu;

                else
                    set(obj.ChannelIndicators(i), 'XData', X, 'YData', Y)
                end
            end
        end

        function createContextMenu(obj)
            hMenu = uicontextmenu(obj.Figure);

            colorLabels = obj.getColorOptions();
            for i = 1:numel(colorLabels)
                mitem = uimenu(hMenu, 'Text', colorLabels{i});
                mitem.MenuSelectedFcn = @obj.changeChannelColor;
            end

            mitem = uimenu(hMenu, 'Text', 'Select Color...', 'Separator', 'on');
            mitem.MenuSelectedFcn = @obj.changeChannelColor;
            mitem = uimenu(hMenu, 'Text', 'Enter Wavelength...');
            mitem.MenuSelectedFcn = @obj.changeChannelColor;
            mitem = uimenu(hMenu, 'Text', 'Make Current Colors Default', 'Separator', 'on');
            mitem.MenuSelectedFcn = @obj.onChangeDefaultsMenuItemClicked;

            obj.ContextMenu = hMenu;
        end

        function drawIndicatorState(obj)

            dx = obj.Position(1);

            r = obj.ChannelIndicatorSize/2;
            pad = 3;

            theta = deg2rad( [45:90:360, nan] );
            theta = theta([1,3,5,2,4]);

            [X, Y] = pol2cart(theta, ones(size(theta))*r);

            for i = 1:obj.NumChannels

                x0 = dx + (pad + 2*r) * (i-1);
                y0 = 0;

                if numel(obj.ChannelForeground) < i
                    obj.ChannelForeground(i) = plot(obj.Axes, X+x0, Y+y0, 'w');
                    obj.ChannelForeground(i).LineWidth = 1;
                    obj.ChannelForeground(i).Color = ones(1,3)*0.8;
                    obj.ChannelForeground(i).PickableParts = 'none';
                    obj.ChannelForeground(i).HitTest = 'off';
                    obj.ChannelForeground(i).Tag = 'ButtonForeground';
                    set(obj.ChannelForeground(i), 'Visible', 'off')
                    obj.setPointerBehavior(obj.ChannelForeground(i))
                else
                    set(obj.ChannelForeground(i), 'XData', X+x0, 'YData', Y+y0)
                end

                obj.changeIndicatorAppearance(i)
            end
        end

        function changeIndicatorAppearance(obj, channelNum)

            if ismember(channelNum, obj.CurrentChannels) % Channel on
                obj.ChannelForeground(channelNum).Visible = 'off';
                if obj.IsMouseOnButton(channelNum)          % Mouse on
                    obj.ChannelIndicators(channelNum).FaceAlpha = 0.8;
                else                                        % Mouse off
                    obj.ChannelIndicators(channelNum).FaceAlpha = 0.95;
                end

            else                                         % Channel off
                obj.ChannelForeground(channelNum).Visible = 'on';
                if obj.IsMouseOnButton(channelNum)          % Mouse on
                    obj.ChannelIndicators(channelNum).FaceAlpha = 0.7;
                    obj.ChannelForeground(channelNum).Color = ones(1,3)*0.9;
                else                                        % Mouse off
                    obj.ChannelIndicators(channelNum).FaceAlpha = 0.5;
                    obj.ChannelForeground(channelNum).Color = ones(1,3)*0.8;
                end
            end
            %set(obj.ChannelForeground, 'Visible', 'off')
        end

        function updateIndicatorColor(obj, chNum, rgb)
            obj.ChannelIndicators(chNum).FaceColor = rgb;
        end

        function updateSize(obj)

            w = obj.ChannelIndicatorSize;
            dx = obj.ChannelIndicatorSpacing;
            widgetWidth = obj.NumChannels * w + (obj.NumChannels-1) .* dx;

            obj.Position_(3) = widgetWidth;
        end
    end

    methods (Access = private) % User interaction callbacks

        function onChannelIndicatorPressed(obj, channelNum)

            %obj.Figure.CurrentKey

            %oldSelection = obj.CurrentChannels;
            switch obj.Figure.SelectionType
                case 'normal'
                    % pass
                    obj.CurrentChannels = channelNum;

                case 'extend'
                    obj.CurrentChannels = union(obj.CurrentChannels, channelNum);

                case 'alt'
                    obj.LastChannelPressed = channelNum;
                    return

                case 'open'
                    if isequal(obj.CurrentChannels, 1:obj.NumChannels)
                        obj.CurrentChannels = channelNum;
                    else
                        obj.CurrentChannels = 1:obj.NumChannels;
                    end
                    %obj.selectChannel(channelNum)
                    %return
            end

%             if ismember(channelNum, obj.CurrentChannels)
%                 obj.CurrentChannels = setdiff(obj.CurrentChannels, channelNum);
%             else
%                 obj.CurrentChannels = union(obj.CurrentChannels, channelNum);
%             end

            % If only one channel is visible, and it is deselected, toggle
            % all the other channels on
            if isempty(obj.CurrentChannels)
                allChannels = 1:obj.NumChannels;
                obj.CurrentChannels = setdiff(allChannels, channelNum, 'stable');
            end

            if ~isempty(obj.Callback)
%                 evtData = struct(); % todo: eventdata
%                 evtData.OldSelection = oldSelection;
%                 evtData.NewSelection = obj.CurrentChannels;
%                 obj.Callback(obj, evtData)
                obj.Callback(obj.CurrentChannels) % todo: generalize...
            end
        end

    % % % Callbacks for mouseover effects

        function setPointerBehavior(obj, h)
        %setPointerBehavior Set pointer behavior of buttons.

            pointerBehavior.enterFcn    = @(s,e,hObj)obj.onMouseEntered(h);
            pointerBehavior.exitFcn     = @(s,e,hObj)obj.onMouseExited(h);
            pointerBehavior.traverseFcn = [];%@obj.moving;

            uim.utility.setPointerBehavior(h, pointerBehavior)
        end

        function onMouseEntered(obj, h, varargin)
        %onMouseEntered Callback for mouse entering button

            ind = ismember(obj.ChannelIndicators, h);
            obj.IsMouseOnButton(ind) = true;

            if isa(h, 'matlab.graphics.primitive.Patch')
                switch h.Tag
                    case 'ChannelIndicator'
                    	obj.changeIndicatorAppearance(find(ind))
                end
            elseif isa(h, 'matlab.graphics.chart.primitive.Line')
            end

            obj.Figure.Pointer = 'hand';
        end

        function onMouseExited(obj, h, varargin)
        %onMouseEntered Callback for mouse leaving button

            ind = ismember(obj.ChannelIndicators, h);
            obj.IsMouseOnButton(ind) = false;

            if isa(h, 'matlab.graphics.primitive.Patch')
                switch h.Tag
                    case 'ChannelIndicator'
                    	obj.changeIndicatorAppearance(find(ind))
                end

            elseif isa(h, 'matlab.graphics.chart.primitive.Line')
            end

            if ~obj.IsMouseButtonPressed
                obj.Figure.Pointer = 'arrow';
            end
        end
    end

    methods (Access = private) % Property set callbacks

        function onVisibleChanged(obj)

            if ~obj.IsConstructed; return; end

            %obj.Axes.Visible = obj.Visible;

            if obj.Visible
            else
            end
        end

        function onLocationChanged(obj)
            if ~obj.IsConstructed; return; end
        end

        function onSizeChanged(obj)

            if ~obj.IsConstructed; return; end

            if obj.IsAxesInternal
                obj.Axes.Position(3:4) = obj.Position_(3:4);

                axWidth = obj.Axes.Position(3);
                axHeight = obj.Axes.Position(4);

                newYLim = [-1, 1] .* (axHeight/2);
                if ~all( newYLim == obj.Axes.YLim  )
                    obj.Axes.YLim = newYLim;
                end

                newXLim = [1, axWidth];
                if ~all( newXLim == obj.Axes.XLim )
                    obj.Axes.XLim = newXLim;
                end
            else
                % Do nothing...
            end
        end

        function onNumChannelsChanged(obj)

            obj.IsMouseOnButton = false(1, obj.NumChannels);

            % Resize axes...
            % Todo: Call methods to change size / resize
            obj.updateSize()
            obj.onSizeChanged()

            if ~obj.IsConstructed; return; end

            assert(~any(obj.IsMouseOnButton), 'This should not happen')

            obj.drawIndicators()
            obj.drawIndicatorState()
        end

        function onCurrentChannelsChanged(obj)

            for i = 1:obj.NumChannels
                obj.changeIndicatorAppearance(i)

                % Post hoc: Commented out, do not remember why I added
                % this conditional. Keep for future refactoring, in case I
                % recall whether this if/else is necessary
                % if any(ismember(obj.CurrentChannels, i))
                %     obj.changeIndicatorAppearance(i)
                % else
                %     obj.changeIndicatorAppearance(i)
                % end
            end
        end
    end

    methods (Static, Access = private)
        function [labels, colors] = getColorOptions()
            labels = {'Red', 'Green', 'Blue', 'Cyan', 'Magenta', 'Yellow'};
            colors = {[1,0,0], [0,1,0], [0,0,1], [0,1,1], [1,0,1], [1,1,0]};
        end
    end
end
