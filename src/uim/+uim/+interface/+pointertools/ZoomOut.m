classdef ZoomOut < uim.interface.PointerTool & uim.mixin.Zoomable
%ZoomOut Pointer tool that zooms out on a click
%
%   tool = uim.interface.pointertools.ZoomOut(hAxes) creates the tool for
%   hAxes. The axes limits at construction become XLimOrig and YLimOrig,
%   the outer bounds for every zoom, so set the limits to the full view
%   first. A PointerManager creates the tool for the key "zoomOut".
%
%   A left click zooms out about the pointer: each end of the limits
%   moves out by 2*ZoomFactor times the width (the view doubles with the
%   default 0.25). The new limits are widened to the axes aspect ratio
%   and kept inside XLimOrig and YLimOrig, then ZoomFinishedFcn runs. A
%   double-click restores XLimOrig and YLimOrig. Right-button presses
%   are ignored.
%
%   A host can take over the click zoom by setting ButtonDownFcn, which
%   is called as ButtonDownFcn() instead. With RunDefault true the
%   default zoom runs first.
%
%   ExitMode is 'previous'. The zoom methods come from
%   uim.mixin.Zoomable.
%
%   See also uim.interface.pointertools.ZoomIn, uim.mixin.Zoomable,
%   uim.interface.PointerManager

    properties (Constant)
        ExitMode = 'previous';
    end

    properties % Implement abstract properties from zoom
        ZoomFactor = 0.25 % Half the fraction of the width each limit moves out per click; 0.25 doubles the view
        XLimOrig % [min, max] x bounds for zooming, taken from the axes at construction
        YLimOrig % [min, max] y bounds for zooming, taken from the axes at construction
        RunDefault = false; % If true, run the default zoom before a host ButtonDownFcn
    end

    methods

        function obj = ZoomOut(hAxes)
        %ZoomOut Create the tool for an axes
        %
        %   tool = uim.interface.pointertools.ZoomOut(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
        %setPointerSymbol Set the figure pointer to a magnifier with a minus
            setptr(obj.Figure, 'glassminus');
        end

        function onButtonDown(obj, ~, event)
        %onButtonDown Zoom out on a click, or restore the full view on a double-click

            if event.Button==3; return; end

            switch obj.Figure.SelectionType
                case 'normal'
                    if isempty(obj.ButtonDownFcn)
                        obj.imageZoom('out')
                    else
                        if obj.RunDefault
                            obj.imageZoom('out')
                        end
                        obj.ButtonDownFcn();
                    end

                case 'open'
                    set(obj.Axes, 'XLim', obj.XLimOrig, 'YLim', obj.YLimOrig)
            end
        end

        function onButtonMotion(~, ~, ~)
        %onButtonMotion Do nothing; the tool acts on the press
        end

        function onButtonUp(~, ~, ~)
        %onButtonUp Do nothing; the tool acts on the press
        end
    end
end
