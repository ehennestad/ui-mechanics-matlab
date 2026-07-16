classdef TiledImageAxes < uim.Handle
%TiledImageAxes Class for creating image tiles in an axes
%
%   Create an axes with a grid of tiles, where each tile can hold an image,
%   a line/patch and a text object. Additionally tiles can be selected
%   and it is possible to add custom callback functions to the action of
%   selecting a tile.
%
%   This class will function like a virtual subplot in the sense that you
%   can plot into multiple small subplots whereas the actual axes object is
%   one "matlab.graphics.axis.Axes" object. This means that the class is
%   much less flexible than having a figure with real subplots, but on the
%   other hand it can provide a powerful engine for plotting e.g. 100s of
%   images in a montage/mosaic, with added functionality like plotting
%   something on top and adding textlabels. And as stated before, tiles can
%   be selected and trigger custom callback functions.
%
%   Making a figure with 10s to hundreds of subplots in a figure, would
%   update much slower than what is possible with this class.
%
%
%   Examples:
%       See mclassifier.manualClassifier &
%       imviewer.widgets.ThumbnailSelector for practical examples.

% Todo:
%   [ ] Make TileCallbackFcn a property and invoke it internally whenever a
%       tile is selected. Define eventdata that has the tile number as a
%       property.

% "Persistent settings" Consider if it should be configurable for objects.
properties (Constant = true)
    PlotOrder = 'rowwise'       % rowwise | columnwise
end

properties % Properties to configure axes layout (Default values are preset)
    GridSize = [3, 5]           % [nRows, nCols]
    ImageSize = [128, 128]      % [imHeight, imWidth] Size (Reso) in px per tile
    Padding = 10                % Number of pixels between each tile. Todo: Rename to spacing. Note: not in use
    NumChannels = 1;            % Number of color channels.

    NormalizedPadding = 0.012;  % Padding between tiles in normalized units.
    TileUnits = 'pixel'         % pixel | scaled. scaled units will set axes coordinates in a scaled unit vis a vis pixels.

    Visible = 'on'
end

properties % Properties for configuration of appearance

    TileConfiguration = struct('DefaultTileColor', ones(1,3)*0.7, ...
                               'SelectedTileColor', ones(1,3)*0.5, ...
                               'DefaultColorMap', 'parula', ...
                               'TextColor', ones(1,3)*0.8, ...
                               'SelectedTileAlpha', 0.4)

    HighlightTileOnMouseOver = false
    TileCallbackFcn
end

properties (SetAccess = protected) % Properties for public access
    SelectedTiles  % Number of tiles that are selected
    AxesRange      % Store the range of axes limits for quick retrieval ([x,y])
end

properties (Dependent = true) % General info about class objects
    Figure
    Axes
    NumTiles
    NumRows
    NumColumns
    Position
end

% Properties that are used internally
properties (Access = private, Hidden)
    TileCorners
    TileCenters
    TileIndices
    TileIndexMap

    ImageSize_ = [128, 128]     % Original size of images that are plotted. % Todo. Set this on construction?
    ScaleFactor = [1, 1]        % Internal scalefactor (convert pixel to coord)

    TilePixelSize
    TileLineWidth = 2

    AxesPositionChangedListener

    IsConstructed = false
end

% Dependent properties that are used internally
properties (Dependent = true, Access = private)
    PixelWidth          % Number of pixels in x for the whole mosaic image
    PixelHeight         % Number of pixels in y for the whole mosaic image
    PixelPadding        % Number of pixels for padding between tiles.
end

% Properties to store for graphical handles
properties (Access = private, Hidden)
    Parent
    Figure_
    Axes_
    Image

    TileText            % Handle for text object belonging to a tile
    TilePlot            % Handle for line/patch object belonging to a tile

    TileOutline         % Handle for tile outline

    Debug = false
end

