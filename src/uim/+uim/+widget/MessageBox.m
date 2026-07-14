classdef MessageBox < uim.mixin.Resizable
%uim.widget.MessageBox A class that implements a messagebox for showing
% popupmessages within a figure window.

% TODO:
%   [ ] Remove dependence on uim.mixin.Resizable (imrect fucks up the axes configurations)

    properties (Access = private)

        ReferenceAxes % Axes the message box axes is plotted relative to. Not a real parent (see the inherited Parent property).
        Axes
        Background
        MessageText
        CloseButton
        CloseButtonBackground
        OriginalPosition = [];

        WaitbarHandle
        IsWaitbarActive = false

        CurrentObjectInFocus = struct('handle', gobjects(1), 'props', {{}})
        FigureCursorMotionFcn = [];
        MouseMotionListener = event.listener.empty

        IsMouseOver
        Value = 0
        Style = uim.style.ButtonDarkMode

        MessageTimer
        CornerRadius = 2
    end

    properties
        %Parent %Resizable property for which axes the imrect is plotted into
        Position
        BackgroundColor = ones(1,3) * 0.2
        BackgroundAlpha = 0.7
        BorderColor = ones(1,3) * 0.5
        FontSize = 14
        FontColor = ones(1,3)*0.8
    end % \properties Dependent?

    properties
        Units = 'pixel'
        MinSize = [300, 50] % Should be MaxSize....
    end % \properties

    methods

        function obj = MessageBox(hParent, varargin)

            msg = 'Invalid Sequence of Name, Value Parameters';
            assert(all(cellfun(@(arg) ischar(arg), varargin(1:2:end))), msg)

            for i = 1:2:numel(varargin)
                try
                    obj.(varargin{i}) = varargin{i+1};
                catch
                    fprintf('Invalid Parameter Name (%s)\n', varargin{i})
                end
            end

            % Todo: parse varargin...

            obj.ReferenceAxes = hParent;

            obj.createAxes()
            obj.createTextbox()

        end % \MessageBox (Constructor)

        function delete(obj)
            delete(obj.Axes)
        end % \delete

    end % \structor methods

    methods (Access = protected)
        function setDefaultButtonDownFcn(~, ~)
        end

        function resize(obj, newPosition, ~)

            % make sure messagebox units are the same as the reference axes
            % units before setting the position property. The position
            % values are based on the Units property of the parent.

            axUnits = obj.Axes.Units;
            obj.Axes.Units = obj.ReferenceAxes.Units;

            if strcmp(obj.Parent.XDir, 'reverse')
                newPosition(1) = obj.Parent.Position(3) - newPosition(1);
            end

            if strcmp(obj.Parent.YDir, 'reverse')
                newPosition(2) = obj.Parent.Position(4) - newPosition(2);
            end

            obj.Axes.Position = newPosition;
            obj.Axes.Units = axUnits;

            obj.updateTextboxCoords()
        end
    end

    methods (Access = private)

        function createAxes(obj)

            % Add message axes...
            if isa(obj.ReferenceAxes, 'matlab.graphics.axis.Axes')
                obj.Axes = axes('Parent', obj.ReferenceAxes.Parent);
            else
                obj.Axes = axes('Parent', obj.ReferenceAxes);
            end

            % Set some axes properties
            obj.Axes.Units = obj.Units;
            obj.Axes.HandleVisibility = 'off';
            obj.Axes.Tag = 'Message Box';

            % Get parent position
            origParentUnits = obj.ReferenceAxes.Units;
            obj.ReferenceAxes.Units = obj.Units;
            pos = obj.ReferenceAxes.Position;
            obj.ReferenceAxes.Units = origParentUnits;

            if isa(obj.ReferenceAxes, 'matlab.ui.Figure') || isa(obj.ReferenceAxes, 'matlab.ui.container.Panel')
                pos(1:2)=0;
            end

            % Make sure axes does not exceed parent container.
            axW = min(pos(3), obj.MinSize(1));
            axH = min(pos(4), obj.MinSize(2));

            axesLocation = [pos(1)+ (pos(3) - axW)/2, pos(2) + (pos(4) - axH)/2];
            obj.Axes.Position = [axesLocation, axW, axH ];
            obj.Axes.Visible = 'off';
            hold(obj.Axes, 'on')

            if isa(obj.ReferenceAxes, 'matlab.ui.container.Panel')
                obj.Axes.Position = [0,0,obj.ReferenceAxes.Position(3:4)];
            end

            % Configure isResizable behavior. This will make the messagebox
            % resizeable.
            axUnits = obj.Axes.Units;
            obj.Axes.Units = obj.ReferenceAxes.Units;
            obj.Position = obj.Axes.Position;
            obj.Axes.Units = axUnits;

            obj.Parent = obj.ReferenceAxes;
            if isa(obj.ReferenceAxes, 'matlab.graphics.axis.Axes')
                obj.createInteractiveRectangle()
                obj.hideInteractiveRectangle

                hFunc = makeConstrainToRectFcn('imrect', obj.Parent.XLim, obj.Parent.YLim);
                obj.setPositionConstraintFcn(hFunc)
                obj.IsResizable = false; % Turn of resizeability. (Messagebox can only be moved).
            end

        end % \createAxes

        function [xData, yData] = getTextboxCoordinates(obj)

