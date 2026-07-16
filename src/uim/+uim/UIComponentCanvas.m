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
%   canvas = uim.UIComponentCanvas(hAxes), where hAxes is an axes,
%   creates an *overlay* canvas: instead of covering the whole
%   container, the canvas axes covers just the pixel rectangle of hAxes
%   (the target axes) and tracks its position and size. This lets
%   components anchor inside a data axes (e.g. a toolbar in the
%   northeast corner of an image display). An axes holds at most one
%   overlay canvas, and overlay canvases coexist with a whole-container
%   canvas on the same container.
%
%   Overlay mode limitations (v1):
%     - The canvas anchors to the axes Position rectangle, not the
%       visible plot box (these differ under axis image/equal).
%     - Z-order among multiple canvases in a container follows canvas
%       creation order (later canvases stack on top).
%     - The target axes must be parented directly in a figure, uifigure,
%       panel or tab (no TiledChartLayout).
%     - Containers with CanvasMode='private' are not supported on an
%       overlay canvas.
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
        Parent matlab.graphics.Graphics             % Parent handle (figure/uifigure)
        Axes matlab.graphics.axis.Axes               % Handle to the axes which components are plotted in
        TargetAxes matlab.graphics.axis.Axes        % Overlay mode: the data axes this canvas covers (empty in classic mode)
        Children uim.abstract.Component % Flat list of all components drawn on this canvas
        Tag (1,1) string = "UI Component Canvas" % A tag which is also applied to the axes.
    end

    properties (Dependent, Transient)
        Size (1,2) double
    end

    properties (Access = private, Transient, Hidden)
        PixelPosition (1,4) double = [nan, nan, nan, nan]
        PixelSize (1,2) double = [nan, nan]
        ParentSizeChangedListener event.listener = event.listener.empty
        ParentLocationChangedListener event.listener = event.listener.empty
        Tooltip uim.interface.ToolTip
        ParentDestroyedListener
    end

    events
        SizeChanged
    end

    methods % Structors
        function obj = UIComponentCanvas(hParent, options)

            arguments
                hParent (1,1) matlab.graphics.Graphics = figure()
                options.Tag (1,1) string = "UI Component Canvas"
            end

            obj.Tag = options.Tag;

            if isa(hParent, 'matlab.graphics.axis.Axes')
                % Overlay mode: cover the pixel rectangle of the target
                % axes with a sibling canvas axes that tracks its geometry.
                hContainer = hParent.Parent;
                isSupportedContainer = isa(hContainer, 'matlab.ui.Figure') ...
                    || isa(hContainer, 'matlab.ui.container.Panel') ...
                    || isa(hContainer, 'matlab.ui.container.Tab');
                if ~isSupportedContainer
                    error('uim:UIComponentCanvas:UnsupportedAxesParent', ...
                        ['An overlay canvas requires the target axes to be ', ...
                         'parented directly in a figure, panel or tab. ', ...
                         'Axes inside a %s are not supported.'], class(hContainer))
                end
                % Must be assigned before Parent; the Parent setter keys
                % canvas ownership on the target axes in overlay mode.
                obj.TargetAxes = hParent;
                obj.Parent = hContainer;
            else
                obj.Parent = hParent;
            end

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
            % Delete components before the axes so each component can run
            % its own teardown against valid graphics objects. (Components
            % also self-delete via a canvas-destroyed listener; this pass
            % covers any that no longer hold that listener.)
            childList = obj.Children;
            for i = 1:numel(childList)
                if isvalid(childList(i))
                    delete(childList(i))
                end
            end

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
            if obj.isOverlay()
                error('uim:UIComponentCanvas:OverlayReparentNotSupported', ...
                    ['An overlay canvas follows its target axes and can not ', ...
                     'be reparented directly.'])
            end
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

    methods (Access = {?uim.abstract.Component}) % Child registration

        function registerChild(obj, component)
        %registerChild Add a component to the canvas' list of children
            if ~any(obj.Children == component)
                obj.Children = [obj.Children, component];
            end
        end

        function unregisterChild(obj, component)
        %unregisterChild Remove a component from the canvas' list of children
            obj.Children(obj.Children == component) = [];
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

            uim.utility.disableAxesInteractivity(obj.Axes)
        end

        function configureParentPositionChangedListener(obj)

            % Delete listeners if they already exist.
            if ~isempty(obj.ParentSizeChangedListener)
                delete(obj.ParentSizeChangedListener)
            end

            if ~isempty(obj.ParentLocationChangedListener)
                delete(obj.ParentLocationChangedListener)
            end

            % Create SizeChanged & LocationChanged listeners on the
            % tracked object (the parent container, or the target axes
            % in overlay mode).
            hSource = obj.getGeometryEventSource();

            el = listener(hSource, 'SizeChanged', @obj.onSizeChanged);
            obj.ParentSizeChangedListener = el;

            el = listener(hSource, 'LocationChanged', @obj.onLocationChanged);
            obj.ParentLocationChangedListener = el;

        end

        function configureParentDestroyedListener(obj)

            if ~isempty(obj.ParentDestroyedListener) && ...
                    isvalid(obj.ParentDestroyedListener)
                delete(obj.ParentDestroyedListener)
            end

            % In overlay mode the canvas dies with its target axes (which
            % also covers container destruction, since axes destruction
            % cascades from the container).
            obj.ParentDestroyedListener = addlistener(...
                obj.getGeometryEventSource(), ...
                'ObjectBeingDestroyed', @(~,~) delete(obj));
        end

        function configureSiblingCreatedListener(obj)
        %configureSiblingCreatedListener Need to know when a sibling is born

            % Use the undocumented DefaultAxesCreateFcn property of the
            % parent container to run a callback whenever new axes are
            % added. This is done because our axes always needs to stay
            % on top of the uistack. The hook is shared between all
            % canvases attached to the container via a registry (see
            % installSiblingCreatedHook).

            uim.UIComponentCanvas.installSiblingCreatedHook(obj.Parent, obj)

            % Hoist our own axes now: it was created before this canvas
            % registered with the hook, so its creation event restacked
            % only the previously registered canvases. This keeps the
            % invariant that canvases created later stack on top.
            obj.onSiblingCreated()
        end

    end

    methods (Access = protected) % Event callbacks

        function onSizeChanged(obj, ~, ~)
        %onSizeChanged Call an update to the PixelSize property
            newPixelPosition = obj.getTrackedPixelPosition();

            oldSize = obj.PixelSize;
            newSize = newPixelPosition(3:4);

            obj.PixelPosition = newPixelPosition;
            obj.PixelSize = newSize;

            % On creation oldSize is [nan, nan]; listeners can use this to
            % tell the initial sizing apart from an actual resize.
            evt = uim.event.SizeChangedData(oldSize, newSize);
            obj.notify('SizeChanged', evt)
        end

        function onLocationChanged(obj, ~, ~)
            obj.PixelPosition = obj.getTrackedPixelPosition();

            if obj.isOverlay()
                % A pure move changes the overlay origin without a size
                % change, so the set.PixelSize pathway will not trigger
                % an axes reposition. Do it here.
                obj.setAxesLimits()
            end
        end

        function onSiblingCreated(obj, ~, ~)
        %onSiblingCreated Keep our axes on top of the uistack
            try
                uistack(obj.Axes, 'top')
            catch ME
                switch ME.identifier
                    case 'MATLAB:ui:uifigure:UnsupportedAppDesignerFunctionality'
                        % uistack is unsupported in uifigures (in the
                        % releases that raise this error), so reorder the
                        % parent's Children directly. The canvas axes must
                        % temporarily be handle-visible to appear in
                        % Children at all.
                        obj.Axes.HandleVisibility = 'on';
                        restoreVisibility = onCleanup(...
                            @() set(obj.Axes, 'HandleVisibility', 'off'));

                        siblings = obj.Parent.Children;
                        isCanvasAxes = siblings == obj.Axes;
                        if any(isCanvasAxes)
                            % Children(1) is the top of the stack.
                            obj.Parent.Children = ...
                                [siblings(isCanvasAxes); siblings(~isCanvasAxes)];
                        end
                end
            end
        end
    end

    methods (Access = private) % Mode helpers

        function tf = isOverlay(obj)
        %isOverlay True when the canvas covers a target axes, not a container
            tf = ~isempty(obj.TargetAxes);
        end

        function pixelPosition = getTrackedPixelPosition(obj)
        %getTrackedPixelPosition Pixel rect the canvas axes should cover
            if obj.isOverlay()
                pixelPosition = getpixelposition(obj.TargetAxes);
            else
                pixelPosition = uim.utility.getContentPixelPosition(obj.Parent);
            end
        end

        function hSource = getGeometryEventSource(obj)
        %getGeometryEventSource Object whose geometry and lifetime the canvas tracks
            if obj.isOverlay()
                hSource = obj.TargetAxes;
            else
                hSource = obj.Parent;
            end
        end

        function hOwner = getOwnershipHandle(obj, hParent)
        %getOwnershipHandle Handle holding the canvas' appdata registration
            if obj.isOverlay()
                hOwner = obj.TargetAxes;
            else
                hOwner = hParent;
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

                if obj.isOverlay()
                    % The canvas axes and target axes share a graphics
                    % parent, so the target's pixel rect (from
                    % getpixelposition) is directly usable as the canvas
                    % axes position.
                    origin = obj.PixelPosition(1:2);
                else
                    % In classic mode PixelPosition(1:2) is the parent's
                    % content offset in the *grandparent* frame (from
                    % getContentPixelPosition) and must not be used here;
                    % the canvas axes fills its parent, whose local frame
                    % starts at [1,1].
                    origin = [1, 1];
                end
                newPosition = [origin, axesSize];

                set(obj.Axes, 'Position', newPosition, ...
                    'XLim', axesLimits(1, :), 'YLim', axesLimits(2, :))
            else
                axesSize = max(obj.PixelSize, [1, 1]);
                obj.Axes.XLim = [1, max(axesSize(1)+1, 2)];
                obj.Axes.YLim = [1, max(axesSize(2)+1, 2)];
            end
        end

        function removeParent(obj)

            if ~isempty(obj.Parent) && isvalid(obj.Parent)
                uim.UIComponentCanvas.uninstallSiblingCreatedHook(obj.Parent, obj)
            end

            hOwner = obj.getOwnershipHandle(obj.Parent);
            if ~isempty(hOwner) && isvalid(hOwner) && ...
                    isappdata(hOwner, 'UIComponentCanvas') && ...
                    isequal(getappdata(hOwner, 'UIComponentCanvas'), obj)
                rmappdata(hOwner, 'UIComponentCanvas')
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
    end

    methods % Set/Get

        function size = get.Size(obj)
            size = obj.PixelSize;
        end

        function set.Parent(obj, newValue)
        %set.Parent Validate value and assign to Parent property

            % Ownership is keyed on the container in classic mode and on
            % the target axes in overlay mode.
            hOwner = obj.getOwnershipHandle(newValue);

            % An owner holds at most one canvas; a second one would fight
            % over the appdata entry (and, for containers, the
            % DefaultAxesCreateFcn hook).
            existingCanvas = getappdata(hOwner, 'UIComponentCanvas');
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

            % Add class instance to appdata of the owner handle
            setappdata(hOwner, 'UIComponentCanvas', obj);

            if hadParent
                obj.reparentAxes();
            end
        end

        function set.PixelSize(obj, newValue)

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

    methods (Static, Access = private) % Sibling-created hook registry

        function installSiblingCreatedHook(hContainer, canvasObj)
        %installSiblingCreatedHook Register a canvas with the container's shared hook
        %
        %   All canvases attached to the same container share a single
        %   DefaultAxesCreateFcn. A registry in the container's appdata
        %   dispatches to each canvas in registration order, so canvases
        %   can be created and deleted in any order without corrupting
        %   the hook chain.

            hookData = getappdata(hContainer, 'UIComponentCanvasSiblingHook');

            if isempty(hookData)
                hookData = struct();
                hookData.PreviousFcn = get(hContainer, 'DefaultAxesCreateFcn');
                hookData.InstalledFcn = @(src, evt) ...
                    uim.UIComponentCanvas.dispatchSiblingCreated(hContainer, src, evt);
                hookData.Canvases = canvasObj;
                set(hContainer, 'DefaultAxesCreateFcn', hookData.InstalledFcn)
            elseif ~any(hookData.Canvases == canvasObj)
                hookData.Canvases = [hookData.Canvases, canvasObj];
            end

            setappdata(hContainer, 'UIComponentCanvasSiblingHook', hookData)
        end

        function uninstallSiblingCreatedHook(hContainer, canvasObj)
        %uninstallSiblingCreatedHook Remove a canvas from the container's shared hook
        %
        %   When the last registered canvas is removed, the container's
        %   DefaultAxesCreateFcn is restored to its pre-install value —
        %   unless a third party has replaced the hook in the meantime,
        %   in which case their hook is left untouched.

            hookData = getappdata(hContainer, 'UIComponentCanvasSiblingHook');
            if isempty(hookData); return; end

            keep = isvalid(hookData.Canvases) & hookData.Canvases ~= canvasObj;
            hookData.Canvases = hookData.Canvases(keep);

            if isempty(hookData.Canvases)
                if isequal(get(hContainer, 'DefaultAxesCreateFcn'), hookData.InstalledFcn)
                    set(hContainer, 'DefaultAxesCreateFcn', hookData.PreviousFcn)
                end
                rmappdata(hContainer, 'UIComponentCanvasSiblingHook')
            else
                setappdata(hContainer, 'UIComponentCanvasSiblingHook', hookData)
            end
        end

        function dispatchSiblingCreated(hContainer, src, evt)
        %dispatchSiblingCreated Shared DefaultAxesCreateFcn for a container's canvases

            if ~isvalid(hContainer); return; end

            hookData = getappdata(hContainer, 'UIComponentCanvasSiblingHook');
            if isempty(hookData); return; end

            % Prune canvases that were deleted without a proper uninstall.
            hookData.Canvases = hookData.Canvases(isvalid(hookData.Canvases));
            setappdata(hContainer, 'UIComponentCanvasSiblingHook', hookData)

            % Invoke the hook that was present before the first canvas
            % installed the shared one.
            callback = hookData.PreviousFcn;
            if isa(callback, 'function_handle')
                callback(src, evt)
            elseif iscell(callback) && ~isempty(callback)
                callback{1}(src, evt, callback{2:end})
            end

            % Registration order: canvases created later end up on top.
            for canvas = hookData.Canvases
                canvas.onSiblingCreated(src, evt)
            end
        end
    end

    methods (Static)

        function obj = getOrCreate(hParent)
        %getOrCreate Return the canvas attached to hParent, creating one if needed
        %
        %   hParent can be a figure, uifigure, panel or tab (whole-container
        %   canvas) or an axes (overlay canvas covering that axes).
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

            uim.utility.disableAxesInteractivity(hAxes)
        end
    end
end
