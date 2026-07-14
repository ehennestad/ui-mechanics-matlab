classdef UIComponentCanvas < handle
%UIComponentCanvas A class based canvas for drawing modern ui components
%
%   canvas = uim.UIComponentCanvas(hParent) creates a canvas covering the
%   content area of hParent (a figure, uifigure or panel).
%
%   canvas = uim.UIComponentCanvas(hParent, Tag=tagValue) additionally
%   assigns a custom tag to the canvas and its axes.
%
%   canvas = uim.UIComponentCanvas.getOrCreate(hParent) returns the
%   canvas already attached to hParent, or creates one if none exists.
%   A parent container holds at most one canvas.
%
%   Description
%       Built around an axes which overlays all other components in a
%       figure. All interactivity of the axes is turned off, but components
%       can be plotted in the axes. This provides a high level of style
%       customization, because the appearance of a component is only
%       limited by what its possible to plot.
%
%       The canvas always fills its parent's content area and tracks
%       parent resize; it has no position of its own.
%

% Note: In general, it is better to parent the canvas in a panel than
% directly in a figure. When resizing the figure window, if the canvas axes
% is parented to a figure, things appear more glitchy (the axes is
% temporarily squeezed when figure size is decreased) than if the axes is
% parented to a panel.

% Note:
% The 'DefaultAxesCreateFcn' property of figure is used to notify whenever
% a new axes is created on the figure. This is done to make sure the
% UIComponentCanvas axes is always on top.
%
% Limitation: The canvas can not overlay panels. Panels always stack on
% top of axes, so in a figure/uifigure with multiple panels the canvas
% must be parented inside the panel it should cover, not the figure.