methods %Structors

    % % Constructor
    function obj = TiledImageAxes(varargin)
    %TiledImageAxes Create and configure the TiledImageAxes object
    %
    %   TiledImageAxes Creates a tiled image axes in a new figure.
    %
    %   TiledImageAxes(parent) Creates a tiled images axes in an existing
    %   figure or uipanel.
    %
    %   TiledImageAxes(..., Name, Value) creates a tiled images given
    %   additional parameters.
    %
    %   Parameters:
    %       GridSize            : size of grid with tiles [nRows, nCols]
    %       ImageSize           : nPixels for image in each tile [h, w]
    %       Padding             : nPixels of padding between tiles (int) -- Not scale invariant :(
    %       TileConfiguration   : 'rowwise' (default) | 'columnwise'

        isFigCreated = false;
        if nargin == 0
            createFigure(obj)

        elseif ~isa(varargin{1}, 'matlab.ui.Figure') && ...
                    ~isa(varargin{1}, 'matlab.ui.container.Panel') && ...
                         ~isa(varargin{1}, 'matlab.ui.container.Tab')

            createFigure(obj)
            isFigCreated = true;
        else
            parent = varargin{1};
            varargin = varargin(2:end);

            obj.Figure_ = ancestor(parent, 'figure');
            obj.Parent = parent;
        end

        if nargin > 0 && ~isempty(varargin)
            obj.parseVarargin(varargin)
        end

        createAxes(obj)

        % Initialize grid.
        % The changeGridSize method also takes care of the initialization
        obj.updateScaleFactor()
        obj.changeGridSize()

        if isFigCreated; obj.fitFigure; end
        obj.IsConstructed = true;

        if ~nargout
            clear obj
        end
    end

    % % Destructor
    function delete(obj)
        if isvalid(obj.Axes_)
            delete(obj.Axes_)
        end
    end
end

methods (Access = private) % Methods for setting up gui

    function parseVarargin(obj, cellOfVarargin)

        fields = {'ImageSize', 'GridSize', 'Padding', 'TileConfiguration', ...
            'NumChannels', 'NormalizedPadding', 'TileUnits', 'Visible' };

        assert(mod(numel(cellOfVarargin), 2) == 0, ...
            'Inputs must be supplied as name-value pairs.')

        for i = 1:2:numel(cellOfVarargin)
            inputName = cellOfVarargin{i};
            if isstring(inputName) && isscalar(inputName)
                inputName = char(inputName);
            end

            match = strcmpi(fields, inputName);
            if any(match)
                obj.(fields{match}) = cellOfVarargin{i+1};
            end
        end
    end

    function createFigure(obj)

        % Create figure:
        obj.Figure_ = figure('Visible', obj.Visible);
        obj.Figure_.MenuBar = 'none';
        obj.Figure_.KeyPressFcn = @obj.keypress;

        obj.Parent = obj.Figure_;
    end

    function createAxes(obj)
    %createAxes Create the axes for plotting tiles in

        obj.Axes_ = axes(obj.Parent);
        obj.Axes_.Position = [0.02,0.02,0.96,0.96];
        hold(obj.Axes_, 'on')

        % Make sure axes is not visible
        set(obj.Axes_, 'xTick', [], 'YTick', []);
        obj.Axes_.XAxis.Visible = 'off';
        obj.Axes_.YAxis.Visible = 'off';
        obj.Axes_.Visible = 'off';

        % Since axes will hold image data, the yaxis is reversed.
        obj.Axes_.YDir = 'reverse';

        uim.utility.disableAxesInteractivity(obj.Axes_)

        % Set colormap
        colormap(obj.Axes_, obj.TileConfiguration.DefaultColorMap)

        % Add a listener for axes position changes, which will require
        % internal updates.
        el = addlistener(obj.Axes_, 'Position', 'PostSet', ...
            @(s,e) obj.onAxesPositionChanged);
        obj.AxesPositionChangedListener = el;

        if obj.Debug
            obj.showAxesGrid()
        end
    end

    function showAxesGrid(obj)
    %showAxesGrid Show XGrid of axes (for debugging)

        obj.Axes.Visible = 'on';
        obj.Axes.XAxis.Visible = 'on';

        obj.Axes.XAxis.Color = 'r';%ones(1,3).*0.5;%'r';
        obj.Axes.XAxis.TickDirection = 'out';

        obj.Axes.XMinorTick = 'on';

        obj.Axes.XGrid = 'on';
        obj.Axes.XMinorGrid = 'on';
        obj.Axes.GridAlpha = 0.5;
        obj.Axes.MinorGridAlpha = 0.25;
        obj.Axes.MinorGridLineStyle = '--';

        obj.Axes.Layer = 'top';
    end

    function updateAxesLimits(obj)
    %updateAxesLimits % Update axes limits based on grid configuration

        if isempty(obj.Axes_); return; end % Skip during initialization

        numOriginalPixelsX = obj.PixelWidth ./ obj.ScaleFactor(1);
        numOriginalPixelsY = obj.PixelHeight ./ obj.ScaleFactor(2);

        % Set x- and y- limits according to the size of the original
        % (unscaled) image data (in pixel coordinates).
        obj.Axes_.XLim = ([0, numOriginalPixelsX] + 0.5 );
        obj.Axes_.YLim = ([0, numOriginalPixelsY] + 0.5 );
        obj.Axes_.XTick = obj.Axes_.XLim(1):5:obj.Axes_.XLim(2);

        % Place image data so that it fills the axes limits. This way, the
        % coordinates of the original data is kept.
        if ~isempty(obj.Image)
            pixelSize = 1 ./ obj.ScaleFactor;

            % Find positions where to place corner pixels of image in order
            % to fill out the x-limits and y-limits. Should be offset from
            % the limits by half a pixel size (scaled pixel units).
            xA = obj.Axes_.XLim(1) + pixelSize(1)/2;
            xB = obj.Axes_.XLim(2) - pixelSize(1)/2;

            yA = obj.Axes_.YLim(1) + pixelSize(2)/2;
            yB = obj.Axes_.YLim(2) - pixelSize(2)/2;

            obj.Image.XData = [xA, xB] ;
            obj.Image.YData = [yA, yB];
        end

        % Update axesRange property.
        obj.AxesRange = [uim.utility.range(obj.Axes_.XLim), uim.utility.range(obj.Axes_.YLim)];
    end

    function configurePointerBehavior(obj)
    %configurePointerBehavior Configure behavior if mouse moves over a tile

        if isempty(obj.TileOutline); return; end

        if obj.HighlightTileOnMouseOver  % Add callback functions
            pointerBehavior = struct('enterFcn', [], 'exitFcn', [], 'traverseFcn', []);

            for i = 1:numel(obj.TileOutline)
                pointerBehavior.enterFcn    = @(s,e,num)obj.onMouseEnteredTile(i);
                pointerBehavior.exitFcn     = @(s,e,num)obj.onMouseExitedTile(i);

                uim.utility.setPointerBehavior(obj.TileOutline(i), pointerBehavior)
            end

        else % Reset
            for i = 1:numel(obj.TileOutline)
                uim.utility.setPointerBehavior(obj.TileOutline(i), [])
            end
        end
    end

    function updateGraphicsObjects(obj)
    %updateGraphicsObjects Create/update handles & positions of gobjects
    %
    %   Initializes and updates all handles that are used for plotting in
    %   tiles. Creates CData of the image object which will contain image
    %   data for all the plotted tiles, as well as boxes around each tiles
    %   and handles for adding lines or text to the interior of each tile.
    %
    %   NOTE! This function will reset any tilecallback functions that are
    %   assigned externally. % Todo: Should fix this...

        if isempty(obj.Axes_); return; end % Skip during initialization

        % Initialize empty image data.
        imdata = zeros(obj.PixelHeight, obj.PixelWidth, obj.NumChannels, 'uint8');

        % % Initialize/Update image object.
        if isempty(obj.Image)
            obj.Image = image(imdata, 'Parent', obj.Axes_);
            obj.Image.Visible = obj.Visible;
            obj.updateAxesLimits()

            % Add context menu to image.
            obj.Image.UIContextMenu = uicontextmenu(obj.Figure_);
            uim.menu.createColormapList(obj.Image.UIContextMenu, obj.Axes_)
        else
            obj.Image.CData = imdata;
        end

        obj.Image.AlphaData = zeros(obj.PixelHeight, obj.PixelWidth);

        % Set alphadata for all tile indices to 1. Effect: invisible
        % padding/spacing
        ind = cat(3, obj.TileIndices{:});
        obj.Image.AlphaData(ind(:)) = 1;

        % % Initialize/update tile outline
        if isempty(obj.TileOutline)
            obj.TileOutline = obj.initializePlotHandles('patch', obj.NumTiles);
        else
            obj.TileOutline = obj.updateNumHandles(obj.TileOutline, obj.NumTiles);
        end

        % Set some properties on the tile outline handles.
        set(obj.TileOutline, 'EdgeColor', ones(1,3)*0.7);
        set(obj.TileOutline, 'FaceAlpha', 0.05);
        set(obj.TileOutline, 'LineWidth', obj.TileLineWidth);
        set(obj.TileOutline, 'Clipping', 'off')

        tileTags = arrayfun(@(i) num2str(i), 1:obj.NumTiles, 'uni', 0);
        set(obj.TileOutline, {'Tag'}, tileTags')

        % Set pointer behavior.
        if obj.HighlightTileOnMouseOver
            obj.configurePointerBehavior()
        end

        % Create coordinates (xdata/ydata) for the outline of each tile.
        fullSize = [obj.PixelHeight, obj.PixelWidth];
        [xData, yData] = deal(cell(numel(obj.TileIndices), 1));

        for i = 1:numel(obj.TileIndices)

            upperLeft = obj.TileIndices{i}(1);
            [y0, x0] = ind2sub(fullSize, upperLeft);

            pixelSize = 1 ./ obj.ScaleFactor;
            %x0 = x0 - pixelSize(1)/2;
            %y0 = y0 - pixelSize(2)/2;

            bbox = [x0, y0, obj.ImageSize(2), obj.ImageSize(1)];
            bbox = bbox ./ repmat(obj.ScaleFactor, 1, 2);
            bbox(1:2) = bbox(1:2) - pixelSize/2;

            coords = obj.bbox2points(bbox) ;
            coords = coords + (obj.ScaleFactor-1).*pixelSize/2; % dont understand this...

            % Calculate and update position
            xData{i} = coords(:, 1);
            yData{i} = coords(:, 2);

            % Set additional props while looping to create xdata/ydata
            obj.TileOutline(i).ButtonDownFcn = {@obj.selectTile, i};
            setappdata(obj.TileOutline(i), 'OrigColor', ones(1,3)*0.7)
        end

        set(obj.TileOutline, {'XData'}, xData, {'YData'}, yData)
        set(obj.TileOutline, 'LineWidth', 3)

        % % Initialize/update text and plot handles

        if isempty(obj.TileText)
            obj.TileText = obj.initializePlotHandles('text', obj.NumTiles);
        else
            obj.TileText = obj.updateNumHandles(obj.TileText, obj.NumTiles);
        end

        if isempty(obj.TilePlot)
            obj.TilePlot = obj.initializePlotHandles('patch', obj.NumTiles);
        else
            obj.TilePlot = obj.updateNumHandles(obj.TilePlot, obj.NumTiles);
        end

        set(obj.TileText, 'Tag', 'TileTextHandle')
        set(obj.TilePlot, 'Tag', 'TilePlotHandle')

        % Update position of text based on gridsize and tile positions
        pixOffset = round(obj.ImageSize(1).*0.05);
        newPos = arrayfun(@(i) [obj.TileCorners(i,:) + pixOffset, 0] ./ ...
                            [obj.ScaleFactor, 1], 1:obj.NumTiles, 'uni', 0);
        set(obj.TileText, {'Position'}, newPos')

        % Reset plot data
        set(obj.TilePlot, 'XData', nan, 'YData', nan)
    end

    function setTileIndices(obj)
    %setTileIndices Create indices for referencing data in tiles
    %
    %   This method is used for setting up an interface for easily updating
    %   data within individual tiles.
    %
    %   The following properties are set:
    %
    %       tileIndices  : Cell array of linear indices for each pixel in a
    %                      tile. Size is nRows x nCols
    %       tileCorners  : Matrix with x- and y- pixel coordinates for each
    %                      tile's corner. Size is nTiles x 2 (x = 1st col,
    %                      y = 2nd col)
    %       tileCenters  : Not implemented here.
    %       tileIndexMap : A matrix with same size as the image object's
    %                      CData. The value of each element is the tile
    %                      number corresponding to the pixel at that
    %                      position. Pixels between tiles are set to NaN

        % Pixel coordinate for the position of rows and columns
        x0 = ((1:obj.NumColumns)-1) .* (obj.ImageSize(2)+obj.PixelPadding) + 1;
        y0 = ((1:obj.NumRows)-1) .* (obj.ImageSize(1)+obj.PixelPadding) + 1;

        % Pixel coordinates for all pixels that are within rows/columns
        X = arrayfun(@(x) (x-1) + (1:obj.ImageSize(2)), x0, 'uni', 0);
        Y = arrayfun(@(y) (y-1) + (1:obj.ImageSize(1)), y0, 'uni', 0);

        % Determine the ordering of tiles based on the plotOrder property
        tileOrder = 1:obj.NumRows*obj.NumColumns;
        switch obj.PlotOrder
            case 'columnwise'
                tileOrder = reshape(tileOrder, obj.NumRows, obj.NumColumns);
            case 'rowwise'
                tileOrder = reshape(tileOrder, obj.NumColumns, obj.NumRows)';
        end

        % Flip upside down because image coordinates are flipped.
%             tileOrder = flipud(tileOrder); I dont remember why this was
%             commented out, but probably for a good reason.

        % Allocate property values.
        obj.TileIndices = cell(size(tileOrder));
        obj.TileCorners = zeros(numel(tileOrder), 2);
        fullSize = [obj.PixelHeight, obj.PixelWidth];
        obj.TileIndexMap = nan(fullSize);

        % Assign the values. This is done so that tileIndices are assigned
        % in either a row- or a column-based manner.
        for j = 1:size(tileOrder,1)
            for i = 1:size(tileOrder,2)
                [ii, jj] = meshgrid(X{i}, Y{j});
                obj.TileIndices{tileOrder(j,i)} = sub2ind(fullSize, jj, ii);
                obj.TileCorners(tileOrder(j,i), :) = [X{i}(1), Y{j}(1)];

                tileNum = tileOrder(j,i);
                obj.TileIndexMap(Y{j}, X{i}) = tileNum;
            end
        end
    end

    function h = initializePlotHandles(obj, hClass, n)
    %initializePlotHandles Create plot handles based on a class
    %
    %   This method is used for initializing plot handles on startup and
    %   creating more plot handles on request when the number of tiles
    %   change due to changes to grid-size.
    %
    %   Currently supports text, line and patches.

        switch hClass

            case {'text', 'matlab.graphics.primitive.Text'}

                h = text(ones(1,n), ones(1,n), '');
                set(h, 'Parent', obj.Axes_)
                set(h, 'Color', obj.TileConfiguration.TextColor)
                set(h, 'FontSize', 12)
                set(h, 'VerticalAlignment', 'top')
                set(h, 'HitTest', 'off', 'PickableParts', 'none')
                set(h, 'Clipping', 'on')

            case {'line', 'matlab.graphics.chart.primitive.Line'}

                h = plot(nan(2,n), nan(2,n));
                set(h, 'Parent', obj.Axes_)

            case {'patch', 'matlab.graphics.primitive.Patch'}
                h = arrayfun(@(i) patch(obj.Axes_, nan, nan, 'w'), 1:n);
                %set(h, 'Parent', obj.Axes_)
                set(h, 'FaceAlpha', 0.01, 'LineWidth', 1, 'EdgeColor', 'w')
        end

        set(h, 'Visible', obj.Visible)
    end

    function handles = updateNumHandles(obj, handles, n)
    %updateNumHandles Update number of handles if gridsize changes
    %
    %   handles = updateNumHandles(obj, handles, n) updates the handles
    %   vector to contains n elements, either through adding or removing
    %   handles

        if numel(handles) < n
            hClass = class(handles);
            newHandles = obj.initializePlotHandles(hClass, n-numel(handles));
            handles((numel(handles)+1):n) = newHandles;

        elseif numel(handles) > n
            delete( handles((n+1):end) )
            handles((n+1):end) = [];
        else
            return
        end
    end

    function changeGridSize(obj)
    %changeGridSize Take care of updates required when grid size is changed

        if isempty(obj.Axes_); return; end % Skip during initialization

        % Todo: Update padding size based on pixel resolution.
        obj.updateAxesLimits()

        obj.setTileIndices()
        obj.updateGraphicsObjects()

        obj.updateTileLineWidth()
    end

    function updateTileLineWidth(obj)
    %updateTileLineWidth Update linewidth of outline based on tile's size
    %
    %   Set the line with for the tile's outline based on its "physical",
    %   i.e pixel size.

        axesPixelPosition = getpixelposition(obj.Axes);
        obj.TilePixelSize = axesPixelPosition(3:4) ./ fliplr(obj.GridSize);
        obj.TileLineWidth = min([3, ceil( mean(obj.TilePixelSize) / 50 )]);
    end

    function makeFigureTight(obj)
    %makeFigureTight Set position of figure to wrap tightly around axes.

        obj.fitAxes()

        axesPixelPosition = getpixelposition(obj.Axes_);
        figPixelPosition = axesPixelPosition(3:4) + 2*axesPixelPosition(1:2);

        obj.Figure_.Position(3:4) = figPixelPosition;
    end
end

methods

    function tileNum = hittest(obj, x, y)

        if nargin < 3
            mousePoint = obj.Axes.CurrentPoint(1,2);
            mousePoint = round(mousePoint);
            x = mousePoint(1); y = mousePoint(2);
        end

        x = round(x .* obj.ScaleFactor(1));
        y = round(y .* obj.ScaleFactor(2));

        if x >= 1 && x <= obj.PixelWidth && y >= 1 && y <= obj.PixelHeight
            tileNum = obj.TileIndexMap(y, x);
        else
            tileNum = nan;
        end
    end

% % Methods to get dependent properties

    function position = get.Position(obj)
        position = obj.Axes_.Position;
    end
    function set.Position(obj, newPosition)
        obj.Axes_.Position = newPosition;
    end

    function numRows = get.NumRows(obj)
        numRows = obj.GridSize(1);
    end

    function numColumns = get.NumColumns(obj)
        numColumns = obj.GridSize(2);
    end

    function pixelWidth = get.PixelWidth(obj)
%         pixelWidth = obj.NumColumns .* obj.ImageSize(2) + ...
%                             (obj.NumColumns-1) .* obj.Padding;

        pixelWidth = obj.NumColumns .* obj.ImageSize(2);
        pixelWidth = pixelWidth + obj.PixelPadding .* (obj.NumColumns-1);
    end

    function pixelHeight = get.PixelHeight(obj)
%          pixelHeight = obj.NumRows .* obj.ImageSize(1) + ...
%                             (obj.NumRows-1) .* obj.Padding;

        pixelHeight = obj.NumRows .* obj.ImageSize(1);
        pixelHeight = pixelHeight + obj.PixelPadding .* (obj.NumRows-1);
    end

    function pixelPadding = get.PixelPadding(obj)
        pixelPadding = round(obj.NumRows .* obj.ImageSize(1) .* obj.NormalizedPadding);
    end

    function numTiles = get.NumTiles(obj)
        numTiles = numel(obj.TileIndices);
    end

    function hAx = get.Axes(obj)
        hAx = obj.Axes_;
    end

    function hFig = get.Figure(obj)
        hFig = obj.Figure_;
    end

    function setOriginalImageSize(obj, imageSize)
        % Quick fix. Not quite sure if this is actually the original image
        % size. Was needed to get the scalefactor correct, because the
        % hardcoded default value ([128,128]) of imageSize_ is not always
        % applicable. Todo: Clean this up
        obj.ImageSize_ = imageSize;
        obj.updateScaleFactor()
    end

    function pos = getTileOffset(obj, tileNum)

        %Position of tile center.

        fullSize = [obj.PixelHeight, obj.PixelWidth];

        [y, x] = ind2sub(fullSize, obj.TileIndices{tileNum} );
        tileCenter = [mean(x(:)), mean(y(:))];

        pos = tileCenter;
    end

    function pixelpos = getpixelposition(obj)
        pixelpos = getpixelposition(obj.Axes);
    end

    function pos = getTileCenter(obj, tileNum)

        %Position of tile center.

        fullSize = [obj.PixelHeight, obj.PixelWidth];

        [y, x] = ind2sub(fullSize, obj.TileIndices{tileNum} );
        tileCenter = [mean(x(:)), mean(y(:))];

        pos = tileCenter ./ obj.ScaleFactor;
    end

    function pos = getTileCenterAxesCoords(obj, tileNum)

        %Position of tile center.

        pad = obj.PixelPadding ./ obj.ScaleFactor;
        origImSize = obj.ImageSize ./ obj.ScaleFactor;

        iRow = ceil( tileNum / obj.NumColumns );
        iCol = mod(tileNum-1, obj.NumColumns)+1;

        pos = zeros(1,2);
        pos(1) = origImSize(2)*(iCol-1) + pad(1)*(iCol-1) + origImSize(2)/2;
        pos(2) = origImSize(1)*(iRow-1) + pad(2)*(iRow-1) + origImSize(1)/2;

        pos = pos + 0.5;
    end

% % Methods to set properties
    function set.GridSize(obj, gridSize)

        validateattributes(gridSize, {'numeric'}, {'numel', 2})

        if any(obj.GridSize ~= gridSize)
            obj.GridSize = gridSize;
            obj.changeGridSize()
        end
    end

    function set.ImageSize(obj, imageSize)
        validateattributes(imageSize, {'numeric'}, {'numel', 2})

        obj.ImageSize = imageSize;
        obj.updateScaleFactor()
        obj.changeGridSize()
    end

    function set.TileUnits(obj, newValue)

        validatestring(newValue, {'pixel', 'scaled'});

        obj.TileUnits = newValue;
        obj.updateScaleFactor()
    end

    function set.Visible(obj, newValue)
        validatestring(newValue, {'on', 'off'});
        obj.Visible = newValue;

        obj.onVisibleChanged()
    end

    function set.TileLineWidth(obj, newValue)
        obj.TileLineWidth = newValue;
        obj.onTileStyleChanged()
    end

    function set.HighlightTileOnMouseOver(obj, newValue)
        assert(isa(newValue, 'logical'), 'Property Value must be true or false')

        obj.HighlightTileOnMouseOver = newValue;
        obj.configurePointerBehavior()
    end

% % %     function set.TileConfiguration(obj, newConfig)
% % %
% % %     end

    function fitAxes(obj)
    %fitAxes Todo: Rename, and make sure it does not exceed screen size...

        fullSize = [obj.PixelWidth, obj.PixelHeight];

        % Set position of axes to the same as the full size of the
        % imagedata.

        axUnits = obj.Axes_.Units;
        obj.Axes_.Units = 'pixel';
        obj.Axes_.Position(3:4) = fullSize;
        obj.Axes_.Units = axUnits;
    end

% % Reset imagedata, e.g before an update
    function resetAxes(obj)
    %resetAxes Reset children of axes. Useful before running updates.
        obj.Image.CData(:) = 255;
        set(obj.TilePlot, 'XData', nan, 'YData', nan)
        set(obj.TileText, 'String', '')
    end

    function resetTile(obj, tileNum)
    %resetTile Reset graphic data in tiles given by tileNum
    %
    %   tileNum can be a vector or tileNumbers.

        % Todo: Avoid looping
        for i = tileNum
            obj.setTileOutlineColor(i)
            obj.removeTileImage(i)
        end

        set(obj.TilePlot(tileNum), 'XData', nan, 'YData', nan)
        set(obj.TileText(tileNum), 'String', '')
    end

% % Update image or plot data within a tile.

    function updateTileImage(obj, imdata, tileNum)
    %updateTileImage Update image data in given tile(s)

        [h, w, ~] = size(imdata);

        % Update imageSize_ property and scaleFactor.
        if ~isequal([h, w], obj.ImageSize)
            imdata = imresize(imdata, obj.ImageSize);
            obj.ImageSize_ = [h, w];
            obj.updateScaleFactor()

            %obj.Axes_.XLim = ([0, numOriginalPixelsX] + 0.5 );
            %obj.Axes_.YLim = ([0, numOriginalPixelsY] + 0.5 );
        end

        % Update image data for the specified tiles.
        if obj.NumChannels == 1
            obj.Image.CData([obj.TileIndices{tileNum}]) = imdata;
        else
            for i = 1:obj.NumChannels
                tmpIm = obj.Image.CData(:, :, i);
                tmpIm( [obj.TileIndices{tileNum}] ) = imdata(:, :, i, :);
                obj.Image.CData(:, :, i) = tmpIm;
            end
        end
        obj.Image.AlphaData([obj.TileIndices{tileNum}]) = 1;
    end

    function removeTileImage(obj, tileNum)

        if obj.NumChannels == 1
            obj.Image.CData([obj.TileIndices{tileNum}]) = 0;
        else
            for i = 1:obj.NumChannels
                tmpIm = obj.Image.CData(:, :, i);
                tmpIm( [obj.TileIndices{tileNum}] ) = 0;
                obj.Image.CData(:, :, i) = tmpIm;
            end
        end

        obj.Image.AlphaData([obj.TileIndices{tileNum}]) = 0;
    end

    function updateTileText(obj, textString, tileNum, varargin)
    %updateTileText Update displayed text in given tile(s)
    %
    %   Input: textString : string or cell array of strings.

        if isa(textString, 'cell') && isrow(textString)
            textString = textString';
        end

        if isa(textString, 'char'); textString = {textString}; end

        set(obj.TileText(tileNum), {'String'}, textString);

        if ~isempty(varargin)
            set(obj.TileText(tileNum), varargin{:})
        end
    end

    function updateTilePlot(obj, xData, yData, tileNum)
    %updateTilePlot Update displayed plot in given tile(s)
    %
    %   Input:  xData : vector or cell array of vectors.
    %           yData : vector or cell array of vectors.

        % Shift plot coordinates to center of current tile
        fullSize = [obj.PixelHeight, obj.PixelWidth];

        for i = 1:numel(tileNum)
            [y, x] = ind2sub(fullSize, obj.TileIndices{tileNum(i)} );
            x = x ./ obj.ScaleFactor(1);
            y = y ./ obj.ScaleFactor(2);
            tileCenter = obj.getTileCenterAxesCoords( tileNum(i) );

            % Calculate and update position
            xData{i} = xData{i} + tileCenter(1);
            yData{i} = yData{i} + tileCenter(2);

            % Set movement limits.... Should that be done in caller?
            obj.TilePlot(tileNum(i)).UserData.XLim = [min(x(:)), max(x(:))];
            obj.TilePlot(tileNum(i)).UserData.YLim = [min(y(:)), max(y(:))];
        end

        % Update plot data
        if isrow(tileNum); tileNum = tileNum'; end
        if isrow(xData); xData = xData'; end
        if isrow(yData); yData = yData'; end

        set(obj.TilePlot(tileNum), {'XData'}, xData, {'YData'}, yData)
    end

    function updateTilePlotLinewidth(obj, tileNum, lineWidth)
        set(obj.TilePlot(tileNum), 'LineWidth', lineWidth')
    end

    % TODO: Rename these methods to setCallbacks
    function tileCallbackFcn(obj, funHandle, tileNum)
    %tileCallbackFcn Add a callback to mouse press within given tile.
        obj.TileOutline(tileNum).ButtonDownFcn = funHandle;
    end

    function tilePlotButtonDownFcn(obj, funHandle, tileNum)
        obj.TilePlot(tileNum).ButtonDownFcn = funHandle;
    end

    % % % Keypress callback

    function keypress(obj, ~, event)

        switch event.Key
            case 'return'
                if isfield( obj.Figure_.UserData, 'uiwait') && obj.Figure_.UserData.uiwait
                    uiresume(obj.Figure_)
                    obj.Figure_.UserData.uiwait = false;
                    obj.Figure_.UserData.lastKey = event.Key;
                end
            case 'escape'
                if isfield( obj.Figure_.UserData, 'uiwait') && obj.Figure_.UserData.uiwait
                    uiresume(obj.Figure_)
                    obj.Figure_.UserData.uiwait = false;
                end
        end
    end

    function ind = uiwait(obj)
    %uiwait Implements uiwait on the gui figure and returns selected tile ind

    % Dont remember what this is used for.

        obj.Figure_.UserData.uiwait = true;
        uiwait(obj.Figure_)

        if isvalid(obj.Figure_)

            switch obj.Figure_.UserData.lastKey
                case 'return'
                    uiresume(obj.Figure_)
                    ind = obj.SelectedTiles;
                    close(obj.Figure_)
                case 'escape'
                    uiresume(obj.Figure_)
                    ind = nan;
                    close(obj.Figure_)
            end
        else
            ind = nan;
        end
    end

    % % % User callbacks

    function selectTile(obj, ~, ~, tileNum)
    %selectTile Select tile on mousepress and change its color.

        % Todo: toggle select/unselect

        color = obj.TileConfiguration.SelectedTileColor;

        if ~isequal(obj.SelectedTiles, tileNum) && ~isempty(obj.SelectedTiles)
            setTileOutlineColor(obj, obj.SelectedTiles)
        end

        obj.SelectedTiles = tileNum;
        if isempty(obj.SelectedTiles); return; end

        setTileOutlineColor(obj, obj.SelectedTiles, color)

        if ~isempty(obj.TileCallbackFcn)
            obj.TileCallbackFcn([], [], tileNum)
        end
    end

    function setTileOutlineColor(obj, tileNum, color)
    %setTileOutlineColor Set color of tile outline

    % NB: Only works for one tile at a time.
    % Todo: Adapt to work for more than one tile.
        tmpH = obj.TileOutline(tileNum);

        % Default color / no coloring of tile
        if nargin < 3 || isempty(color)
            tmpH.EdgeColor = obj.TileConfiguration.DefaultTileColor;
            tmpH.FaceAlpha = 0.05;
            tmpH.FaceColor = tmpH.EdgeColor;
            setappdata(tmpH, 'OrigColor',  obj.TileConfiguration.DefaultTileColor);

        % Custom color, tile is also colored.
        else
            tmpH.EdgeColor = color;
            tmpH.FaceAlpha = max([0.01, obj.TileConfiguration.SelectedTileAlpha]); % Avoid setting to 0
            tmpH.FaceColor = color;
            setappdata(tmpH, 'OrigColor', color);
        end
    end

    function setTextColor(obj, newColor)
        obj.TileConfiguration.TextColor = newColor;
        set(obj.TileText, 'Color', newColor)
    end

    function setPlotVisibility(obj, mode)
        set(obj.TilePlot, 'Visible', mode)
    end

    function setTileTransparency(obj, tileNum, alphaLevel)
        set(obj.TileOutline(tileNum), 'FaceAlpha', alphaLevel)
    end
end

methods (Access = private) % Internal gui management

    function updateScaleFactor(obj)
    %updateScaleFactor Update internal scalefactor mapping pixels to coords
    %
    %   Tiled images are resized to fit the resolution of a tile. This is
    %   practical for internal updates, and it was the way the interface
    %   was originally constructed. However, this setup can create problems
    %   when other interfaces are dependent on a specific coordinate system.
    %   To keep backwards compatibility, pixel units and are used by
    %   default, but scaled units can be optionally used. This methods
    %   updates the internal scalefactor.

        switch obj.TileUnits
            case 'scaled'
                newScaleFactor = obj.ImageSize ./ obj.ImageSize_;
            case 'pixel'
                newScaleFactor = [1, 1];
        end

        % This is a trainwreck solution. Calling change grid size will call
        % updateGraphicsObjects which will reset any tileCallback assigned
        % from external interface. Need to fix. BIG Todo!
        if any(obj.ScaleFactor ~= newScaleFactor)
            obj.ScaleFactor = newScaleFactor;
            % Todo: Change this. Dont need to change the whole grid, just axes
            % limits and update graphics object
            obj.changeGridSize()
        end
    end

    function onVisibleChanged(obj)

        if ~obj.IsConstructed; return; end

        set(obj.Image, 'Visible', obj.Visible);
        set(obj.TileOutline, 'Visible', obj.Visible);
        set(obj.TilePlot, 'Visible', obj.Visible);
        set(obj.TileText, 'Visible', obj.Visible);
    end

    function onTileStyleChanged(obj)
        if ~isempty(obj.TileOutline)
            set(obj.TileOutline, 'LineWidth', obj.TileLineWidth)
            %set(obj.TileOutline, 'LineWidth', 1); % Todo: remove
        end
    end

    function onAxesPositionChanged(obj)
        obj.updateTileLineWidth()
    end

    function onMouseEnteredTile(obj, tileNum)
        tileColor = obj.TileOutline(tileNum).EdgeColor;
        % Note: This is set on tile creation and updated if tile is
        % changed.
        %setappdata(obj.TileOutline(tileNum), 'OrigColor', tileColor);
        obj.TileOutline(tileNum).EdgeColor = min([tileColor+0.15; [1,1,1]]);
    end

    function onMouseExitedTile(obj, tileNum)
        tileColor = getappdata(obj.TileOutline(tileNum), 'OrigColor');
        obj.TileOutline(tileNum).EdgeColor = tileColor;
    end
end

methods(Static)

    % Matlab function belonging to image processing toolbox. Should have
    % been a generic function....

    function points = bbox2points(bbox)
        % BBOX2POINTS Convert a rectangle into a list of points
        %
        %   points = BBOX2POINTS(rectangle) converts a bounding box
        %   into a list of points. rectangle is either a single
        %   bounding box specified as a 4-element vector [x y w h],
        %   or a set of bounding boxes specified as an M-by-4 matrix.
        %   For a single bounding box, the function returns a list of 4 points
        %   specified as a 4-by-2 matrix of [x,y] coordinates. For multiple
        %   bounding boxes the function returns a 4-by-2-by-M array of
        %   [x,y] coordinates, where M is the number of bounding boxes.
        %
        %   Class Support
        %   -------------
        %   bbox can be int16, uint16, int32, uint32, single, or double.
        %   points is the same class as rectangle.
        %
        %   Example
        %   -------
        %   % Define a bounding box
        %   bbox = [10 20 50 60];
        %
        %   % Convert the bounding box to a list of 4 points
        %   points = bbox2points(bbox);
        %
        %   % Define a rotation transformation
        %   theta = 10;
        %   tform = affine2d([cosd(theta) -sind(theta) 0; sind(theta) cosd(theta) 0; 0 0 1]);
        %
        %   % Apply the rotation
        %   points2 = transformPointsForward(tform, points);
        %
        %   % Close the polygon for display
        %   points2(end+1, :) = points2(1, :);
        %
        %   % Plot the rotated box
        %   plot(points2(:, 1), points2(:, 2), '*-');
        %
        %   See also affine2d, projective2d

        %#codegen

        validateattributes(bbox, ...
            {'int16', 'uint16', 'int32', 'uint32', 'single', 'double'}, ...
            {'real', 'nonsparse', 'nonempty', 'finite', 'size', [NaN, 4]}, ...
            'bbox2points', 'bbox');

        validateattributes(bbox(:, [3,4]), {'numeric'}, ...
            {'>=', 0}, 'bbox2points', 'bbox(:,[3,4])');

        numBboxes = size(bbox, 1);
        points = zeros(4, 2, numBboxes, 'like', bbox);

        % upper-left
        points(1, 1, :) = bbox(:, 1);
        points(1, 2, :) = bbox(:, 2);

        % upper-right
        points(2, 1, :) = bbox(:, 1) + bbox(:, 3);
        points(2, 2, :) = bbox(:, 2);

        % lower-right
        points(3, 1, :) = bbox(:, 1) + bbox(:, 3);
        points(3, 2, :) = bbox(:, 2) + bbox(:, 4);

        % lower-left
        points(4, 1, :) = bbox(:, 1);
        points(4, 2, :) = bbox(:, 2) + bbox(:, 4);
    end
end
end
