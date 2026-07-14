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

            % Create an alphamask for image, where cropped part is in focus
            vertexX = rcc(1) + [0, rcc(3), rcc(3), 0];
            vertexY = rcc(2) + [0, 0, rcc(4), rcc(4)];

            imSizeXY = [obj.XLimOrig(2), obj.YLimOrig(2)];

        %             mask = double(poly2mask(vertexX, vertexY, imSizeXY(2), imSizeXY(1)));
        %             mask(~mask) = 0.4;
        %             hImage.AlphaData = mask;

            outerBoxX = [0, imSizeXY(1)+1, imSizeXY(1)+1, 0, 0];
            innerBoxX = [vertexX, vertexX(1)];
            outerBoxY = [imSizeXY(2)+1, imSizeXY(2)+1, 0, 0, imSizeXY(2)+1];
            innerBoxY = [vertexY, vertexY(1)];

            if isempty(obj.CroppedBoundaryPatch)
                h = patch(obj.Axes, [outerBoxX, innerBoxX], [outerBoxY, innerBoxY], 'k');
                h.FaceAlpha = 0.3;
                h.EdgeColor = 'none';
                h.Tag = 'Crop Outline';
                obj.CroppedBoundaryPatch = h;
            else
                h = obj.CroppedBoundaryPatch;
                set(h, 'XData', [outerBoxX, innerBoxX], 'YData',  [outerBoxY, innerBoxY] )
            end
        end

        function rccInit = getRectangleInitCoordinates(obj)
            xLim = obj.CurrentXLim;
            yLim = obj.CurrentYLim;

            if isequal(xLim, [1,inf]) && isequal(yLim, [1,inf])
                rccInit = [];
            elseif isempty(xLim) && isempty(yLim)
                rccInit = [];
            else
                rccInit = zeros(1,4);
                rccInit([1,3]) = [xLim(1), xLim(2)-xLim(1)];
                rccInit([2,4]) = [yLim(1), yLim(2)-yLim(1)];
            end
        end

        function updateRectangleContextMenu(obj, hRect)

            hCMenu = hRect.ContextMenu;
            delete(hCMenu.Children(1))

            hMenuItem = uimenu(hCMenu, 'Text', 'Reset Crop');
            hMenuItem.Callback = @obj.resetCrop;
        end

        function updateLimits(obj, rcc)
            obj.CurrentXLim = [rcc(1), rcc(1) + rcc(3) - 1];
            obj.CurrentYLim = [rcc(2), rcc(2) + rcc(4) - 1];
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