% Todo:
%   [ ] Create a variation of UIComponentCanvas for single components.
%   [ ] Throttle SizeChanged notifications during interactive resize
%       (e.g. skip notify if the previous one fired less than ~30 ms ago)
%       so that component reposition/redraw does not run for every
%       intermediate size.

    properties (SetAccess = private, Transient)
        Parent = []                 % Parent handle (figure/uifigure)
        Axes = []                   % Handle to the axes which components are plotted in
        Children = []               % List of uicomponents
        Tag = 'UI Component Canvas' % A tag which is also applied to the axes.
    end

    properties (Dependent, Transient)
        Size
    end

    properties (Access = private, Transient, Hidden)
        PixelPosition = [nan, nan, nan, nan]
        PixelSize = [nan, nan]
        ParentSizeChangedListener event.listener = event.listener.empty
        ParentLocationChangedListener event.listener = event.listener.empty
        Tooltip uim.interface.ToolTip
        ParentDestroyedListener
        PreviousDefaultAxesCreateFcn = []
        SiblingCreatedFcn = []
    end

    events
        SizeChanged
    end

    methods % Structors
        function obj = UIComponentCanvas(hParent, options)

            arguments
                hParent (1,1) matlab.graphics.Graphics = figure()
                options.Tag (1,:) char = 'UI Component Canvas'
            end

            obj.Tag = options.Tag;
            obj.Parent = hParent;

            obj.onSizeChanged() % Call update because we set the parent

            obj.createAxes()
            obj.Tooltip = uim.interface.ToolTip(obj);

            obj.configureParentPositionChangedListener()
            obj.configureSiblingCreatedListener()

            obj.configureParentDestroyedListener()

            if ~nargout
                clear obj
            end
        end

        function delete(obj)
            if ~isempty(obj.Parent) && isvalid(obj.Parent)
                obj.removeParent()
            else
                if ~isempty(obj.ParentDestroyedListener) && isvalid(obj.ParentDestroyedListener)
                    delete(obj.ParentDestroyedListener)
                end
                if ~isempty(obj.ParentSizeChangedListener) && isvalid(obj.ParentSizeChangedListener)
                    delete(obj.ParentSizeChangedListener)
                end
                if ~isempty(obj.ParentLocationChangedListener) && isvalid(obj.ParentLocationChangedListener)
                    delete(obj.ParentLocationChangedListener)
                end
            end
            if ~isempty(obj.Tooltip) && isvalid(obj.Tooltip)
                delete(obj.Tooltip)
            end
            if ~isempty(obj.Axes) && isvalid(obj.Axes)
                delete(obj.Axes)
            end
        end
    end

    methods

        function reparent(obj, newParent)
            obj.Parent = newParent;
        end

        function showTooltip(obj, text, position)
            if ~isempty(obj.Tooltip) && isvalid(obj.Tooltip)
                obj.Tooltip.showTooltip(text, position)
            end
        end

        function hideTooltip(obj)
            if ~isempty(obj.Tooltip) && isvalid(obj.Tooltip)
                obj.Tooltip.hideTooltip()
            end
        end
    end

    methods (Access = private) % Creation

        function createAxes(obj)
        %createAxes Create the axes of the UIComponentCanvas

        % Important. HitTest and Pickable parts need to be on and visible
        % for children of the axes to be able to capture mouseclicks.!

            args = uim.utility.getAxesToolbarArgs();

            obj.Axes = axes(obj.Parent, args{:});

            obj.Axes.Units = 'pixels';
            obj.Axes.Visible = 'off';
            obj.Axes.HandleVisibility = 'off';
            obj.Axes.HitTest = 'on';
            obj.Axes.PickableParts = 'visible';
            obj.Axes.Tag = sprintf('%s Axes', obj.Tag);

            hold(obj.Axes, 'on')

            obj.setAxesLimits()

            if ~isempty(args)
                disableDefaultInteractivity(obj.Axes)
            end
        end

        function configureParentPositionChangedListener(obj)

            % Delete listeners if they already exist.
            if ~isempty(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
            end

            if ~isempty(obj.ParentLocationChangedListener)
                delete(obj.ParentLocationChangedListener)
            end

            % Create listeners for Parent's SizeChanged & LocationChanged
            el = listener(obj.Parent, 'SizeChanged', @obj.onSizeChanged);
            obj.ParentSizeChangedListener = el;

            el = listener(obj.Parent, 'LocationChanged', @obj.onLocationChanged);
            obj.ParentLocationChangedListener = el;

        end

        function configureParentDestroyedListener(obj)

            if ~isempty(obj.ParentDestroyedListener) && ...
                    isvalid(obj.ParentDestroyedListener)
                delete(obj.ParentDestroyedListener)
            end

            obj.ParentDestroyedListener = addlistener(obj.Parent, ...
                'ObjectBeingDestroyed', @(~,~) delete(obj));
        end

        function configureSiblingCreatedListener(obj)
        %configureSiblingCreatedListener Need to know when a sibling is born

            % Use the undocumented DefaultAxesCreationFcn property of
            % figure to run a callback whenever new axes are added to the
            % figure. This is done because our axes always need to stay on
            % top of the uistack.

            % Note, this is more like a dummy listener...

            obj.PreviousDefaultAxesCreateFcn = get(obj.Parent, 'DefaultAxesCreateFcn');
            obj.SiblingCreatedFcn = @obj.onSiblingCreated;
            set(obj.Parent, 'DefaultAxesCreateFcn', obj.SiblingCreatedFcn)
        end

    end

    methods (Access = protected) % Event callbacks

        function onSizeChanged(obj, ~, ~)
        %onSizeChanged Call an update to the PixelSize property
            newParentPosition = uim.utility.getContentPixelPosition(obj.Parent);

            oldSize = obj.PixelSize;
            newSize = newParentPosition(3:4);

            obj.PixelPosition = newParentPosition;
            obj.PixelSize = newSize;

            % On creation oldSize is [nan, nan]; listeners can use this to
            % tell the initial sizing apart from an actual resize.
            evt = uim.event.SizeChangedData(oldSize, newSize);
            obj.notify('SizeChanged', evt)
        end

        function onLocationChanged(obj, ~, ~)
            obj.PixelPosition = uim.utility.getContentPixelPosition(obj.Parent);
        end

        function onSiblingCreated(obj, src, evt)
        %onSiblingCreated Keep our axes on top of the uistack
            obj.invokePreviousDefaultAxesCreateFcn(src, evt)

            try
                uistack(obj.Axes, 'top')
            catch ME
                switch ME.identifier
                    case 'MATLAB:ui:uifigure:UnsupportedAppDesignerFunctionality'
                        obj.Axes.HandleVisibility = 'on';
                        IND = 1:numel(obj.Parent.Children);
                        IND(end-1:end) = IND([end,end-1]);
                        obj.Parent.Children = obj.Parent.Children(IND);
                        obj.Axes.HandleVisibility = 'off';
                end
            end
        end
    end

    methods (Access = private) % Internal updates

        function setAxesLimits(obj)
        %setAxesLimits Set limits of the UIComponentCanvas axes.

            % Abort if axes is not created yet.
            if isempty(obj.Axes); return; end

            if strcmp(obj.Axes.Units, 'pixels')
                axesSize = max(obj.PixelSize, [1, 1]);
                axesLimits = [1, max(axesSize(1)+1, 2); ...
                              1, max(axesSize(2)+1, 2)];
                newPosition = [1,1, axesSize];

                set(obj.Axes, 'Position', newPosition, ...
                    'XLim', axesLimits(1, :), 'YLim', axesLimits(2, :))
            else
                axesSize = max(obj.PixelSize, [1, 1]);
                obj.Axes.XLim = [1, max(axesSize(1)+1, 2)];
                obj.Axes.YLim = [1, max(axesSize(2)+1, 2)];
            end
        end

        function removeParent(obj)

            if ~isempty(obj.Parent) && isvalid(obj.Parent) && ...
                    isequal(get(obj.Parent, 'DefaultAxesCreateFcn'), obj.SiblingCreatedFcn)
                set(obj.Parent, 'DefaultAxesCreateFcn', obj.PreviousDefaultAxesCreateFcn)
            end

            if ~isempty(obj.Parent) && isvalid(obj.Parent) && ...
                    isappdata(obj.Parent, 'UIComponentCanvas') && ...
                    isequal(getappdata(obj.Parent, 'UIComponentCanvas'), obj)
                rmappdata(obj.Parent, 'UIComponentCanvas')
            end

            if ~isempty(obj.ParentDestroyedListener)
                delete(obj.ParentDestroyedListener)
                obj.ParentDestroyedListener = [];
            end

            if ~isempty(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
                obj.ParentSizeChangedListener = event.listener.empty;
            end

            if ~isempty(obj.ParentLocationChangedListener)
                delete(obj.ParentLocationChangedListener)
                obj.ParentLocationChangedListener = event.listener.empty;
            end
        end

        function reparentAxes(obj)
            obj.Axes.Parent = obj.Parent;

            obj.onSizeChanged()
            obj.setAxesLimits()

            obj.configureParentPositionChangedListener()
            obj.configureSiblingCreatedListener()
            obj.configureParentDestroyedListener()
        end

        function invokePreviousDefaultAxesCreateFcn(obj, src, evt)

            callback = obj.PreviousDefaultAxesCreateFcn;
            if isempty(callback); return; end

            if isa(callback, 'function_handle')
                callback(src, evt)
            elseif iscell(callback)
                callback{1}(src, evt, callback{2:end})
            end
        end
    end

    methods % Set/Get

        function size = get.Size(obj)
            size = obj.PixelSize;
        end

        function set.Parent(obj, newValue)
        %set.Parent Validate value and assign to Parent property

            errMsg = sprintf(['Error setting property ''Parent'' of class ''%s'': \n', ...
                    'Value must be ''matlab.graphics.Graphics'''], class(obj));

            assert( isa(newValue, 'matlab.graphics.Graphics'), errMsg)

            % A parent holds at most one canvas; a second one would fight
            % over the DefaultAxesCreateFcn hook and the appdata entry.
            existingCanvas = getappdata(newValue, 'UIComponentCanvas');
            if ~isempty(existingCanvas) && isvalid(existingCanvas) ...
                    && existingCanvas ~= obj
                error('uim:UIComponentCanvas:DuplicateCanvas', ...
                    ['The parent container already has a UIComponentCanvas. ', ...
                     'Use uim.UIComponentCanvas.getOrCreate to retrieve it.'])
            end

            hadParent = ~isempty(obj.Parent) && isvalid(obj.Parent);

            if hadParent
                obj.removeParent();
            end

            obj.Parent = newValue;

            % Add class instance to appdata of the parent handle
            setappdata(obj.Parent, 'UIComponentCanvas', obj);

            if hadParent
                obj.reparentAxes();
            end
        end

        function set.PixelSize(obj, newValue)

            assert(isnumeric(newValue) && numel(newValue)==2, ...
                'uim:InvalidPropertyValue', ...
                'PixelSize should be a vector of two elements')

            isPixelSizeChanged = any(newValue ~= obj.PixelSize);
            if ~isPixelSizeChanged; return; end

            obj.PixelSize = newValue;

            % Update axes limits to correspond with the canvas pixelsize.
            obj.setAxesLimits()
        end

        function locationPoint = getLocationPoint(obj, locationKey)
            locationPoint = uim.abstract.Component.location2point(obj.PixelSize, locationKey);
        end
    end

    methods (Static)

        function obj = getOrCreate(hParent)
        %getOrCreate Return the canvas attached to hParent, creating one if needed
            obj = getappdata(hParent, 'UIComponentCanvas');
            if isempty(obj) || ~isvalid(obj)
                obj = uim.UIComponentCanvas(hParent);
            end
        end

        function hAxes = createComponentAxes(hParent)

            args = uim.utility.getAxesToolbarArgs();

            hAxes = axes(hParent, args{:});

            set(hAxes, 'XTick', [], 'YTick', [])
            hAxes.Visible = 'off';
            hAxes.Units = 'pixel';
            hAxes.HandleVisibility = 'off';
            hAxes.Tag = 'Widget Container';

            axis(hAxes, 'equal')
            hold(hAxes, 'on')

            if ~isempty(args)
                disableDefaultInteractivity(hAxes)
            end
        end
    end
end
