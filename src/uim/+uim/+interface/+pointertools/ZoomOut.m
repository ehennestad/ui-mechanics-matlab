classdef ZoomOut < uim.interface.PointerTool & uim.interface.Zoomable

    properties (Constant)
        ExitMode = 'previous';
    end

    properties % Implement abstract properties from zoom
        ZoomFactor = 0.25
        XLimOrig
        YLimOrig
        RunDefault = false;
    end

    methods

        function obj = ZoomOut(hAxes)
            obj@uim.interface.PointerTool(hAxes)
            obj.XLimOrig = obj.Axes.XLim;
            obj.YLimOrig = obj.Axes.YLim;
        end

        function setPointerSymbol(obj)
            setptr(obj.Figure, 'glassminus');
        end

        function onButtonDown(obj, ~, event)

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
        end

        function onButtonUp(~, ~, ~)
        end
    end
end
