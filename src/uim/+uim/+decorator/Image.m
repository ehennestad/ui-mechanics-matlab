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
%   CData and Alpha read back as assigned; the image is flipped only when
%   it is drawn, because the canvas y-axis points up. With
%   LockAspectRatio true, the image is scaled to fit inside the component
%   and keeps its aspect ratio.
%
%   See also uim.abstract.Component

    properties (Constant)
        Type = 'image' % Component type name.
    end

    properties
        CData = [] % Image data, an m-by-n or m-by-n-by-3 array as accepted by image.
        Alpha = [] % Transparency: empty, a scalar, or an array the size of the image (AlphaData).

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

            obj.CData = newValue;

            obj.plotImage()
        end

        function set.Alpha(obj, newValue)
            obj.validateAlpha(newValue)
            obj.Alpha = newValue;
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

            obj.ImageHandle.AlphaData = obj.getDrawnAlpha();
        end
    end

    methods (Access = protected)

        function plotImage(obj)
            if ~obj.IsConstructed; return; end

            if ~isempty(obj.ImageHandle)
                delete(obj.ImageHandle)
                obj.ImageHandle=[];
            end

            obj.validateAlpha(obj.Alpha)

            % The canvas y-axis points up, so the rows are drawn flipped
            obj.ImageHandle = image(obj.CanvasAxes, 'CData', flipud(obj.CData));
            obj.ImageHandle.AlphaData = obj.getDrawnAlpha();

            obj.ImageHandle.HitTest = 'off';
            obj.ImageHandle.PickableParts = 'none';

            obj.setImagePosition()
        end

        function setImagePosition(obj)

            imSize = obj.Size;

            if obj.LockAspectRatio
                % Both ratios are height / width: a relatively taller image
                % fills the height, a wider one fills the width
                if obj.AspectRatio > obj.Size(2) / obj.Size(1)
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

        function validateAlpha(obj, alpha)
        %validateAlpha Check that alpha is empty, a scalar or the size of the image
        %
        %   The size check needs CData. During construction it waits until
        %   the image is first drawn, so it does not depend on the order in
        %   which the options are assigned.
            if ~obj.IsConstructed; return; end

            imageSize = size(obj.CData, [1, 2]);
            assert(isempty(alpha) || isscalar(alpha) || isequal(size(alpha), imageSize), ...
                "uim:Image:InvalidAlpha", ...
                "Alpha must be empty, a scalar, or an array the size of the image (%d-by-%d).", ...
                imageSize(1), imageSize(2))
        end

        function alphaData = getDrawnAlpha(obj)
        %getDrawnAlpha Alpha in the drawn orientation of the image
            if isempty(obj.Alpha)
                alphaData = 1;
            else
                alphaData = flipud(obj.Alpha);
            end
        end
    end
end
