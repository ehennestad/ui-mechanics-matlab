classdef ZoomOut < uim.interface.PointerTool & uim.interface.Zoomable

    properties (Constant)
        exitMode = 'previous';
    end

    properties % Implement abstract properties from zoom
        zoomFactor = 0.25
        xLimOrig
        yLimOrig
        runDefault = false;
    end

    methods

        function obj = ZoomOut(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.xLimOrig = obj.hAxes.XLim;
            obj.yLimOrig = obj.hAxes.YLim;
        end

        function setPointerSymbol(obj)
            setptr(obj.hFigure, 'glassminus');
        end

        function onButtonDown(obj, ~, event)

            if event.Button==3; return; end

            switch obj.hFigure.SelectionType
                case 'normal'
                    if isempty(obj.buttonDownCallback)
                        obj.imageZoom('out')
                    else
                        if obj.runDefault
                            obj.imageZoom('out')
                        end
                        obj.buttonDownCallback();
                    end

                case 'open'
                    set(obj.hAxes, 'XLim', obj.xLimOrig, 'YLim', obj.yLimOrig)
            end
        end

        function onButtonMotion(~, ~, ~)
        end

        function onButtonUp(~, ~, ~)
        end
    end
end
