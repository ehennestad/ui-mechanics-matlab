classdef PointerManager < handle
%PointerManager A manager for switching between different interactive
% pointer tools in axes.
%
%   See also uim.interface.PointerTool

% List of things to implement
%   Keypress sequences should be read from settings somehow
%   Also: Migrate other things from a settings file/preferences...
%   Need to capture the figure's scroll callback.
%   [x] use listeners instead of attaching mouse function to figure handle

    properties
        DefaultPointerTool
    end

    properties (SetAccess = private)
        Figure matlab.ui.Figure
        Axes matlab.graphics.axis.Axes

        Pointers struct = struct()
        SupportedTools

        CurrentPointerTool

    end

    properties (Access = private)
        PreviousPointerTool
        WasCursorInAxes (1,1) logical = false;

        HostAxesButtonDownFcn = []
        IsHostButtonDownFcnHeld (1,1) logical = false

        AxesButtonPressListener event.listener
        PointerToolToggleListeners event.listener
        WindowMousePressListener event.listener
        WindowButtonMotionListener event.listener
        WindowButtonUpListener event.listener
        WindowScrollWheelListener event.listener % todo
        %WindowKeyPressListener event.listener
        MouseDownPointerTool = []
    end

    properties (Access = protected)
        IsMouseButtonDown (1,1) logical = false
        PreviousMousePoint (1,2) double = [nan, nan]
        PreviousMouseClickPoint   % Point where mouse was last clicked
    end

    methods % Structors

        function obj = PointerManager(hFigure, hAxes, pointerNames)
        %PointerManager Attach a PointerManager to a figure

            obj.Figure = hFigure;
            obj.Axes = hAxes;

            % In java figures CurrentPoint only follows the mouse while
            % a WindowButtonMotionFcn is installed. The shared helper
            % keeps its no-op for the figure's lifetime: widgets rely on
            % the same mechanism, so it must survive this manager's
            % deletion.
            uim.utility.ensurePointerMotionTracking(hFigure)

            % Create listeners for mouse event in figure. Button presses
            % are captured at the window level (not via the axes
            % ButtonDownFcn): data objects such as images have HitTest on
            % by default and would swallow every click before it reached
            % the axes callback.
            obj.createFigureMouseListeners()

            hold(obj.Axes, 'on')

            if nargin >= 3 &&  ~isempty(pointerNames)
                obj.initializePointers(hAxes, pointerNames)
            end

            if ~nargout
                clear obj
            end
        end

        function delete(obj)
        %delete Delete method for PointerManager.

            obj.deleteFigureMouseListeners()
            delete(obj.PointerToolToggleListeners)

            obj.releaseHostButtonDownFcn()
        end
    end

    methods (Access = private)

        function createFigureMouseListeners(obj)

            obj.WindowMousePressListener = addlistener(obj.Figure, ...
                'WindowMousePress', @obj.onWindowMousePress);

            obj.WindowButtonMotionListener = addlistener(obj.Figure, ...
                 'WindowMouseMotion', @obj.onButtonMotion);

            obj.WindowButtonUpListener = addlistener(obj.Figure, ...
                'WindowMouseRelease', @obj.onButtonRelease);

            %obj.WindowScrollWheelListener = addlistener(obj.Figure, ...
            %    'WindowScrollWheel', @obj.onMouseScrolled);

            % Should this be independent, or called from external gui?
            %obj.WindowKeyPressListener = addlistener(obj.Figure, ...
            %    'WindowKeyPress', @obj.onKeyPress);
        end

        function deleteFigureMouseListeners(obj)

            isdeletable = @(x) ~isempty(x) && isvalid(x);

            if isdeletable(obj.WindowMousePressListener)
                delete(obj.WindowMousePressListener)
            end

            if isdeletable(obj.WindowButtonMotionListener)
                delete(obj.WindowButtonMotionListener)
            end

            if isdeletable(obj.WindowButtonUpListener)
                delete(obj.WindowButtonUpListener)
            end

