classdef TiledImageAxes < uim.Handle
%TiledImageAxes Grid of image tiles drawn in a single axes
%
%   A TiledImageAxes works like a grid of small subplots inside one
%   axes. Each tile can show an image, a line drawing (patch) and a text
%   label, and can be selected with a click. All tile images share one
%   image object, so a grid of hundreds of tiles updates much faster
%   than a figure with as many real subplots.
%
%   obj = uim.graphics.TiledImageAxes() creates the tiled axes in a new
%   figure.
%
%   obj = uim.graphics.TiledImageAxes(parent) creates it in parent, a
%   figure, uipanel or uitab.
%
%   obj = uim.graphics.TiledImageAxes(parent, Name=Value) also sets
%   GridSize, ImageSize, NumChannels, NormalizedPadding, TileUnits,
%   Visible, TileConfiguration or Padding. Names are case insensitive;
%   other names are ignored.
%
%   Tiles are numbered row by row, from the upper-left tile. The axes
%   has YDir 'reverse' and is invisible. With TileUnits 'pixel', axes
%   coordinates are pixels of the composite image. With 'scaled', they
%   are pixels of the original images (see setOriginalImageSize), which
%   are resized to ImageSize for display.
%
%   Changing GridSize or ImageSize rebuilds the tiles, and so does a
%   change of TileUnits or of the original image size that changes the
%   axes scale. Rebuilding clears tile images and plots, and gives the
%   outlines their default color and click callback (selectTile) back.
%
%   Deleting the object deletes its axes.
%
%   TiledImageAxes methods:
%     updateTileImage         - Show image data in tiles
%     removeTileImage         - Clear the image of tiles
%     updateTileText          - Set the text label of tiles
%     updateTilePlot          - Draw a line drawing in tiles
%     resetTile               - Clear image, plot, text and color of tiles
%     resetAxes               - Clear all tiles
%     selectTile              - Select a tile, as a click on it does
%     setTileOutlineColor     - Color the outline of a tile
%     tileCallbackFcn         - Replace the click callback of a tile
%     hittest                 - Tile number at a point
%     getTileCenterAxesCoords - Axes coordinate of a tile's centre
%
%   Example:
%       hFigure = figure;
%       tiles = uim.graphics.TiledImageAxes(hFigure, GridSize=[2, 3], ...
%           ImageSize=[64, 64]);
%       tiles.updateTileImage(uint8(255 * rand(64, 64)), 1)
%       tiles.updateTileText('Tile 1', 1)
%       tiles.TileCallbackFcn = @(~, ~, tileNum) disp(tileNum);
%
%   See also uim.graphics.internal.computeTileLayout

% "Persistent settings" Consider if it should be configurable for objects.
properties (Constant = true)
    PlotOrder = 'rowwise'       % Tile numbering order: rowwise | columnwise
end

properties % Properties to configure axes layout (Default values are preset)
    GridSize = [3, 5]           % [nRows, nCols]
    ImageSize = [128, 128]      % [imHeight, imWidth] Size (Reso) in px per tile
    Padding = 10                % Not used; see NormalizedPadding. Todo: Rename to spacing.
    NumChannels = 1;            % Color channels per tile: 1 (colormapped) or 3 (RGB). Set at construction.

    % Gap between tiles as a fraction of the grid height in pixels
    % (NumRows * ImageSize(1)). Set at construction.
    NormalizedPadding = 0.012;
    TileUnits = 'pixel'         % pixel | scaled: axes coordinates in composite-image or original-image pixels

    Visible = 'on'              % on | off: visibility of the tile graphics
end

properties % Properties for configuration of appearance

    % Tile appearance: outline colors, the colormap applied at
    % construction, the text color for new labels, and the face alpha of
    % a selected tile.
    TileConfiguration = struct('DefaultTileColor', ones(1,3)*0.7, ...
                               'SelectedTileColor', ones(1,3)*0.5, ...
                               'DefaultColorMap', 'parula', ...
                               'TextColor', ones(1,3)*0.8, ...
                               'SelectedTileAlpha', 0.4)

    % If true, brighten a tile outline while the pointer is over it.
    % Needs the Image Processing Toolbox; without it nothing happens.
    HighlightTileOnMouseOver = false

    % Called as TileCallbackFcn([], [], tileNum) after a tile is selected
    TileCallbackFcn