% %             % Deprecate:
% %             xLim = obj.Axes.XLim;
% %             yLim = obj.Axes.YLim;
% %
% %             xData = xLim([1,1,2,2,1]);
% %             yData = yLim([2,1,1,2,2]);

            axesPos = getpixelposition(obj.Axes);
            boxSize = axesPos(3:4);
            [xData, yData] = uim.shape.rectangle(boxSize, obj.CornerRadius);
            xData = xData / max(xData(:));
            yData = yData / max(yData(:));
        end

        function updateTextboxCoords(obj)
            if isempty(obj.Background); return; end
            [xData, yData] = obj.getTextboxCoordinates();
            set(obj.Background, 'XData', xData, 'YData', yData)
        end

        function createTextbox(obj)

            [xData, yData] = obj.getTextboxCoordinates();

            obj.Background = patch(obj.Axes, xData, yData, 'w');
            obj.Background.FaceColor = obj.BackgroundColor;
            obj.Background.FaceAlpha = obj.BackgroundAlpha;
            obj.Background.EdgeColor = obj.BorderColor;
            obj.Background.Visible = 'off';
            obj.Background.PickableParts = 'none';
            obj.Background.HitTest = 'off';

            hold(obj.Axes, 'on')
            obj.Axes.XLim = [0,1];
            obj.Axes.YLim = [0,1];

            xPos = obj.Axes.XLim(1) + uim.utility.range(obj.Axes.XLim)/2;
            yPos = obj.Axes.YLim(1) + uim.utility.range(obj.Axes.YLim)/2;

            obj.MessageText = text(obj.Axes, xPos, yPos, '');
            obj.MessageText.Visible = 'off';
            obj.MessageText.HorizontalAlignment = 'center';
            obj.MessageText.VerticalAlignment = 'middle';
            obj.MessageText.FontSize = obj.FontSize;
            obj.MessageText.Color = obj.FontColor;
            obj.MessageText.Interpreter = 'none';
            obj.MessageText.PickableParts = 'none';
            obj.MessageText.HitTest = 'off';

            % Add button.
            obj.CloseButton = plot(obj.Axes, 1, 1, 'x');
            obj.CloseButton.MarkerSize = 12;
            obj.CloseButton.Visible = 'off';
            obj.CloseButton.ButtonDownFcn = @(s,e) obj.clearMessage;
            obj.CloseButton.Color = obj.FontColor;
            obj.CloseButton.LineWidth = 1;
            obj.CloseButton.PickableParts = 'visible';
            obj.CloseButton.HitTest = 'on';

            obj.setXbuttonPosition()
            obj.addXbuttonBackground()

            pointerBehavior.enterFcn    = @obj.onMouseEnteredButton;
            pointerBehavior.exitFcn     = @obj.onMouseExitedButton;
            pointerBehavior.traverseFcn = [];%@obj.moving;

            iptSetPointerBehavior(obj.CloseButton, pointerBehavior);
            iptPointerManager(ancestor(obj.CloseButton, 'figure'));
            uistack(obj.CloseButton, 'top')

        end % \createTextbox

        function setXbuttonPosition(obj)
            pixpos = getpixelposition(obj.Axes);
            btnPos = 1 - ([0.05, 0.05] .* [1, pixpos(3)/pixpos(4)]);
            obj.CloseButton.XData = btnPos(1);
            obj.CloseButton.YData = btnPos(2);

            if ~isempty(obj.CloseButtonBackground)
                [xData, yData] = obj.getXButtonBackgroundCoords();
                set(obj.CloseButtonBackground, 'XData', xData, 'YData', yData)
            end
        end

        function addXbuttonBackground(obj)

            [xData, yData] = obj.getXButtonBackgroundCoords();
            hBtn = patch(obj.Axes, xData, yData, 'w');

            % Configure patch which will be visible when hovering over X
            hBtn.FaceColor = [209, 210, 211] ./ 255;
            hBtn.EdgeColor = 'none';
            hBtn.FaceAlpha = 0.01;
            hBtn.LineWidth = 1;
            hBtn.Tag = sprintf('Close Button');
            hBtn.ButtonDownFcn = @(s, e) obj.clearMessage;
            hBtn.HitTest = 'off';
            hBtn.PickableParts = 'none';
            hBtn.Visible = 'off';

            obj.CloseButtonBackground = hBtn;
        end

        function [xData, yData] = getXButtonBackgroundCoords(obj)

            margin = 6;
            offset = 0;

            % Get coordinates for patching a box under the X.
            bgSize = obj.CloseButton.MarkerSize + margin;
            [edgeX, edgeY] = uim.shape.rectangle([bgSize, bgSize]);
            edgeX = edgeX + offset;

            % Convert edge coordinates to data units (Transpose because
            % input to px2du is nPoints x 2 and output from createBox is
            % row-vectors.
            edgeCoords = uim.utility.px2du(obj.Axes, [edgeX', edgeY'] );
            xPos = obj.CloseButton.XData;
            yPos = obj.CloseButton.YData;

            % Shift coordinates to be centered on xPos and yPos.
            edgeCoords = edgeCoords - mean(edgeCoords,1) + [xPos, yPos];

            xData = edgeCoords(:, 1);
            yData = edgeCoords(:, 2);
        end

        function fadeIn(obj)
            obj.Background.FaceAlpha = 0;
            obj.Background.Visible = 'on';

            fade = linspace(0, obj.BackgroundAlpha, 60);

            for i = 1:numel(fade)
                obj.Background.FaceAlpha = fade(i);
                if i == 10
                    obj.MessageText.Visible = 'on';
                    obj.CloseButton.Visible = 'on';
                    obj.CloseButtonBackground.Visible = 'on';
                end
                pause(0.01)
                drawnow limitrate
            end

        end % \fadeIn

        function fadeOut(obj)

            fade = linspace(obj.BackgroundAlpha, 0, 60);

            for i = 1:numel(fade)
                obj.Background.FaceAlpha = fade(i);
                if i == 50
                    obj.MessageText.Visible = 'off';
                    obj.CloseButton.Visible = 'off';
                    obj.CloseButtonBackground.Visible = 'off';
                end
                pause(0.01)
                drawnow limitrate
            end

        end % \fadeOut

        function foldMessage(obj)

            msg = obj.MessageText.String;

            nChars = numel(msg);
            extent = obj.MessageText.Extent;
            obj.MessageText.String = '';

            nLines = ceil(extent(3));
            %Extent is in normalized units, so the extent says how many
            %lines the text should be divided on.

            nCharsPerLine = floor(nChars ./ extent(3) ) - 10; % -10 to leave some margin

            % Start loop where message is split on spaces to create lines
            % that will not exceed the width of the textbox. Loop finished
            % when it has gone over the whole message. Note: Messages are
            % also split on file separator, so that long pathstrings are
            % also split

            % Todo: Improve/simplify code.

            tmpmsg = msg;
            lines = cell(nLines, 1);
            finished = false;
            c = 1;
            while ~finished
                [split, M] = strsplit(tmpmsg, {filesep, ' '});
                M{end+1} = '';
                a = cumsum( arrayfun(@(i) numel(split{i}) + i-1, 1:numel(split) ) );
                b = a-nCharsPerLine;
                b(b>0) = [];
                [~, ind] = max(b);

                lines{c} = strjoin( cat(1, split(1:ind), M(1:ind)), '');
                tmpmsg = strjoin( cat(1, split(ind+1:end), M(ind+1:end)), '');
                c = c + 1;
                if isempty(tmpmsg); finished = true; end
            end

            obj.MessageText.Interpreter = 'none';
            obj.MessageText.String = lines;
            extent = obj.MessageText.Extent;

            if extent(4) > 1
                obj.OriginalPosition = obj.Axes.Position([2,4]);
                obj.Axes.Position(4) = obj.Axes.Position(4) * ceil(extent(4));
                obj.Axes.Position(2) = obj.Axes.Position(2) - ...
                    (obj.Axes.Position(4) - obj.OriginalPosition(2))/2;
                obj.setXbuttonPosition()
                obj.updateTextboxCoords()
            end

        end % \foldMessage

% %         function hijackMouseOver(obj)
% %             hFig = ancestor(obj.ReferenceAxes, 'Figure');
% %
% %             if isempty(obj.MouseMotionListener)
% %                 el = listener(hFig, 'WindowMouseMotion', @obj.mouseOver);
% %                 obj.MouseMotionListener = el;
% %             end
% %
% %         end

% %         function giveBackMouseOver(obj)
% %             if ~isempty(obj.MouseMotionListener)
% %                 delete(obj.MouseMotionListener);
% %                 obj.MouseMotionListener = event.listener.empty;
% %             end
% %         end

% %         function mouseOver(obj, src, event)
% %             %disp('messageBox mouseover')
% %              h = hittest();
% % %
% % %             if ~isequal(h, obj.CurrentObjectInFocus.handle)
% % %                 % Reset previous object
% % %                 if ~isa(obj.CurrentObjectInFocus.handle, 'matlab.graphics.GraphicsPlaceholder')
% % %                     set(obj.CurrentObjectInFocus.handle, obj.CurrentObjectInFocus.props{:})
% % %                     obj.CurrentObjectInFocus = struct('handle', gobjects(1), 'props', {{}});
% % %                 end
% % %
% % %                 if isa(h, 'matlab.graphics.primitive.Patch') && contains(h.Tag, 'Button')
% % %                     h.FaceAlpha = 0.15;
% % %                     obj.CurrentObjectInFocus = struct('handle', h, 'props', {{'FaceAlpha', 0}});
% % %                 end
% % %             end
% %
% %
% %             if isequal(h, obj.CloseButtonBackground)
% %             	% Already taken care of
% %             elseif isequal(h, obj.Background) || isequal(h, obj.MessageText)
% %                 % Do nothing
% %             else % Call figures default callback...
% %                 if ~isempty(obj.FigureCursorMotionFcn)
% %                     obj.FigureCursorMotionFcn(src, event)
% %                 end
% %             end
% %
% %         end

        function clearMessageIn(obj, n, doFade)

            if ~isempty(obj.MessageTimer)
                stop(obj.MessageTimer)
                delete(obj.MessageTimer)
                obj.MessageTimer = [];
            end
            n = round(n, 2);
            t = timer('ExecutionMode', 'singleShot', 'StartDelay', n);
            t.TimerFcn = @(myTimerObj, thisEvent) obj.clearMessageByTimer(t, doFade);
            obj.MessageTimer = t;
            start(obj.MessageTimer)
        end

        function clearMessageByTimer(obj, t, doFade)

            % Return if gui has been deleted
            if ~isvalid(obj); return; end

            if nargin >=2 && ~isempty(t) && isvalid(t)
                stop(obj.MessageTimer)
                delete(obj.MessageTimer)
                obj.MessageTimer = [];
            end

            obj.clearMessage(doFade)
        end

            function onMouseEnteredButton(obj, ~, ~)
                obj.IsMouseOver = true;
                obj.CloseButtonBackground.FaceAlpha = 0.15;
                obj.CloseButtonBackground.EdgeColor = ones(1,3) * 0.4;

    %             if ~isempty(obj.Tooltip)
    %                 obj.Toolbar.showTooltip(obj.Tooltip, obj.TooltipPosition)
    %             end
            end

            function onMouseExitedButton(obj, ~, ~)
                obj.IsMouseOver = false;
                obj.CloseButtonBackground.FaceAlpha = 0;
                obj.CloseButtonBackground.EdgeColor = 'none';

    %             obj.Toolbar.hideTooltip()
            end

    end % \methods (Private)

    methods (Access = public)

        function centerInWindow(obj, pos)
            uim.utility.layout.centerObjectInRectangle(obj.Axes, pos)
        end

        function activateGlobalMessageDisplay(obj, mode)

            if nargin < 2
                mode = 'update';
            end

            global fprintf

            switch mode
                case 'display'
                    fprintf = @(msg)obj.displayMessage(msg);
                case 'update'
                    fprintf = @(varargin)obj.displayMessage(varargin{:});
            end
        end

        function activateGlobalWaitbar(obj)
            global waitbar
            waitbar = @obj.waitbar;
        end

        function deactivateGlobalWaitbar(obj)
         	global waitbar
            waitbar = [];

            obj.waitbar(1, '', 'close')
        end

        function displayMessage(obj, msg, duration, doFade)

            if isempty(obj); return; end

            if nargin < 4; doFade = false; end

            %             if nargin < 3 || isempty(duration)
            %                 duration = 2;
            %             end

            % Do this first, to avoid double calling if two messages are
            % displayed quickly.
            %obj.hijackMouseOver()

            msg = sprintf('%s', msg);
            msg = strrep(msg, newline, '');

            if ~isempty(obj.MessageText.String)
                if isequal(msg, obj.MessageText.String{1}); return; end
            end

            % todo, do more work on this... i.e
            % this function should accept everything that can go into
            % fprintf

            obj.MessageText.String = msg;
            obj.foldMessage()

            if doFade && ~strcmp(obj.Background.Visible, 'on')
                obj.fadeIn()
            else
                obj.MessageText.Visible = 'on';
                obj.Background.Visible = 'on';
                obj.CloseButton.Visible = 'on';
                obj.CloseButtonBackground.Visible = 'on';

                drawnow
            end
            obj.showInteractiveRectangle()

            if isa(obj.ReferenceAxes, 'matlab.ui.container.Panel')
                obj.ReferenceAxes.Visible = 'on';
            end

            % Make sure close-button background is will capture
            % mouseclicks/mouseovers.
% %             obj.CloseButtonBackground.HitTest = 'on';
% %             obj.CloseButtonBackground.PickableParts = 'all';

            if nargin >= 3 && ~isempty(duration)
                obj.clearMessageIn(duration, doFade)

%                 pause(duration)
%                 obj.clearMessage(doFade)
            end

        end % \displayMessage

        function clearMessage(obj, doFade)

            if isempty(obj); return; end

            if nargin < 2; doFade = false; end

            if doFade
                obj.fadeOut();
                obj.Background.FaceAlpha = obj.BackgroundAlpha;
            else
                obj.MessageText.Visible = 'off';
                obj.CloseButton.Visible = 'off';
                obj.CloseButtonBackground.Visible = 'off';
            end
            obj.hideInteractiveRectangle()

            obj.MessageText.String = '';
            obj.Background.Visible = 'off';

            % Make sure close-button background is will not capture
            % mouseclicks/mouseovers.
% %             obj.CloseButtonBackground.HitTest = 'off';
% %             obj.CloseButtonBackground.PickableParts = 'visible';

            if ~isa(obj.CurrentObjectInFocus.handle, 'matlab.graphics.GraphicsPlaceholder')
                set(obj.CurrentObjectInFocus.handle, obj.CurrentObjectInFocus.props{:})
                obj.CurrentObjectInFocus = struct('handle', gobjects(1), 'props', {{}});
            end

            if ~isempty(obj.OriginalPosition)
                obj.Axes.Position([2,4]) = obj.OriginalPosition;
                obj.updateTextboxCoords()

                obj.OriginalPosition = [];
                obj.setXbuttonPosition()
            end

            if obj.IsWaitbarActive && ~isempty(obj.WaitbarHandle)
                obj.waitbar(1, '', 'close')
            end

            if isa(obj.ReferenceAxes, 'matlab.ui.container.Panel')
                obj.ReferenceAxes.Visible = 'off';
            end

            %drawnow
            %%obj.giveBackMouseOver()

        end % \clearMessage

        function tf = isMessageDisplaying(obj)
            tf = strcmp(obj.MessageText.Visible, 'on') && ~isempty(obj.MessageText.String);
        end

        function resetAxesPosition(obj)

             % Get parent position
            origParentUnits = obj.ReferenceAxes.Units;
            obj.ReferenceAxes.Units = obj.Units;
            pos = obj.ReferenceAxes.Position;
            obj.ReferenceAxes.Units = origParentUnits;

            if isa(obj.ReferenceAxes, 'matlab.ui.Figure')
                pos(1:2)=0;
            end

            % Make sure axes does not exceed parent container.
            axW = min(pos(3), obj.MinSize(1));
            axH = min(pos(4), obj.MinSize(2));

            axesLocation = [pos(1)+ (pos(3) - axW)/2, pos(2) + (pos(4) - axH)/2];
            obj.Axes.Position = [axesLocation, axW, axH ];
            obj.updateTextboxCoords()
        end

    end % \methods

    methods (Access = public) % Waitbar

        function waitbar(obj, p, message, action)

            if nargin < 3; message = ''; end
            if nargin < 4; action = 'set'; end

            if isempty(obj.WaitbarHandle) || ~isvalid(obj.WaitbarHandle) % Create waitbar
                pixPos = getpixelposition(obj.Axes);
                obj.WaitbarHandle = uim.widget.Waitbar(obj.Axes, ...
                    'Position', [0,1,pixPos(3),10], 'Visible', 'off');
            end

            switch action
                case 'close'
                    obj.IsWaitbarActive = false;
                    obj.WaitbarHandle.Status = 0; % Reset status
                    obj.WaitbarHandle.Visible = 'off';

                otherwise

                    if ~obj.IsWaitbarActive % Activate waitbar
                        obj.IsWaitbarActive = true;
                        obj.WaitbarHandle.Visible = 'on';
                        drawnow
                    end

                    p = min([p,1]);
                    obj.WaitbarHandle.Status = p;

                    if ~isempty(message)
                        obj.displayMessage(message)
                    end
            end
        end
    end

end % \classdef
