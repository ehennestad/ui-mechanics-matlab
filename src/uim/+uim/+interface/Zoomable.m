classdef Zoomable < handle

    % TODO:
    % [ ] Add switcher to only zoom in x or only zoom in y.
    % [ ] Add plot zoom region here.
    %
    % [ ] Make this super class for both zoom and panning, i.e an
    %     axesDataLimits mixin (abstract) pointer tool...

    properties (Abstract)
        ZoomFactor
        XLimOrig
        YLimOrig
    end

    properties
        ZoomFinishedFcn
        % LimitsChangedFcn % Function to run when limits change.
    end

    methods

        function shiftView(obj, shift)
        % Move visible portion of axes according to shift

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
            % Zoom in image

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

            isInsideAxes = uim.interface.internal.isPointInsideLimits(...
                pointerFigurePixel, axPos(1) + [0, axPos(3)], axPos(2) + [0, axPos(4)]);

            if isInsideAxes
                [xLimNew, yLimNew] = uim.interface.internal.zoomLimitsAboutPoint(...
                    xLim, yLim, zoomF, pointerFigurePixel - axPos(1:2), ...
                    axPos(3:4), pointerData, obj.Axes.YDir);
            else
                xLimNew = uim.interface.internal.scaleLimits(xLim, zoomF);
                yLimNew = uim.interface.internal.scaleLimits(yLim, zoomF);
            end

            xLimNew = uim.interface.internal.clampRangeWithin(xLimNew, obj.XLimOrig);
            yLimNew = uim.interface.internal.clampRangeWithin(yLimNew, obj.YLimOrig);

            setNewImageLimits(obj, xLimNew, yLimNew)
        end

        function setNewImageLimits(obj, xLimNew, yLimNew)

            % Todo: Have tests here to prevent setting limits outside of
            % image limits.

            pos = getpixelposition(obj.Axes);
            axesAspectRatio = pos(3)/pos(4);

            % Adjust limits so that the zoomed image fills up the display.
            % An axes collapsed to zero width or height has no aspect to
            % fill, so its limits are only clamped.
            if axesAspectRatio > 0 && isfinite(axesAspectRatio)
                [xLimNew, yLimNew] = uim.interface.internal.fitLimitsToAspectRatio(...
                    xLimNew, yLimNew, axesAspectRatio);
            end

            xLimNew = uim.interface.internal.clampRangeWithin(xLimNew, obj.XLimOrig);
            yLimNew = uim.interface.internal.clampRangeWithin(yLimNew, obj.YLimOrig);

            set(obj.Axes, 'XLim', xLimNew, 'YLim', yLimNew)
            %plotZoomRegion(obj, xLimNew, yLimNew)

            if ~isempty(obj.ZoomFinishedFcn)
                obj.ZoomFinishedFcn()
            end
        end

        function setNewXLims(obj, newLimits)

            if nargin == 1 || isempty(newLimits)
                newLimits = obj.XLimOrig;
            end

            % Todo: Make sure XLim2 > XLim1
            newLimits = uim.interface.internal.intersectRanges(newLimits, obj.XLimOrig);
            set(obj.Axes, 'XLim', newLimits);

            drawnow limitrate
        end

        function setNewYLims(obj, newLimits)

            if nargin == 1 || isempty(newLimits)
                newLimits = obj.YLimOrig;
            end

            newLimits = uim.interface.internal.intersectRanges(newLimits, obj.YLimOrig);
            set(obj.Axes, 'YLim', newLimits);
        end
    end
end
