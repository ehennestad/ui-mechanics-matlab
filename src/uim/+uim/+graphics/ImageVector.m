classdef ImageVector < handle
%ImageVector Vector image made of polygons that move and scale as one
%
%   obj = uim.graphics.ImageVector(hParent, vectorData) plots each shape
%   of vectorData as a filled polygon without an edge in hParent, an
%   axes or an hggroup. vectorData is a struct array with the fields
%   Shape (a polyshape) and Color (its face color), such as an icon from
%   uim.style.getDefaultIcons, or the path (character vector) of a
%   MAT-file holding such a struct in the variable imageVector. Any
%   other parent raises uim:ImageVector:InvalidParent.
%
%   Each shape is drawn with plot. For an hggroup parent the constructor
%   holds the ancestor axes. An axes parent is held while the shapes are
%   drawn and then gets its previous NextPlot back, so the shapes are
%   added to the existing content. The object is stored in
%   hParent.UserData.Handles, so it lives as long as the parent;
%   hParent.UserData must be empty or a struct.
%
%   Position is the point named by HorizontalAlignment and
%   VerticalAlignment (for example the bottom-left corner); changing an
%   alignment keeps Position and moves the image around it. scale (and
%   Width and Height) resizes about the axes origin and rotate turns about
%   the box centre; both leave Position at the anchor's new location.
%
%   ImageVector methods:
%     translate       - Move the image by [dx, dy]
%     scale           - Resize about the axes origin
%     rotate          - Turn about the bounding box centre
%     fliplr, flipud  - Mirror the image within its bounding box
%     getVectorStruct - Current shapes and colors as a struct array
%
%   Example:
%       icons = uim.style.getDefaultIcons();
%       hAxes = axes(figure);
%       hold(hAxes, "on")
%       axis(hAxes, "equal")
%       icon = uim.graphics.ImageVector(hAxes, icons.zoomIn);
%       icon.Height = 1;
%       icon.Position = [0, 0];
%
%   See also uim.style.getDefaultIcons, uim.graphics.patchLineDrawing,
%   polyshape

    properties

        HorizontalAlignment = 'center' % left | center | right: x of the box point that Position names
        VerticalAlignment = 'middle' % bottom | middle | top: y of the box point that Position names

        Shape % Not used
        Color % Face color applied to every polygon; empty until set
        Alpha % Face alpha (0-1) applied to every polygon; empty until set
        Parent % Not used

        LockAspectRatio = true % If true, setting Width or Height scales both dimensions
        PickableParts = 'visible' % PickableParts of every polygon
        HitTest = 'on' % HitTest of every polygon
    end

    properties (Dependent)
        Position % [x, y] of the alignment point, in data units; setting it moves the image
        Angle % Total rotation in degrees, counterclockwise; setting it rotates by the difference
        Width % Bounding box width in data units; setting it scales about the axes origin
        Height % Bounding box height in data units; setting it scales about the axes origin
        Clipping % Clipping of the polygons ('on' or 'off'); reads the first polygon
        Visible % Visibility of the polygons ('on' or 'off'); reads the first polygon
    end

    properties (SetAccess = private)
        BoundingBox % [x, y, width, height] of all polygons, in data units
    end

    properties (Access = private)
        NumShapes
        Polygons

        CurrentAngle = 0
        CurrentPosition = [0, 0]
    end

    methods

        function obj = ImageVector(hParent, pathStr, varargin)
        %ImageVector Plot vector image data in an axes or hggroup
        %
        %   obj = uim.graphics.ImageVector(hParent, vectorData)
        %   obj = uim.graphics.ImageVector(hParent, matFilePath)
        %
        %   Further inputs are ignored.

            assert(isa(hParent, 'matlab.graphics.axis.Axes') || ...
            isa(hParent, 'matlab.graphics.primitive.Group'), ...
            "uim:ImageVector:InvalidParent", 'Invalid parent handle for ImageVector');

            if isa(pathStr, 'char')
                S = load(pathStr);
                V = S.imageVector;
            elseif isa(pathStr, 'struct')
                V = pathStr;
            end

            numShapes = numel(V);

            hP = gobjects(numShapes, 1);

            if isa(hParent, 'matlab.graphics.axis.Axes')
                % Plot replaces the content of an axes that is not held.
                % The previous NextPlot is restored when the constructor
                % exits, also if a shape fails to plot.
                nextPlot = hParent.NextPlot;
                hParent.NextPlot = 'add';
                restoreNextPlot = onCleanup(@() set(hParent, 'NextPlot', nextPlot));
            else
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

            obj.CurrentPosition = uim.graphics.internal.boundingBoxAnchor(...
                obj.BoundingBox, obj.HorizontalAlignment, obj.VerticalAlignment);
        end

        function delete(obj)

            for i = 1:obj.NumShapes
                delete(obj.Polygons(i))
            end

            delete(obj)
        end

        function V = getVectorStruct(obj)
        %getVectorStruct Current shapes and colors as a struct array
        %
        %   V = obj.getVectorStruct() returns a struct array with the
        %   fields Shape (a polyshape of each polygon's current vertices)
        %   and Color (its face color), in the form the constructor
        %   accepts.
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
        %rotate Turn the image about its bounding box centre
        %
        %   obj.rotate(angle) rotates every polygon by angle degrees,
        %   counterclockwise, about the centre of the current bounding box
        %   and adds angle to Angle.

            origBBox = obj.BoundingBox;
            %currentPosition = obj.CurrentPosition;

            offset = origBBox(1:2) + origBBox(3:4)/2;
            obj.translate(-offset);

            for i = 1:obj.NumShapes
                obj.Polygons(i).Shape = rotate(obj.Polygons(i).Shape, angle);
            end

            obj.CurrentAngle = obj.CurrentAngle + angle;
            obj.translate(offset);
            obj.updateAnchorPosition()
        end

        function fliplr(obj)
        %fliplr Mirror the image left to right within its bounding box
        %
        %   obj.fliplr() keeps the bounding box and Position.

            warning('off', 'MATLAB:polyshape:repairedBySimplify')

            currentPositionKeep = obj.CurrentPosition;

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

            obj.CurrentPosition = currentPositionKeep;
        end

        function flipud(obj)
        %flipud Mirror the image top to bottom within its bounding box
        %
        %   obj.flipud() keeps the bounding box and Position.

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
        %translate Move the image by an offset
        %
        %   obj.translate(shift) moves every polygon and Position by
        %   shift = [dx, dy] in data units.

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
        %scale Resize the image about the axes origin
        %
        %   obj.scale(scaleFactor) multiplies all coordinates by
        %   scaleFactor, a scalar or [sx, sy]. Points move towards or away
        %   from (0, 0), so the image moves unless it contains the origin.
        %   Position follows the alignment point.

            if isscalar(scaleFactor)
                scaleFactor = repmat(scaleFactor, 1, 2);
            end

            for i = 1:obj.NumShapes
                obj.Polygons(i).Shape = scale(obj.Polygons(i).Shape, scaleFactor);
            end
            obj.updateAnchorPosition()
        end

        function reposition(obj, newAlignment)
        %reposition Shift the shapes so the new alignment anchor sits at Position
        %
        %   obj.reposition(newAlignment) moves the image so the point
        %   of the bounding box named by newAlignment lies at Position.
        %   newAlignment is one horizontal ('left', 'center', 'right') or
        %   vertical ('bottom', 'middle', 'top') alignment; only that
        %   coordinate of the image moves, and Position stays put. The
        %   alignment properties are not changed; setting
        %   HorizontalAlignment or VerticalAlignment calls this method.
        %   Any other value raises uim:ImageVector:InvalidAlignment.

            bbox = obj.BoundingBox;
            shift = [0, 0];

            switch newAlignment
                case {'left', 'center', 'right'}
                    anchor = uim.graphics.internal.boundingBoxAnchor(...
                        bbox, newAlignment, 'bottom');
                    shift(1) = obj.CurrentPosition(1) - anchor(1);
                case {'bottom', 'middle', 'top'}
                    anchor = uim.graphics.internal.boundingBoxAnchor(...
                        bbox, 'left', newAlignment);
                    shift(2) = obj.CurrentPosition(2) - anchor(2);
                otherwise
                    error("uim:ImageVector:InvalidAlignment", ...
                        "Unknown alignment ""%s"".", newAlignment)
            end

            position = obj.CurrentPosition;
            obj.translate(shift);
            obj.CurrentPosition = position;
        end
    end

    methods (Access = private)

        function updateAnchorPosition(obj)
        %updateAnchorPosition Set Position to the alignment anchor of the current box
            obj.CurrentPosition = uim.graphics.internal.boundingBoxAnchor(...
                obj.BoundingBox, obj.HorizontalAlignment, obj.VerticalAlignment);
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
            oldValue = obj.HorizontalAlignment;

            if ~strcmp(oldValue, value)
                obj.reposition(value)
                obj.HorizontalAlignment = value;
            end
        end

        function set.VerticalAlignment(obj, value)
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

            anchorPosition = uim.graphics.internal.boundingBoxAnchor(...
                obj.BoundingBox, obj.HorizontalAlignment, obj.VerticalAlignment);

            shift = value - anchorPosition;
            obj.translate(shift);

            obj.CurrentPosition = value;
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