end

properties (SetAccess = protected) % Properties for public access
    SelectedTiles  % Number of the selected tile, or empty
    AxesRange      % Width and height of the axes limits, [xRange, yRange]
end

properties (Dependent = true) % General info about class objects
    Figure      % Figure that contains the axes
    Axes        % Axes that holds the tiles
    NumTiles    % Number of tiles in the grid
    NumRows     % Number of tile rows, GridSize(1)
    NumColumns  % Number of tile columns, GridSize(2)
    Position    % Position of the axes in its parent; setting it moves the axes
end

% Properties that are used internally
properties (Access = private, Hidden)
    TileCorners
    TileCenters
    TileIndices
    TileIndexMap

    ImageSize_ = [128, 128]     % Original size of images that are plotted. % Todo. Set this on construction?
    ScaleFactor = [1, 1]        % [x, y] scale from axes units to composite-image pixels

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
    %TiledImageAxes Create a tiled image axes
    %
    %   obj = uim.graphics.TiledImageAxes()
    %   obj = uim.graphics.TiledImageAxes(parent)
    %   obj = uim.graphics.TiledImageAxes(parent, Name=Value)
    %
    %   Name-Value arguments (see the class properties):
    %       GridSize          - [nRows, nCols], default [3, 5]
    %       ImageSize         - [height, width] of each tile in pixels,
    %                           default [128, 128]
    %       NumChannels       - 1 (default) or 3
    %       NormalizedPadding - gap between tiles, default 0.012
    %       TileUnits         - 'pixel' (default) or 'scaled'
    %       Visible           - 'on' (default) or 'off'
    %       TileConfiguration - struct of tile appearance settings
    %       Padding           - not used

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

        uim.internal.disableAxesInteractivity(obj.Axes_)

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

                uim.internal.setPointerBehavior(obj.TileOutline(i), pointerBehavior)
            end

        else % Reset
            for i = 1:numel(obj.TileOutline)
                uim.internal.setPointerBehavior(obj.TileOutline(i), [])
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
            uim.graphics.internal.createColormapList(obj.Image.UIContextMenu, obj.Axes_)
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
    %   data within individual tiles. See
    %   uim.graphics.internal.computeTileLayout for the fields that are set.

        layout = uim.graphics.internal.computeTileLayout(obj.GridSize, ...
            obj.ImageSize, obj.PixelPadding, obj.PlotOrder);

        obj.TileIndices = layout.TileIndices;
        obj.TileCorners = layout.TileCorners;
        obj.TileIndexMap = layout.TileIndexMap;
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
    %hittest Tile number at an axes coordinate (default: the pointer)
    %
    %   tileNum = obj.hittest() uses the axes CurrentPoint, rounded.
    %   tileNum = obj.hittest(x, y) uses the axes coordinate (x, y).
    %   tileNum is NaN outside the grid and in the gaps between tiles.

        if nargin < 3
            mousePoint = round(obj.Axes.CurrentPoint(1, 1:2));
            x = mousePoint(1); y = mousePoint(2);
        end

        tileNum = uim.graphics.internal.tileAtPoint(...
            obj.TileIndexMap, x, y, obj.ScaleFactor);
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
        pixelSize = uim.graphics.internal.tileGridPixelSize(...
            obj.GridSize, obj.ImageSize, obj.PixelPadding);
        pixelWidth = pixelSize(2);
    end

    function pixelHeight = get.PixelHeight(obj)
        pixelSize = uim.graphics.internal.tileGridPixelSize(...
            obj.GridSize, obj.ImageSize, obj.PixelPadding);
        pixelHeight = pixelSize(1);
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
    %setOriginalImageSize Set the size of the source images for scaled units
    %
    %   obj.setOriginalImageSize(imageSize) sets the [height, width] of
    %   the images before they are resized to ImageSize. With TileUnits
    %   'scaled', axes coordinates are pixels of images of this size.
    %   updateTileImage sets it from the data it receives.

        % Quick fix. Not quite sure if this is actually the original image
        % size. Was needed to get the scalefactor correct, because the
        % hardcoded default value ([128,128]) of imageSize_ is not always
        % applicable. Todo: Clean this up
        obj.ImageSize_ = imageSize;
        obj.updateScaleFactor()
    end

    function pos = getTileOffset(obj, tileNum)
    %getTileOffset Centre of a tile in composite-image pixels
    %
    %   pos = obj.getTileOffset(tileNum) returns the [x, y] mean of the
    %   tile's pixel positions in the composite image, without the
    %   conversion to axes coordinates that getTileCenter applies.

        fullSize = [obj.PixelHeight, obj.PixelWidth];

        [y, x] = ind2sub(fullSize, obj.TileIndices{tileNum} );
        tileCenter = [mean(x(:)), mean(y(:))];

        pos = tileCenter;
    end

    function pixelpos = getpixelposition(obj)
    %getpixelposition Position of the axes in pixels
    %
    %   pixelpos = obj.getpixelposition() returns getpixelposition of the
    %   axes, [left, bottom, width, height] relative to its parent.
        pixelpos = getpixelposition(obj.Axes);
    end

    function pos = getTileCenter(obj, tileNum)
    %getTileCenter Centre of a tile in axes coordinates
    %
    %   pos = obj.getTileCenter(tileNum) returns the [x, y] mean of the
    %   tile's pixel positions, divided by the scale factor between axes
    %   units and composite-image pixels.
    %
    %   See also getTileCenterAxesCoords

        fullSize = [obj.PixelHeight, obj.PixelWidth];

        [y, x] = ind2sub(fullSize, obj.TileIndices{tileNum} );
        tileCenter = [mean(x(:)), mean(y(:))];

        pos = tileCenter ./ obj.ScaleFactor;
    end

    function pos = getTileCenterAxesCoords(obj, tileNum)
    %getTileCenterAxesCoords Axes coordinate of a tile's centre
    %
    %   pos = obj.getTileCenterAxesCoords(tileNum) returns [x, y] in axes
    %   units. hittest(pos(1), pos(2)) returns tileNum.
        pos = uim.graphics.internal.tileCenter(tileNum, obj.NumColumns, ...
            obj.ImageSize, obj.PixelPadding, obj.ScaleFactor);
    end

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
    %fitAxes Resize the axes to show one screen pixel per image pixel
    %
    %   obj.fitAxes() sets the axes width and height in pixels to the
    %   size of the composite image, keeping its lower-left corner.

    % Todo: Rename, and make sure it does not exceed screen size...

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
    %resetAxes Clear the content of all tiles before an update
    %
    %   obj.resetAxes() sets every pixel of the composite image to 255
    %   and clears all tile plots and text. Image transparency and
    %   outline colors are unchanged.
        obj.Image.CData(:) = 255;
        set(obj.TilePlot, 'XData', nan, 'YData', nan)
        set(obj.TileText, 'String', '')
    end

    function resetTile(obj, tileNum)
    %resetTile Clear the image, plot, text and outline color of tiles
    %
    %   obj.resetTile(tileNum) restores the default outline color, clears
    %   and hides the image, and clears the plot and text of each tile in
    %   tileNum, a row vector of tile numbers.

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
    %updateTileImage Show image data in one or more tiles
    %
    %   obj.updateTileImage(imdata, tileNum) writes imdata into the tiles
    %   listed in tileNum and makes them opaque. imdata is
    %   height-by-width for one tile, height-by-width-by-n for n tiles
    %   with NumChannels 1, and height-by-width-by-NumChannels-by-n
    %   otherwise. The composite image is uint8, so values are converted
    %   to uint8; with NumChannels 1 they index the axes colormap.
    %
    %   Data whose height and width differ from ImageSize is resized with
    %   imresize (Image Processing Toolbox), and its size becomes the
    %   original image size (see setOriginalImageSize).

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
    %removeTileImage Clear the image of one or more tiles
    %
    %   obj.removeTileImage(tileNum) sets the tiles' pixels to 0 and makes
    %   them transparent.

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
    %updateTileText Set the text label of one or more tiles
    %
    %   obj.updateTileText(textString, tileNum) sets the label of each
    %   tile in tileNum. textString is a character vector for one tile,
    %   or a cell array of character vectors with one element per tile.
    %   A string scalar is not accepted.
    %   Labels sit near the upper-left corner of their tile.
    %
    %   obj.updateTileText(textString, tileNum, Name, Value) also sets
    %   text object properties, such as Color or FontSize, on those
    %   labels.

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
    %updateTilePlot Draw a line drawing in one or more tiles
    %
    %   obj.updateTilePlot(xData, yData, tileNum) sets the patch of each
    %   tile in tileNum to the vertices in xData and yData. Both are cell
    %   arrays with one vector per tile, in axes units relative to the
    %   tile centre. The patches have a white edge and a nearly
    %   transparent face. The x and y range of each tile is stored in
    %   the patch's UserData as the fields XLim and YLim.

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
    %updateTilePlotLinewidth Set the line width of tile plots
    %
    %   obj.updateTilePlotLinewidth(tileNum, lineWidth) sets the patch
    %   LineWidth, a scalar in points, for the tiles in tileNum.
        set(obj.TilePlot(tileNum), 'LineWidth', lineWidth')
    end

    % TODO: Rename these methods to setCallbacks
    function tileCallbackFcn(obj, funHandle, tileNum)
    %tileCallbackFcn Replace the click callback of a tile outline
    %
    %   obj.tileCallbackFcn(funHandle, tileNum) sets the ButtonDownFcn of
    %   the outline of tile tileNum, replacing the default selectTile.
    %   Rebuilding the tiles restores the default.
        obj.TileOutline(tileNum).ButtonDownFcn = funHandle;
    end

    function tilePlotButtonDownFcn(obj, funHandle, tileNum)
    %tilePlotButtonDownFcn Set the click callback of a tile plot
    %
    %   obj.tilePlotButtonDownFcn(funHandle, tileNum) sets the
    %   ButtonDownFcn of the patch of tile tileNum.
        obj.TilePlot(tileNum).ButtonDownFcn = funHandle;
    end

    % % % Keypress callback

    function keypress(obj, ~, event)
    %keypress End a uiwait on Return or Escape
    %
    %   The KeyPressFcn of the figure the object creates when no parent
    %   is given.

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
    %uiwait Wait for the user to choose a tile in the object's own figure
    %
    %   ind = obj.uiwait() blocks until the user presses Return, then
    %   closes the figure and returns SelectedTiles. If the figure is
    %   closed instead, ind is NaN. Only an object created without a
    %   parent has the key handler that ends the wait.

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
    %selectTile Select a tile, as a click on its outline does
    %
    %   obj.selectTile(src, event, tileNum) restores the default color of
    %   the previously selected tile, colors tile tileNum with
    %   SelectedTileColor, sets SelectedTiles and calls TileCallbackFcn.
    %   src and event are ignored.

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
    %setTileOutlineColor Color the outline and face of one tile
    %
    %   obj.setTileOutlineColor(tileNum, color) colors the edge and face
    %   of the tile with face alpha SelectedTileAlpha (at least 0.01).
    %   obj.setTileOutlineColor(tileNum) restores DefaultTileColor with
    %   face alpha 0.05. tileNum is a single tile number.

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
    %setTextColor Set the color of all tile labels
        obj.TileConfiguration.TextColor = newColor;
        set(obj.TileText, 'Color', newColor)
    end

    function setPlotVisibility(obj, mode)
    %setPlotVisibility Show ('on') or hide ('off') all tile plots
        set(obj.TilePlot, 'Visible', mode)
    end

    function setTileTransparency(obj, tileNum, alphaLevel)
    %setTileTransparency Set the face alpha (0-1) of tile outlines
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
                % ImageSize is [height, width]; the scale factor is [x, y]
                newScaleFactor = fliplr(obj.ImageSize ./ obj.ImageSize_);
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
        %   points = uim.graphics.TiledImageAxes.bbox2points(bbox)
        %   converts a bounding box into a list of points. bbox is either a single
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