%             if isdeletable(obj.WindowKeyPressListener)
%                 delete(obj.WindowKeyPressListener)
%             end
        end
    end

    methods (Hidden)

        function onFigureChanged(obj)
        end

        function updatePointerSymbol(obj)
            if ~isempty(obj.CurrentPointerTool)
                obj.CurrentPointerTool.setPointerSymbol()
            end
        end
    end

    methods

        function initializePointers(obj, hAxes, pointerRef)

            if ~isa(pointerRef, 'cell'); pointerRef = {pointerRef}; end

            for i = 1:numel(pointerRef)

                if ischar(pointerRef{i}) || ...
                        (isstring(pointerRef{i}) && isscalar(pointerRef{i}))
                    thisPointerName = char(pointerRef{i});
                    thisPointerRef = obj.resolvePointerToolConstructor(thisPointerName);
                else
                    thisPointerRef = pointerRef{i};
                    thisPointerName = strsplit(func2str(thisPointerRef), '.');
                    thisPointerName = thisPointerName{end};
                    % Normalize class name (PascalCase) to tool key (camelCase)
                    thisPointerName = [lower(thisPointerName(1)), thisPointerName(2:end)];
                end
                obj.Pointers.(thisPointerName) = thisPointerRef(hAxes);

                obj.PointerToolToggleListeners(end+1) = addlistener( ...
                    obj.Pointers.(thisPointerName), 'ToggledPointerTool', ...
                    @obj.onPointerToolToggled);
            end
        end

        function wasCaptured = onKeyPress(obj, src, event)

            % Todo: Make a system for having unique key shortcuts and
            % setting/changing them from one location..

            % if ~obj.isCursorInsideAxes(obj.Axes); return; end
            % disp(event.Key)

            wasCaptured = false;
            if isempty(event.Modifier)
                toolName = uim.interface.internal.keyToPointerToolName(event.Key);
                if ~isempty(toolName)
                    obj.togglePointerMode(toolName)
                    wasCaptured = true;
                end
            end

            % 2) Call pointertool's keypress
            if ~isempty(obj.CurrentPointerTool)
                wasCaptured = obj.CurrentPointerTool.onKeyPress(src, event) || wasCaptured;
            end

            if ~nargout
                clear wasCaptured
            end
        end

        function wasCaptured = onKeyRelease(obj, src, event)
            wasCaptured = false;
            if ~isempty(obj.CurrentPointerTool)
                wasCaptured = obj.CurrentPointerTool.onKeyRelease(src, event);
            end
        end

        function togglePointerMode(obj, pointerName)
            % button press from toolbar or keypress callback.

            % If the pointerName refers to the current pointer tool, it
            % should be turned off.
            if ~isfield(obj.Pointers, pointerName); return; end

            toggleOff = isequal(obj.CurrentPointerTool, obj.Pointers.(pointerName));

            switch obj.Pointers.(pointerName).ExitMode

                case 'default'

                    if ~isempty(obj.CurrentPointerTool)
                        obj.CurrentPointerTool.deactivate();
                        obj.PreviousPointerTool = []; %Make sure this is reset.
                    end

                    if toggleOff  % Turn off tool which has exitmode default

                        % Change to default tool
                        obj.CurrentPointerTool = obj.DefaultPointerTool;

                    else  % Turn on tool which has exitmode default

                        % If previous tool is populated, turn off and flush
                        if ~isempty(obj.PreviousPointerTool)
                            obj.PreviousPointerTool.deactivate();
                            obj.PreviousPointerTool = [];
                        end
                        obj.CurrentPointerTool = obj.Pointers.(pointerName);
                    end

                case 'previous'

                    if toggleOff  % Turn off tool which has exitmode previous

                        % Set current to previous if available
                        obj.CurrentPointerTool.deactivate();
                        if ~isempty(obj.PreviousPointerTool)
                            obj.CurrentPointerTool = obj.PreviousPointerTool;
                        else
                            obj.CurrentPointerTool = [];
                        end

                    else  % Turn on tool which has exitmode previous
                        if ~isempty(obj.CurrentPointerTool)
                            if strcmp(obj.CurrentPointerTool.ExitMode, 'default')
                                obj.CurrentPointerTool.suspend()
                                obj.PreviousPointerTool = obj.CurrentPointerTool;
                            else
                                % If exitMode is previous, we dont want to
                                % store it in the "previous" property.
                                obj.CurrentPointerTool.deactivate()
                            end
                        end

                        obj.CurrentPointerTool = obj.Pointers.(pointerName);
                    end
            end

            if ~isempty(obj.CurrentPointerTool)
                % Hold before activating: activate() can block until the
                % tool is done (Crop waits in uiwait for the selection).
                obj.holdHostButtonDownFcn()
                obj.CurrentPointerTool.activate();
            else
                obj.releaseHostButtonDownFcn()
                obj.Figure.Pointer = 'arrow';
            end
        end
    end

    methods (Access = private)

        function onPointerToolToggled(obj, src, event)
        %onPointerToolToggled Follow the current tool turning on or off
        %
        %   A tool can turn itself off without going through
        %   togglePointerMode (Crop does when its selection ends), so the
        %   hold follows the toggle events of the current tool. Events
        %   from any other tool are ignored.

            if ~isequal(src, obj.CurrentPointerTool); return; end

            if event.Value
                obj.holdHostButtonDownFcn()
            else
                obj.releaseHostButtonDownFcn()
            end
        end

        function holdHostButtonDownFcn(obj)
        %holdHostButtonDownFcn Set the axes ButtonDownFcn aside while a tool is on
        %
        %   An active pointer tool receives presses on the axes background
        %   through the figure's WindowMousePress listener, and MATLAB also
        %   runs the axes ButtonDownFcn for the same click. While a tool is
        %   on the host's callback is set aside, so each click has one
        %   handler; with no tool on the host's callback handles it.

            if obj.IsHostButtonDownFcnHeld; return; end

            obj.HostAxesButtonDownFcn = obj.Axes.ButtonDownFcn;
            obj.Axes.ButtonDownFcn = [];
            obj.IsHostButtonDownFcnHeld = true;
        end

        function releaseHostButtonDownFcn(obj)
        %releaseHostButtonDownFcn Give the held ButtonDownFcn back to the axes
        %
        %   A callback the host assigned while a tool was active takes
        %   precedence over the one that was set aside, so it is kept.

            if ~obj.IsHostButtonDownFcnHeld; return; end

            if ~isempty(obj.Axes) && isvalid(obj.Axes) ...
                    && isempty(obj.Axes.ButtonDownFcn)
                obj.Axes.ButtonDownFcn = obj.HostAxesButtonDownFcn;
            end
            obj.HostAxesButtonDownFcn = [];
            obj.IsHostButtonDownFcnHeld = false;
        end

        function onWindowMousePress(obj, src, event)
        %onWindowMousePress Route presses that belong to the managed axes
        %
        %   Only act on presses that would have reached the axes: ignore
        %   presses captured by interactive objects (widget buttons,
        %   draggable markers — anything with its own ButtonDownFcn) and
        %   presses on objects outside the managed axes.

            hitObject = event.HitObject;

            isInManagedAxes = isequal(hitObject, obj.Axes) || ...
                isequal(ancestor(hitObject, 'axes'), obj.Axes);
            if ~isInManagedAxes; return; end

            if ~isequal(hitObject, obj.Axes)
                % Objects with their own ButtonDownFcn handle the press
                % themselves. A hit object without the property is
                % treated as interactive too.
                if ~isprop(hitObject, 'ButtonDownFcn') || ...
                        ~isempty(hitObject.ButtonDownFcn)
                    return
                end
            end

            % The window-level event data carries no Button; translate
            % the figure SelectionType (and modifiers) for tools that
            % check evt.Button.
            buttonNumber = uim.interface.internal.selectionTypeToButton(...
                obj.Figure.SelectionType, obj.Figure.CurrentModifier);

            eventData = struct('Button', buttonNumber, ...
                'HitObject', hitObject, 'Point', event.Point, ...
                'IntersectionPoint', event.IntersectionPoint);

            obj.onButtonDown(src, eventData)
        end

        function onButtonDown(obj, src, event)

            % Todo: rename onButtonDownInAxes

            % Call active pointer tool
            if obj.isCursorInsideAxes(obj.Axes)
                if ~isempty(obj.CurrentPointerTool)
                    obj.MouseDownPointerTool = obj.CurrentPointerTool;
                    try
                        obj.MouseDownPointerTool.onButtonDown(src, event)
                    catch ME
                        obj.MouseDownPointerTool = [];
                        rethrow(ME)
                    end
                end
            end
        end

        function onButtonMotion(obj, src, event)

            pointerTool = obj.getMouseEventPointerTool();
            if isempty(pointerTool); return; end
            tf = obj.isCursorInsideAxes(obj.Axes);

            % Change cursor symbol when pointer enters or leaves axes
            if tf && ~obj.WasCursorInAxes % Entered axes
                pointerTool.setPointerSymbol()
                pointerTool.onPointerEnteredAxes()
            elseif ~tf && obj.WasCursorInAxes % Left axes
                set(obj.Figure, 'Pointer', 'arrow');
                pointerTool.onPointerExitedAxes()
            end

            % Create extended eventdata containing mousepoint coordinates?

            % Keep sending motion events to the mouse-down owner. This lets
            % tools such as zoom/pan continue after a valid press even if
            % the cursor leaves the axes.
            pointerTool.onButtonMotion(src, event)

            if tf
                obj.WasCursorInAxes = true;
            else
                obj.WasCursorInAxes = false;
            end

            %drawnow limitrate
        end

        function onButtonRelease(obj, src, event)

            % Redirect to callback of active pointer tool
            pointerTool = obj.getMouseEventPointerTool();
            if ~isempty(pointerTool)
                cleanupObj = onCleanup(@() obj.resetMouseDownPointerTool());
                pointerTool.onButtonUp(src, event)
            end
        end

        function tf = isCursorInsideAxes(~, hAx)

            currentPoint = hAx.CurrentPoint(1, 1:2);
            tf = uim.geometry.isPointInsideLimits(...
                currentPoint, hAx.XLim, hAx.YLim);
        end

        function pointerTool = getMouseEventPointerTool(obj)
            if ~isempty(obj.MouseDownPointerTool)
                pointerTool = obj.MouseDownPointerTool;
            else
                pointerTool = obj.CurrentPointerTool;
            end
        end

        function resetMouseDownPointerTool(obj)
            obj.MouseDownPointerTool = [];
        end
    end

    methods (Static, Access = private)

        function constructorFcn = resolvePointerToolConstructor(pointerName)
        %resolvePointerToolConstructor Map a tool key to its class constructor

            switch pointerName
                case 'axisZoom'
                    constructorFcn = @uim.interface.pointertools.AxisZoom;
                case 'crop'
                    constructorFcn = @uim.interface.pointertools.Crop;
                case 'dataCursor'
                    constructorFcn = @uim.interface.pointertools.DataCursor;
                case 'pan'
                    constructorFcn = @uim.interface.pointertools.Pan;
                case 'zoomIn'
                    constructorFcn = @uim.interface.pointertools.ZoomIn;
                case 'zoomOut'
                    constructorFcn = @uim.interface.pointertools.ZoomOut;
                otherwise
                    error('uim:PointerManager:UnknownPointerTool', ...
                        'Unknown pointer tool "%s".', pointerName)
            end
        end
    end
end
