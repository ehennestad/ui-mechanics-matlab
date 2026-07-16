classdef Image < uim.abstract.Component

    properties (Constant)
        Type = 'image'
    end

    properties
        CData = []
        Alpha = []

        LockAspectRatio = true;

        ColorMap = []
    end

    properties (Access = private)
        ImageHandle
    end

    properties (Transient, Dependent)
        AspectRatio
    end

    methods
        function obj = Image(hParent, varargin)

            obj@uim.abstract.Component(hParent, varargin{:})

            % Image specific construction....

            % Todo: might want to keep bg...
            delete( obj.Background )
            obj.Background = [];

            obj.IsConstructed = true;

            obj.plotImage()
        end

        function delete(obj)
            if ~isempty(obj.ImageHandle) && isvalid(obj.ImageHandle)
                delete(obj.ImageHandle)
            end
        end
    end

    methods % Set/get
        function set.CData(obj, newValue)

            isValidDim = ismatrix(newValue) || ndims(newValue) == 3;
            isValidSize = size(newValue, 3) == 1 || size(newValue, 3) == 3;

            assert(isValidDim & isValidSize, 'Value must be an image matrix')

            obj.CData = flipud(newValue);

            obj.plotImage()
        end

        function set.Alpha(obj, newValue)
            % Todo: Validate size (same size as image)

            obj.Alpha = flipud(newValue);
            obj.onAlphaSet()
        end

        function ar = get.AspectRatio(obj)
            imSize = size(obj.CData);
            ar = imSize(1) / imSize(2);
        end
    end

    methods (Access = protected)
        function resize(obj)
            resize@uim.abstract.Component(obj)
            obj.setImagePosition()
        end

        function relocate(obj, shift)
            relocate@uim.abstract.Component(obj, shift)

            obj.ImageHandle.XData = obj.ImageHandle.XData + shift(1);
            obj.ImageHandle.YData = obj.ImageHandle.YData + shift(2);
        end
    end

    methods (Hidden, Access = protected)

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end

            % Set visibility of graphics components.
            obj.ImageHandle.Visible =  obj.Visible;
        end

        function onAlphaSet(obj)

            if ~obj.IsConstructed; return; end
            if isempty(obj.ImageHandle); return; end

            obj.ImageHandle.AlphaData = obj.Alpha;
        end
    end

    methods (Access = protected)

        function plotImage(obj)
            if ~obj.IsConstructed; return; end

            if ~isempty(obj.ImageHandle)
                delete(obj.ImageHandle)
                obj.ImageHandle=[];
            end

            obj.ImageHandle = image(obj.CanvasAxes, 'CData', obj.CData);
            obj.ImageHandle.AlphaData = obj.Alpha;

            obj.ImageHandle.HitTest = 'off';
            obj.ImageHandle.PickableParts = 'none';

            obj.setImagePosition()
        end

        function setImagePosition(obj)

            imSize = obj.Size;

            if obj.LockAspectRatio
                if obj.AspectRatio > obj.Size(1) / obj.Size(2)
                    imSize(1) = imSize(2) ./ obj.AspectRatio;
                else
                    imSize(2) = imSize(1) .* obj.AspectRatio;
                end
            end

            xPos = obj.Position(1) + [0, imSize(1)];
            yPos = obj.Position(2) + [0, imSize(2)];

            obj.ImageHandle.XData = xPos;
            obj.ImageHandle.YData = yPos;
        end
    end
end
