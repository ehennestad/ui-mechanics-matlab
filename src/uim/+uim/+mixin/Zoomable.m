classdef Zoomable < uim.interface.AxesAttached
%Zoomable Mixin adding zoom-limit handling to a pointer tool
%
%   Combined into uim.interface.PointerTool subclasses. Axes and Figure
%   are declared by uim.interface.AxesAttached and implemented by
%   PointerTool.
%
%   Contract for subclasses:
%       - Inherit uim.interface.PointerTool, or another class that
%         implements Axes and Figure.
%       - Define ZoomFactor, the zoom step used by imageZoom (see
%         uim.geometry.scaleLimits), and XLimOrig and YLimOrig, the
%         [min, max] limits that zooming and panning never go beyond.
%
%   Methods provided:
%       imageZoom         - Zoom one step in or out about the pointer
%       shiftView         - Move the view by a shift in data units
%       setNewImageLimits - Fit limits to the axes aspect and apply them
%       setNewXLims       - Set XLim, clipped to XLimOrig
%       setNewYLims       - Set YLim, clipped to YLimOrig
%
%   See also uim.interface.pointertools.ZoomIn,
%   uim.interface.pointertools.ZoomOut

    % TODO:
    % [ ] Add switcher to only zoom in x or only zoom in y.
    % [ ] Add plot zoom region here.
    %
    % [ ] Make this super class for both zoom and panning, i.e an
    %     axesDataLimits mixin (abstract) pointer tool...

    properties (Abstract)
        ZoomFactor % Zoom step size used by imageZoom.
        XLimOrig % Outer [min, max] x-limits for zooming and panning.
        YLimOrig % Outer [min, max] y-limits for zooming and panning.
    end

    properties
        % Function called with no inputs after setNewImageLimits applies
        % new limits. Empty for none.
        ZoomFinishedFcn
        % LimitsChangedFcn % Function to run when limits change.
    end

    methods

        function shiftView(obj, shift)
        %shiftView Move the view by a shift in data units
        %
        %   obj.shiftView(shift) subtracts shift(1) from XLim and adds
        %   shift(2) to YLim, then applies the result with
        %   setNewImageLimits, which keeps the view inside XLimOrig and
        %   YLimOrig.

            % todo...

            % Get current axes limits
            xlim = get(obj.Axes, 'XLim');
            ylim = get(obj.Axes, 'YLim');

            % Convert mouse shift to image shift
            imshift = shift;
            xLimNew = xlim - imshift(1);
            yLimNew = ylim + imshift(2);

            obj.setNewImageLimits(xLimNew, yLimNew)
        end

        function imageZoom(obj, direction, speed)
        %imageZoom Zoom one step in or out about the pointer
        %
        %   obj.imageZoom(direction) zooms with direction "in" or "out".
        %   Zooming in scales the limits by -ZoomFactor and zooming out by
        %   2*ZoomFactor (see uim.geometry.scaleLimits), so with
        %   ZoomFactor 0.25 one step in halves the view and one step out
        %   doubles it. When the pointer is over the axes, the data point
        %   under it stays under it; otherwise the view scales about its
        %   centre. The result is kept inside XLimOrig and YLimOrig and
        %   applied with setNewImageLimits.
        %
        %   obj.imageZoom(direction, speed) multiplies the step by speed
        %   (default 1).

            if nargin < 3; speed = 1; end

            switch direction
                case 'in'
                        zoomF = -obj.ZoomFactor .* speed;
                case 'out'
                        zoomF = obj.ZoomFactor*2 .* speed;
            end

            xLim = get(obj.Axes, 'XLim');
            yLim = get(obj.Axes, 'YLim');

            % Get cursor position in figure (in pixels). The point which is
            % clicked should appear under the pointer when zooming in.
            figUnits = obj.Figure.Units;
            obj.Figure.Units = 'pixel';
            pointerFigurePixel = get(obj.Figure, 'CurrentPoint');
            obj.Figure.Units = figUnits;

            axUnits = obj.Axes.Units;
            obj.Axes.Units = 'pixel';
            pointerData = get(obj.Axes, 'CurrentPoint');
            obj.Axes.Units = axUnits;
            pointerData = pointerData(1, 1:2);

            axPos = getpixelposition(obj.Axes, true); % Need axes position in figure

            isInsideAxes = uim.geometry.isPointInsideLimits(...
                pointerFigurePixel, axPos(1) + [0, axPos(3)], axPos(2) + [0, axPos(4)]);

            if isInsideAxes
                [xLimNew, yLimNew] = uim.geometry.internal.zoomLimitsAboutPoint(...
                    xLim, yLim, zoomF, pointerFigurePixel - axPos(1:2), ...
                    axPos(3:4), pointerData, obj.Axes.YDir);
            else
                xLimNew = uim.geometry.scaleLimits(xLim, zoomF);
                yLimNew = uim.geometry.scaleLimits(yLim, zoomF);
            end

            xLimNew = uim.geometry.fitRangeInside(xLimNew, obj.XLimOrig);
            yLimNew = uim.geometry.fitRangeInside(yLimNew, obj.YLimOrig);

            setNewImageLimits(obj, xLimNew, yLimNew)
        end

        function setNewImageLimits(obj, xLimNew, yLimNew)
        %setNewImageLimits Fit limits to the axes aspect and apply them
        %
        %   obj.setNewImageLimits(xLim, yLim) widens one of the limits so
        %   the view matches the axes width/height ratio in pixels (see
        %   uim.geometry.fitLimitsToAspectRatio), keeps both inside
        %   XLimOrig and YLimOrig (see uim.geometry.fitRangeInside), sets
        %   XLim and YLim, and calls ZoomFinishedFcn.

            pos = getpixelposition(obj.Axes);
            axesAspectRatio = pos(3)/pos(4);

            % Adjust limits so that the zoomed image fills up the display.
            % An axes collapsed to zero width or height has no aspect to
            % fill, so its limits are only clamped.
            if axesAspectRatio > 0 && isfinite(axesAspectRatio)
                [xLimNew, yLimNew] = uim.geometry.fitLimitsToAspectRatio(...
                    xLimNew, yLimNew, axesAspectRatio);
            end

            xLimNew = uim.geometry.fitRangeInside(xLimNew, obj.XLimOrig);
            yLimNew = uim.geometry.fitRangeInside(yLimNew, obj.YLimOrig);

            set(obj.Axes, 'XLim', xLimNew, 'YLim', yLimNew)
            %plotZoomRegion(obj, xLimNew, yLimNew)

            if ~isempty(obj.ZoomFinishedFcn)
                obj.ZoomFinishedFcn()
            end
        end

        function setNewXLims(obj, newLimits)
        %setNewXLims Set XLim, clipped to XLimOrig
        %
        %   obj.setNewXLims(newLimits) sets XLim to newLimits with each end
        %   clipped to XLimOrig (see uim.geometry.intersectRanges).
        %   obj.setNewXLims() or an empty newLimits restores XLimOrig.

            if nargin == 1 || isempty(newLimits)
                newLimits = obj.XLimOrig;
            end

            newLimits = uim.geometry.intersectRanges(newLimits, obj.XLimOrig);
            set(obj.Axes, 'XLim', newLimits);

            drawnow limitrate
        end

        function setNewYLims(obj, newLimits)
        %setNewYLims Set YLim, clipped to YLimOrig
        %
        %   obj.setNewYLims(newLimits) sets YLim to newLimits with each end
        %   clipped to YLimOrig (see uim.geometry.intersectRanges).
        %   obj.setNewYLims() or an empty newLimits restores YLimOrig.

            if nargin == 1 || isempty(newLimits)
                newLimits = obj.YLimOrig;
            end

            newLimits = uim.geometry.intersectRanges(newLimits, obj.YLimOrig);
            set(obj.Axes, 'YLim', newLimits);
        end
    end
end
