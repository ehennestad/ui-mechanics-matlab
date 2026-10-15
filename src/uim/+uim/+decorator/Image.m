classdef Image < uim.abstract.Component
%Image Image component drawn on a component canvas
%
%   Shows a picture (for example a logo) as a component, so it is placed
%   and resized with the same layout rules as other uim components. The
%   component has no background or border.
%
%   img = uim.decorator.Image(parent, Name=Value) creates the image in
%   parent (a uim.UIComponentCanvas, a uim container, an axes or a
%   graphics container) and sets public properties, for example
%
%       img = uim.decorator.Image(canvas, CData=imread("logo.png"), ...
%           Position=[10, 10, 64, 64], PositionMode="manual");
%
%   The image is stored flipped upside down, because the canvas y-axis
%   points up. Reading CData or Alpha back therefore returns the flipped
%   array, and assigning that value again flips the displayed image.
%
%   With LockAspectRatio true, the code that fits the image into the
%   component compares the image height/width ratio with the component
%   width/height ratio, so in a component that is not square the image
%   can extend past the component.
%
%   See also uim.abstract.Component

    properties (Constant)
        Type = 'image' % Component type name.
    end

    properties
        CData = [] % Image data, an m-by-n or m-by-n-by-3 array as accepted by image.
        Alpha = [] % Transparency, a scalar or an array the size of the image (AlphaData).

        LockAspectRatio = true; % When true, keep the image aspect ratio inside the component.

        ColorMap = [] % Not used by the component.
    end

    properties (Access = private)
        ImageHandle
    end

    properties (Transient, Dependent)
        AspectRatio % Image height divided by image width, from CData.
    end

    methods
        function obj = Image(hParent, varargin)
        %Image Create an image component
        %
        %   img = uim.decorator.Image(parent, Name=Value)

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
