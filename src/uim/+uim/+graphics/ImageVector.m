classdef ImageVector < handle
%ImageVector Plot a set of polygons as one object.
%
%   Methods for placing and scaling all polygons belonging to the group

    % NB: setting position and alignment of image has some bugs. setting
    % alignment first and then position works, but not always the other
    % way around?

    properties

        HorizontalAlignment = 'center' % left | center | right
        VerticalAlignment = 'middle' % bottom | middle | top

        Shape
        Color
        Alpha
        Parent

        LockAspectRatio = true
        PickableParts = 'visible'
        HitTest = 'on'
    end

    properties (Dependent)
        Position
        Angle
        Width
        Height
        Clipping
        Visible
    end

    properties (SetAccess = private)
        BoundingBox
    end

    properties (Access = private)
        NumShapes
        Polygons

        CurrentAngle = 0
        CurrentPosition = [0, 0]
    end

    methods

        function obj = ImageVector(hParent, pathStr, varargin)

            assert(isa(hParent, 'matlab.graphics.axis.Axes') || ...
            isa(hParent, 'matlab.graphics.primitive.Group'), ...
            'Invalid parent handle for ImageVector');

            if isa(pathStr, 'char')
                S = load(pathStr);
                V = S.imageVector;
            elseif isa(pathStr, 'struct')
                V = pathStr;
            end

            numShapes = numel(V);

            hP = gobjects(numShapes, 1);

            if ~isa(hParent, 'matlab.graphics.axis.Axes')
                hAxes = ancestor(hParent, 'axes');
                hold(hAxes, 'on')
            end

            for i = 1:numShapes
                hP(i) = plot(V(i).Shape, 'FaceColor', V(i).Color, 'FaceAlpha', 1, 'EdgeColor', 'none', 'Parent', hParent);
            end

            obj.NumShapes = numShapes;
            obj.Polygons = hP;

            % Find out how to prevent sticking the object to the userdata
            % to avoid it being deleted when object goes out of scope...
            if isempty(hParent.UserData)
                hParent.UserData = struct();
            end

            if isfield(hParent.UserData, 'Handles')
                hParent.UserData.Handles(end+1) = obj;
            else
                hParent.UserData.Handles = obj;
            end
        end

        function delete(obj)

            for i = 1:obj.NumShapes
                delete(obj.Polygons(i))
            end

            delete(obj)
        end

        function V = getVectorStruct(obj)
            polyShape = arrayfun(@(h) h.Shape, obj.Polygons, 'uni', 0);
            colors = arrayfun(@(h) h.FaceColor, obj.Polygons, 'uni', 0);

            for i = 1:numel(polyShape)
                p1 = polyShape{i};
                p2 = polyshape(p1.Vertices, 'Simplify', false); % Set simplify to false to avoid calling check and simplify on creation
                polyShape{i} = p2;
            end

            V = struct('Shape', polyShape, 'Color', colors);
        end

        function rotate(obj, angle)

            origBBox = obj.BoundingBox;
            %currentPosition = obj.CurrentPosition;

            offset = origBBox(1:2) + origBBox(3:4)/2;
            obj.translate(-offset);

            for i = 1:obj.NumShapes
                obj.Polygons(i).Shape = rotate(obj.Polygons(i).Shape, angle);
            end

            obj.CurrentAngle = obj.CurrentAngle + angle;
            obj.translate(offset);
        end

        function fliplr(obj)

            warning('off', 'MATLAB:polyshape:repairedBySimplify')

            origBBox = obj.BoundingBox;

            dx = -origBBox(1);
            obj.translate([-dx, 0]);

            for i = 1:obj.NumShapes
                obj.Polygons(i).Shape.Vertices = [-1, 1] .* obj.Polygons(i).Shape.Vertices;
            end

            newBBox = obj.BoundingBox;
            dx = origBBox(1) - newBBox(1);

            obj.translate([dx, 0]);

            warning('on', 'MATLAB:polyshape:repairedBySimplify')
        end

        function flipud(obj)

            warning('off', 'MATLAB:polyshape:repairedBySimplify')

            currentPositionKeep = obj.CurrentPosition;

            origBBox = obj.BoundingBox;

            dy = -origBBox(2);

            obj.translate([0, -dy]);

            for i = 1:obj.NumShapes
                obj.Polygons(i).Shape.Vertices = [1, -1] .* obj.Polygons(i).Shape.Vertices;
            end

            newBBox = obj.BoundingBox;
            dy = origBBox(2) - newBBox(2);

            obj.translate([0, dy]);

            warning('on', 'MATLAB:polyshape:repairedBySimplify')

            obj.CurrentPosition = currentPositionKeep;
        end

        function translate(obj, shift)

            % if strcmp(mVer(1:5), '9.4.0')
                for i = 1:obj.NumShapes
                    obj.Polygons(i).Shape.Vertices = obj.Polygons(i).Shape.Vertices + shift;
                end
