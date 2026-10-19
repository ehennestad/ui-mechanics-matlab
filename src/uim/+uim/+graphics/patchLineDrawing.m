function hP = patchLineDrawing(hAxes, imageArray, options)
%patchLineDrawing Trace the dark shapes of a line drawing as filled polygons
%
%   hP = uim.graphics.patchLineDrawing(hAxes, imageArray) traces the
%   boundaries of the dark regions of imageArray and plots them into the
%   axes hAxes as one black polygon object. imageArray is a grayscale or
%   RGB image with values from 0 to 255; pixels whose mean over the color
%   channels is below 100 count as dark. Very short boundaries are
%   dropped; with plotType 'polygon' at least one boundary must remain.
%
%   Coordinates are image pixels centred on the image: x is the column
%   and y is the row, each minus half the image size. y grows with the
%   row number, so the drawing appears upright only in an axes with
%   YDir 'reverse'.
%
%   hP = uim.graphics.patchLineDrawing(hAxes, imageArray, Name=Value)
%   sets options:
%     SmoothIter   - Number of circular moving-mean passes over each
%                    boundary. Default 2; 0 disables smoothing.
%     SmoothWindow - Moving-mean window length in points. Default 10.
%     cropImage    - If true (default), first trim the white (255)
%                    border around the content.
%     plotType     - 'polygon' (default) plots one
%                    matlab.graphics.primitive.Polygon holding every
%                    boundary. 'patch' plots one patch per outer
%                    boundary, with the holes it contains cut out, and
%                    returns a column of patch handles.
%   Option names are case insensitive and may be abbreviated; an unknown
%   name raises an error. The function does not change the hold state
%   of hAxes, so with plotType 'polygon' the plot replaces the axes
%   content unless the axes is held.
%
%   The tracing uses bwboundaries from the Image Processing Toolbox.
%
%   See also uim.graphics.ImageVector, uim.style.IconSet

    arguments
        hAxes (1,1) {mustBeA(hAxes, ["matlab.graphics.axis.Axes", "matlab.ui.control.UIAxes"])}
        imageArray {mustBeNumeric, mustBeNonempty}
        options.SmoothIter (1,1) double {mustBeInteger, mustBeNonnegative} = 2
        options.SmoothWindow (1,1) double {mustBePositive} = 10
        options.cropImage (1,1) logical = true
        options.plotType (1,1) string {mustBeMember(options.plotType, ["polygon", "patch"])} = "polygon"
    end

    if options.cropImage
        imageArray = uim.graphics.internal.cropImageToContent(imageArray);
    end

    %% Get coordinates of edges
    BW = mean(imageArray, 3) < 100;

    switch options.plotType
        case 'polygon'
            hP = plotObjectsAsPolygons(hAxes, BW, options);
        case 'patch'
            hP = patchObjects(hAxes, BW, options);
    end
end

function hP = patchObjects(hAxes, BW, options)
%patchObjects Plot binary objects using patches.

    % Get size of image
    imSize = [size(BW, 1), size(BW, 2)];

    [B, ~, N, A] = bwboundaries(BW);

    hP = gobjects(N, 1);

    % Loop through object boundaries (Example from bwboundaries doc)
    for k = 1:N

        [xDataOuter, yDataOuter] = getBoundary(B{k}, imSize, options);
        if numel(xDataOuter) < 20; continue; end

        xData = xDataOuter; yData = yDataOuter;

        % Boundary k is the parent of a hole if the k-th column
        % of the adjacency matrix A contains a non-zero element
        if (nnz(A(:,k)) > 0)
            % Loop through the children of boundary k
            for l = find(A(:,k))'
                [xDataInner, yDataInner] = getBoundary(B{l}, imSize, options);
                if isempty(xDataInner); continue; end

                % Have to insert to inner boundary so that it starts and
                % stops where the outer boundary starts and stops.
                distance = sqrt( (xDataInner(1)-xDataOuter).^2 + ...
                                 (yDataInner(1)-yDataOuter).^2 );

                [~, insertPoint] = min(distance);

                insertInd = find( xData == xDataOuter(insertPoint) );
                insertInd = insertInd(1);
                xData = cat(1, xData(1:insertInd), xDataInner, xData(insertInd:end));
                yData = cat(1, yData(1:insertInd), yDataInner, yData(insertInd:end));
            end
        end

        hP(k) = patch(hAxes, xData, yData, 'k');
    end

    keep = arrayfun(@(h) ~isa(h, 'matlab.graphics.GraphicsPlaceholder'), hP);
    hP = hP(keep);

    set(hP, 'EdgeColor', 'none')
end

function hP = plotObjectsAsPolygons(hAxes, BW, options)
%plotObjectsAsPolygons Plot binary objects as polygons
    % Get size of image
    [imHeight, imWidth] = size(BW);

    % Get boundaries of binary objects
    CC = bwboundaries(BW);

    % Turn off warning that sometimes occurs for polyshapes..
    warning('off', 'MATLAB:polyshape:repairedBySimplify')

    %% Plot image/objects using polygon
    for i = 1:numel(CC)
        data = CC{i};

        if numel(data) < 20; continue; end

        % Center coordinates
        y = data(:,1) - imHeight/2; x = data(:,2) - imWidth/2;

        for j = 1:options.SmoothIter
            y = uim.utility.circularSmooth(y, options.SmoothWindow, 'movmean');
            x = uim.utility.circularSmooth(x, options.SmoothWindow, 'movmean');
        end

        if i == 1 || ~exist('pgon', 'var')
            pgon = polyshape(x, y);
        else
            pgon = pgon.addboundary(x, y);
        end
    end

    warning('on', 'MATLAB:polyshape:repairedBySimplify')

    hP = plot(hAxes, pgon, 'FaceColor', 'k', 'FaceAlpha', 1, 'EdgeColor', 'none');
end

function [xData, yData] = getBoundary(B, imSize, options)

    [xData, yData] = deal([]);

    B(end+1, :) = B(1, :);
    if numel(B) < 40; return; end

    xData = B(:,2) - imSize(2)/2;
    yData = B(:,1) - imSize(1)/2;

    for j = 1:options.SmoothIter
        yData = uim.utility.circularSmooth(yData, options.SmoothWindow, 'movmean');
        xData = uim.utility.circularSmooth(xData, options.SmoothWindow, 'movmean');
    end

    xData(end+1) = xData(1);
    yData(end+1) = yData(1);
end
