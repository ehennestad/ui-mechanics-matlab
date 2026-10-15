classdef Crop < uim.interface.PointerTool
%Crop Pointer tool for selecting a rectangular crop region of an image
%
%   tool = uim.interface.pointertools.Crop(hAxes) creates the tool for an
%   axes that shows an image in pixel coordinates. The axes limits at
%   construction become XLimOrig and YLimOrig, taken as the image
%   extent. Construction adds an empty text object to the axes for the
%   size readout. A PointerManager creates the tool for the key "crop".
%   The tool needs the Image Processing Toolbox (drawrectangle, or imrect
%   in releases without it).
%
%   activate lets the user draw a rectangle, or shows the previous crop
%   (CurrentXLim, CurrentYLim) for editing, and then blocks in uiwait
%   until the tool is deactivated, for example by toggling it off in the
%   PointerManager. While the rectangle moves, a "(width x height)"
%   label follows its corner. The rectangle's context menu has a "Reset
%   Crop" item that selects the whole image and ends the selection.
%
%   When the selection ends, the rounded rectangle becomes the crop:
%   the image outside it is dimmed by a semi-transparent patch,
%   CurrentXLim and CurrentYLim are set to its inclusive pixel limits,
%   and CropLimitChanged fires.
%
%   ExitMode is 'previous'. The mouse callbacks do nothing; the
%   rectangle object handles the mouse.
%
%   Crop events:
%     CropLimitChanged - Fires when a selection ends, with a
%                        uim.event.EventData whose XLim and YLim
%                        properties hold the new crop limits.
%
%   See also uim.interface.PointerManager, drawrectangle

    properties (Constant)
        ExitMode = 'previous';
    end

    properties
        PlotColor = [32, 32, 32]./255; % Color of the selection rectangle
        TextColor = ones(1,3)*0.8; % Color of the size readout; applied at construction
        XLimOrig % [min, max] x extent of the image, taken from the axes at construction
        YLimOrig % [min, max] y extent of the image, taken from the axes at construction

        % Inclusive [first, last] pixel limits of the current crop, or []
        % before the first selection. Setting them before activation
        % sets the rectangle the user starts from.
        CurrentXLim = []
        CurrentYLim = []
    end

    properties
        ImrectHandle % Selection rectangle while a selection is in progress, else []
        CroppedBoundaryPatch % Patch that dims the image outside the crop
        InitialCornerText % Not used
        RectangleSizeText % Text object showing the rectangle size
    end

    events
        CropLimitChanged % A selection ended; event data has XLim and YLim
    end

    methods

        function obj = Crop(hAxes)
        %Crop Create the tool for an image axes
        %
        %   tool = uim.interface.pointertools.Crop(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
            obj.RectangleSizeText = text(obj.Axes, 'Color', obj.TextColor);
        end

        function activate(obj)
        %activate Start a crop selection and wait until it ends
        %
        %   tool.activate() blocks until the tool is deactivated.
            activate@uim.interface.PointerTool(obj)
            obj.RectangleSizeText.Visible = 'on';
            obj.selectRectangularRoi()
            obj.updateInitialCornerText()
        end

        function deactivate(obj)
        %deactivate End the selection and apply the crop
        %
        %   tool.deactivate() resumes the uiwait in activate, deletes the
        %   rectangle and, if there was one, applies it as the crop and
        %   fires CropLimitChanged.

            deactivate@uim.interface.PointerTool(obj)
            uiresume(obj.Figure)

            if ~isempty(obj.ImrectHandle)

                if isvalid(obj.ImrectHandle)
                    if exist('drawrectangle', 'file')
                        rcc = round(obj.ImrectHandle.Position);
                    else
                        rcc = round(obj.ImrectHandle.getPosition);
                    end

                else
                    rcc = [];
                end

                delete(obj.ImrectHandle);
                obj.ImrectHandle = [];

            else
                rcc = [];
            end

            obj.RectangleSizeText.Visible = 'off';
            if isempty(rcc); return; end

            obj.makeCroppedRegionSemiOpaque(rcc)
            obj.updateLimits(rcc)

            evtData = uim.event.EventData('XLim', obj.CurrentXLim, 'YLim', obj.CurrentYLim);
            obj.notify('CropLimitChanged', evtData)
        end
    end

    methods

        function setPointerSymbol(obj)
        %setPointerSymbol Leave the figure pointer unchanged
        end
        function onButtonDown(~, ~, ~)
        %onButtonDown Do nothing; the selection rectangle handles the mouse
        end
        function onButtonMotion(~, ~, ~)
        %onButtonMotion Do nothing; the selection rectangle handles the mouse
            % Update rectangle size text
        end
        function onButtonUp(~, ~, ~)
        %onButtonUp Do nothing; the selection rectangle handles the mouse
        end
    end

    methods (Access = private)

        function updateInitialCornerText(obj)
        end

        function selectRectangularRoi(obj)

            rccInit = obj.getRectangleInitCoordinates;

            % Move to non-class function
            if exist('drawrectangle', 'file')
                if ~isempty(rccInit)
                    hrect = drawrectangle(obj.Axes, 'Position', rccInit);
                else
                    hrect = drawrectangle(obj.Axes);
                end
                addlistener(hrect, 'MovingROI', @obj.onRectangleSizeChanged);
                obj.updateRectangleContextMenu(hrect)

                hrect.LineWidth = 1;
                hrect.Color = obj.PlotColor;
                hrect.StripeColor = ones(1,3)*0.8;
                hrect.DrawingArea = [1, 1, obj.XLimOrig(2)-1, obj.YLimOrig(2)-1];

            else
                hrect = imrect(obj.Axes, rccInit); %#ok<IMRECT>
                hrect.setColor(obj.PlotColor)
                restrainCropSelection = makeConstrainToRectFcn('imrect', obj.XLimOrig, obj.YLimOrig);
                hrect.setPositionConstraintFcn( restrainCropSelection );
            end

            obj.ImrectHandle = hrect;
            uiwait(obj.Figure)

            obj.deactivate();
        end

        function makeCroppedRegionSemiOpaque(obj, rcc)

            % A patch with a hole: the crop stays in focus, the rest dims
            imSizeXY = [obj.XLimOrig(2), obj.YLimOrig(2)];
            [xCoords, yCoords] = uim.interface.internal.cropMaskOutline(rcc, imSizeXY);

            if isempty(obj.CroppedBoundaryPatch)
                h = patch(obj.Axes, xCoords, yCoords, 'k');
                h.FaceAlpha = 0.3;
                h.EdgeColor = 'none';
                h.Tag = 'Crop Outline';
                obj.CroppedBoundaryPatch = h;
            else
                h = obj.CroppedBoundaryPatch;
                set(h, 'XData', xCoords, 'YData', yCoords)
            end
        end

        function rccInit = getRectangleInitCoordinates(obj)
            rccInit = uim.geometry.internal.limitsToRectangle(...
                obj.CurrentXLim, obj.CurrentYLim);
        end

        function updateRectangleContextMenu(obj, hRect)

            hCMenu = hRect.ContextMenu;
            delete(hCMenu.Children(1))

            hMenuItem = uimenu(hCMenu, 'Text', 'Reset Crop');
            hMenuItem.Callback = @obj.resetCrop;
        end

        function updateLimits(obj, rcc)
            [obj.CurrentXLim, obj.CurrentYLim] = ...
                uim.geometry.internal.rectangleToLimits(rcc);
        end

        function onRectangleSizeChanged(obj, ~, evt)

            if isempty(obj.RectangleSizeText)
                obj.RectangleSizeText = text(obj.Axes);
                obj.RectangleSizeText.Color = ones(1,3)*0.8;
            end

            size = round( evt.CurrentPosition(3:4) );

            x = sum(evt.CurrentPosition([1,3]));
            y = sum(evt.CurrentPosition([2,4]));

            obj.RectangleSizeText.Position(1:2) = [x,y] + 5;
            obj.RectangleSizeText.String = sprintf('(%d x %d)', size(1), size(2));
        end

        function resetCrop(obj, ~, ~)

            rcc = zeros(1,4);
            rcc(1:2) = 1;
            rcc(3:4) = floor([obj.XLimOrig(2), obj.YLimOrig(2)]);
            obj.ImrectHandle.Position = rcc;
            drawnow
            obj.deactivate()
        end
    end
end