%             else
%                 for i = 1:obj.NumShapes
%                     obj.Polygons(i).Shape = translate(obj.Polygons(i).Shape, shift);
%                 end
%             end

            obj.CurrentPosition =  obj.CurrentPosition + shift;
        end

        function scale(obj, scaleFactor)

            if isscalar(scaleFactor)
                scaleFactor = repmat(scaleFactor, 1, 2);
            end

            for i = 1:obj.NumShapes
                obj.Polygons(i).Shape = scale(obj.Polygons(i).Shape, scaleFactor);
            end
        end

        function reposition(obj, newAlignment)

            bbox = obj.BoundingBox;
            [dx,dy] = deal(0);

            switch newAlignment

                case 'left'
                    dx = obj.CurrentPosition(1) - bbox(1);
                case 'right'
                    dx = obj.CurrentPosition(1) - bbox(1)+bbox(3);
                case 'center'
                    dx = obj.CurrentPosition(1) - bbox(1)+bbox(3)/2;
                case 'top'
                    dy = obj.CurrentPosition(2) - bbox(2)+bbox(4);
                case 'bottom'
                    dy = obj.CurrentPosition(2) - bbox(2);
                case 'middle'
                    dy = obj.CurrentPosition(2) - bbox(2)+bbox(4)/2;
            end

            obj.translate([dx, dy]);
        end
    end

    methods (Access = private) % Callbacks for property changes

        function onColorChanged(obj, color)
            for i = 1:numel(obj.Polygons)
                obj.Polygons(i).FaceColor = color;
            end
        end

        function onAlphaChanged(obj, value)
            for i = 1:numel(obj.Polygons)
                obj.Polygons(i).FaceAlpha = value;
            end
        end
    end

    methods % set/get

        function set.Clipping(obj, newValue)

            for i = 1:numel(obj.Polygons)
                obj.Polygons(i).Clipping = newValue;
            end
        end

        function newValue = get.Clipping(obj)
            newValue = obj.Polygons(1).Clipping;
        end

        function set.Visible(obj, newValue)

            for i = 1:numel(obj.Polygons)
                obj.Polygons(i).Visible = newValue;
            end
        end

        function newValue = get.Visible(obj)
            newValue = obj.Polygons(1).Visible;
        end

        function set.HorizontalAlignment(obj, value)
            % Todo validatestring ('left', 'center', 'right');

            oldValue = obj.HorizontalAlignment;

            if ~strcmp(oldValue, value)
                obj.reposition(value)
                obj.HorizontalAlignment = value;
            end
        end

        function set.VerticalAlignment(obj, value)
            % Todo validatestring ('top', 'middle', 'bottom');

            oldValue = obj.VerticalAlignment;
            obj.VerticalAlignment = value;

            if ~strcmp(oldValue, value)
                obj.reposition(value)
                obj.VerticalAlignment = value;
            end
        end

        function set.Width(obj, width)

            currentWidth = obj.Width;
            scaleFactorX = width / currentWidth;

            if obj.LockAspectRatio
                scaleFactorY = scaleFactorX;
            else
                scaleFactorY = 1;
            end

            scaleFactor = [scaleFactorX, scaleFactorY];

            obj.scale(scaleFactor)
        end

        function width = get.Width(obj)
            bbox = obj.BoundingBox;
            width = bbox(3);

%             shapes = cat(1, [obj.Polygons.Shape] );
%             coords = cat(1, shapes.Vertices);
%             width = uim.utility.range(coords(:, 1));
        end

        function set.Height(obj, height)

            currentHeight = obj.Height;
            scaleFactorY = height / currentHeight;

            if obj.LockAspectRatio
                scaleFactorX = scaleFactorY;
            else
                scaleFactorX = 1;
            end

            scaleFactor = [scaleFactorX, scaleFactorY];
            obj.scale(scaleFactor)
        end

        function height = get.Height(obj)
            bbox = obj.BoundingBox;
            height = bbox(4);

%             shapes = cat(1, [obj.Polygons.Shape] );
%             coords = cat(1, shapes.Vertices);
%             height = uim.utility.range(coords(:, 2));
        end

        function set.Position(obj, value)

            bbox = obj.BoundingBox;
            anchorPosition = [0,0];

            switch obj.VerticalAlignment
                case 'top'
                    anchorPosition(2) = bbox(2)+bbox(4);
                case 'bottom'
                    anchorPosition(2) = bbox(2);
                case 'middle'
                    anchorPosition(2) = bbox(2)+bbox(4)/2;
            end

            switch obj.HorizontalAlignment

                case 'left'
                    anchorPosition(1) = bbox(1);
                case 'right'
                    anchorPosition(1) = bbox(1)+bbox(3);
                case 'center'
                    anchorPosition(1) = bbox(1)+bbox(3)/2;
            end

            shift = value - anchorPosition;
            obj.translate(shift);

            obj.CurrentPosition = obj.BoundingBox(1:2) + obj.BoundingBox(3:4)/2;
        end

        function position = get.Position(obj)
            position = obj.CurrentPosition;
        end

        function set.Color(obj, newValue)
            obj.onColorChanged(newValue)
            obj.Color = newValue;
        end

        function set.Angle(obj, value)

            deltaAngle = value - obj.CurrentAngle;
            obj.rotate(deltaAngle)
        end

        function angle = get.Angle(obj)
            angle = obj.CurrentAngle;
        end

        function set.Alpha(obj, newValue)
            obj.onAlphaChanged(newValue)
            obj.Alpha = newValue;
        end

        function set.PickableParts(obj, newValue)
            set(obj.Polygons, 'PickableParts', newValue)
            obj.PickableParts = newValue;
        end

        function set.HitTest(obj, newValue)
            set(obj.Polygons, 'HitTest', newValue)
            obj.HitTest = newValue;
        end

        function bbox = get.BoundingBox(obj)

            shapes = cat(1, [obj.Polygons.Shape] );
            coords = cat(1, shapes.Vertices);

            coordinateRange = max(coords) - min(coords);

            bbox = [min(coords), coordinateRange];
        end
    end
end
