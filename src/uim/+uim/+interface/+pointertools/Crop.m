classdef Crop < uim.interface.PointerTool

    properties (Constant)
        ExitMode = 'previous';
    end

    properties
        PlotColor = [32, 32, 32]./255;
        TextColor = ones(1,3)*0.8;
        XLimOrig
        YLimOrig

        CurrentXLim = []
        CurrentYLim = []
    end

    properties
        ImrectHandle
        CroppedBoundaryPatch
        InitialCornerText
        RectangleSizeText
    end

    events
        CropLimitChanged
    end

    methods

        function obj = Crop(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
            obj.RectangleSizeText = text(obj.Axes, 'Color', obj.TextColor);
        end

        function activate(obj)
            activate@uim.interface.PointerTool(obj)
            obj.RectangleSizeText.Visible = 'on';
            obj.selectRectangularRoi()
            obj.updateInitialCornerText()
        end

        function deactivate(obj)

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
        end
        function onButtonDown(~, ~, ~)
        end
        function onButtonMotion(~, ~, ~)
            % Update rectangle size text
        end
        function onButtonUp(~, ~, ~)
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
