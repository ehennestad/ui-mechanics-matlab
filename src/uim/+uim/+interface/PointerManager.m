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

        OriginalAxesButtonDownFcn = [] % Store axes function
    end

    properties (Access = private)
        PreviousPointerTool
        WasCursorInAxes (1,1) logical = false;

        OriginalWindowButtonMotionFcn = []
        DummyWindowButtonMotionFcn = []
        OwnsWindowButtonMotionFcn (1,1) logical = false

        AxesButtonPressListener event.listener
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
            obj.OriginalWindowButtonMotionFcn = hFigure.WindowButtonMotionFcn;

            % Assign dummy callback if WindowButtonMotionFcn is unassigned
            if isempty( hFigure.WindowButtonMotionFcn )
                obj.DummyWindowButtonMotionFcn = @obj.mouseMotionDummyCallback;
                hFigure.WindowButtonMotionFcn = obj.DummyWindowButtonMotionFcn;
                obj.OwnsWindowButtonMotionFcn = true;
            end

            % Create listeners for mouse event in figure
            obj.createFigureMouseListeners()

            % Store current axes button down function
            if ~isempty(hAxes.ButtonDownFcn)
                obj.OriginalAxesButtonDownFcn = hAxes.ButtonDownFcn;
            end

            % Assign PointerManager callbacks to figure
            hAxes.ButtonDownFcn = @obj.onButtonDown; % Use button down callback of axes..
            hAxes.Interruptible = 'off'; % Todo: are there cases where its better if this is on?

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

            if isvalid(obj.Axes)
                if isequal( obj.Axes.ButtonDownFcn, @obj.onButtonDown)
                    obj.Axes.ButtonDownFcn = [];
                end

                if ~isempty(obj.OriginalAxesButtonDownFcn)
                    obj.Axes.ButtonDownFcn = obj.OriginalAxesButtonDownFcn;
                end
            end

            if obj.OwnsWindowButtonMotionFcn && isvalid(obj.Figure) && ...
                    isequal(obj.Figure.WindowButtonMotionFcn, obj.DummyWindowButtonMotionFcn)
                obj.Figure.WindowButtonMotionFcn = obj.OriginalWindowButtonMotionFcn;
            end
        end
    end

    methods (Access = private)

        function createFigureMouseListeners(obj)

            %obj.WindowMousePressListener = addlistener(obj.Figure, ...
            %    'WindowMousePress', @obj.onMousePressed);

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
            end
        end

        function wasCaptured = onKeyPress(obj, src, event)

            % Todo: Make a system for having unique key shortcuts and
            % setting/changing them from one location..

            % if ~obj.isCursorInsideAxes(obj.Axes); return; end
            % disp(event.Key)

            wasCaptured = true;
            if isempty(event.Modifier)
                switch event.Key
                    case 'x'
                        obj.togglePointerMode('crop')
                    case 'q'
                        obj.togglePointerMode('zoomIn')
                    case 'w'
                        obj.togglePointerMode('zoomOut')
                    case 'y'
                        obj.togglePointerMode('pan')
                    case 'i'
                        obj.togglePointerMode('dataCursor')
                    case 's'
                        obj.togglePointerMode('selectObject')
                    case 'd'
                        obj.togglePointerMode('polyDraw')
                    case 'o'
                        obj.togglePointerMode('circleSelect')
                    case 'a'
                        obj.togglePointerMode('autoDetect')
                    case 't'
                        obj.togglePointerMode('freehandDraw')

                    otherwise
                        wasCaptured = false;
                end
            else
                wasCaptured = false;
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
                obj.CurrentPointerTool.activate();
            else
                obj.Figure.Pointer = 'arrow';
            end
        end
    end

    methods (Access = private)

        function onButtonDown(obj, src, event)

            % Todo: rename onButtonDownInAxes

            % 1) Call default axes button down callback
%             if ~isempty(obj.OriginalAxesButtonDownFcn)
%                 obj.OriginalAxesButtonDownFcn(src, event)
%             end

            % 2) Call active pointer tool
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

            xLim = hAx.XLim;
            yLim = hAx.YLim;

            axLim = [xLim(1), yLim(1), xLim(2), yLim(2)];

            % Check if mousepoint is within axes limits.
            tf = ~any(any(diff([axLim(1:2); currentPoint; axLim(3:4)]) < 0));
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

        function mouseMotionDummyCallback(~, ~, ~)
            % Assign this if the WindowButtonMotionFcn of a figure is empty

            % The figure's CurrentPoint property is only updated if a
            % mousemotion callback is assigned.
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
