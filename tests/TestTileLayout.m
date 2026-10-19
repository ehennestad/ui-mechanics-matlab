classdef TestTileLayout < matlab.unittest.TestCase
%TestTileLayout Tile-grid geometry (uim.graphics.internal) and TiledImageAxes

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % Pure geometry

        function gridPixelSizeIncludesGaps(testCase)
            pixelSize = uim.graphics.internal.tileGridPixelSize([2, 3], [10, 20], 4);
            testCase.verifyEqual(pixelSize, [24, 68]);
        end

        function rowwiseLayoutNumbersTilesAlongRows(testCase)
            layout = uim.graphics.internal.computeTileLayout([2, 3], [2, 2], 1, 'rowwise');

            testCase.verifySize(layout.TileIndices, [2, 3]);
            testCase.verifySize(layout.TileIndexMap, [5, 8]);
            testCase.verifyEqual(layout.TileCorners(1, :), [1, 1]);
            testCase.verifyEqual(layout.TileCorners(2, :), [4, 1], "Tile 2 is right of tile 1.");
            testCase.verifyEqual(layout.TileCorners(4, :), [1, 4], "Tile 4 starts the second row.");

            testCase.verifyEqual(layout.TileIndexMap(1:2, 1:2), ones(2));
            testCase.verifyTrue(all(isnan(layout.TileIndexMap(:, 3))), "Column 3 is a gap.");
            testCase.verifyTrue(all(isnan(layout.TileIndexMap(3, :))), "Row 3 is a gap.");

            [rows, cols] = ind2sub([5, 8], layout.TileIndices{4}(:));
            testCase.verifyEqual(sort(unique(rows)), [4; 5]);
            testCase.verifyEqual(sort(unique(cols)), [1; 2]);
        end

        function columnwiseLayoutNumbersTilesAlongColumns(testCase)
            layout = uim.graphics.internal.computeTileLayout([2, 3], [2, 2], 1, "columnwise");
            testCase.verifyEqual(layout.TileCorners(2, :), [1, 4], "Tile 2 is below tile 1.");
            testCase.verifyEqual(layout.TileCorners(3, :), [4, 1]);
        end

        function layoutRejectsUnknownPlotOrder(testCase)
            testCase.verifyError(...
                @() uim.graphics.internal.computeTileLayout([2, 3], [2, 2], 1, 'spiral'), ...
                "uim:computeTileLayout:InvalidPlotOrder");
        end

        function tileCenterFollowsRowwiseNumbering(testCase)
            center = uim.graphics.internal.tileCenter(1, 3, [10, 20], 2, [1, 1]);
            testCase.verifyEqual(center, [10.5, 5.5]);

            center = uim.graphics.internal.tileCenter(5, 3, [10, 20], 2, [1, 1]);
            testCase.verifyEqual(center, [32.5, 17.5], "Tile 5 is row 2, column 2.");
        end

        function tileCenterAppliesScaleFactor(testCase)
            center = uim.graphics.internal.tileCenter(1, 3, [10, 20], 2, [2, 2]);
            testCase.verifyEqual(center, [5.5, 3]);
        end

        function tileAtPointReadsTheIndexMap(testCase)
            layout = uim.graphics.internal.computeTileLayout([2, 3], [2, 2], 1, 'rowwise');
            map = layout.TileIndexMap;

            testCase.verifyEqual(uim.graphics.internal.tileAtPoint(map, 1, 1, [1, 1]), 1);
            testCase.verifyEqual(uim.graphics.internal.tileAtPoint(map, 4.4, 4.6, [1, 1]), 5, ...
                "Rounds to pixel (4, 5): row 2, column 2.");
            testCase.verifyTrue(isnan(uim.graphics.internal.tileAtPoint(map, 3, 1, [1, 1])), ...
                "Gap between tiles.");
            testCase.verifyTrue(isnan(uim.graphics.internal.tileAtPoint(map, 0, 1, [1, 1])));
            testCase.verifyTrue(isnan(uim.graphics.internal.tileAtPoint(map, 9, 1, [1, 1])));
            testCase.verifyEqual(uim.graphics.internal.tileAtPoint(map, 2, 0.5, [2, 2]), 2, ...
                "Scale factor converts axes units to map pixel (4, 1).");
        end

        function tileHelpersReadScaleFactorAsXThenY(testCase)
            % Two 2-by-2 tiles side by side: map columns 3-4 are tile 2.
            layout = uim.graphics.internal.computeTileLayout([1, 2], [2, 2], 0, 'rowwise');
            testCase.verifyEqual(uim.graphics.internal.tileAtPoint(...
                layout.TileIndexMap, 1.6, 1, [2, 1]), 2, ...
                "x scales by scaleFactor(1): column round(3.2) = 3.");

            % 10-by-20 tiles with x scaled by 2: each tile is 10 by 10
            % axes units.
            center = uim.graphics.internal.tileCenter(2, 3, [10, 20], 0, [2, 1]);
            testCase.verifyEqual(center, [15.5, 5.5]);
        end
    end

    methods (Test) % TiledImageAxes

        function tiledAxesGeometryMatchesLayoutHelpers(testCase)
            [hFigure, tiledAxes] = createTiledAxes(testCase, [2, 3], [16, 24], ...
                "NormalizedPadding", 0.05);

            testCase.verifyEqual(tiledAxes.NumTiles, 6);
            testCase.verifyEqual(tiledAxes.NumRows, 2);
            testCase.verifyEqual(tiledAxes.NumColumns, 3);

            % PixelPadding is derived from NormalizedPadding and the grid.
            % Tile 5 is row 2, column 2 of 16-by-24 tiles: one tile and one
            % padding along each axis, plus half a tile and the half-pixel
            % offset.
            expectedPadding = round(2 * 16 * 0.05);
            testCase.assertGreaterThan(expectedPadding, 0);
            expectedCenter = [24 + 12, 16 + 8] + expectedPadding + 0.5;
            testCase.verifyEqual(tiledAxes.getTileCenterAxesCoords(5), expectedCenter);

            for tileNum = [1, 4, 6]
                center = tiledAxes.getTileCenterAxesCoords(tileNum);
                testCase.verifyEqual(tiledAxes.hittest(center(1), center(2)), tileNum);
            end
            testCase.verifyTrue(isnan(tiledAxes.hittest(-5, -5)));

            % Without coordinates, hittest reads the pointer position.
            pointerPixel = uim.utility.du2px(tiledAxes.Axes, ...
                tiledAxes.getTileCenterAxesCoords(4), true);
            hFigure.CurrentPoint = pointerPixel;
            testCase.verifyEqual(tiledAxes.hittest(), 4);
        end

        function scaledTilesAgreeWhenImagesAreRescaledUnevenly(testCase)
            hFigure = figure("Visible", "off", "Position", [100, 100, 400, 300]);
            testCase.addTeardown(@deleteValid, hFigure);
            tiledAxes = uim.graphics.TiledImageAxes(hFigure, "GridSize", [2, 3], ...
                "ImageSize", [16, 24], "TileUnits", "scaled", "NormalizedPadding", 0.05);
            testCase.addTeardown(@deleteValid, tiledAxes);

            % 32-by-24 originals shown in 16-by-24 tiles: y is halved and
            % x is unchanged, so the axes span the original pixels.
            tiledAxes.setOriginalImageSize([32, 24])
            pixelPadding = round(2 * 16 * 0.05);
            testCase.verifyEqual(tiledAxes.Axes.XLim, [0, 3*24 + 2*pixelPadding] + 0.5);
            testCase.verifyEqual(tiledAxes.Axes.YLim, [0, (2*16 + pixelPadding) * 2] + 0.5);

            % Hit-testing, tile centres and the drawn outlines agree.
            for tileNum = 1:tiledAxes.NumTiles
                hOutline = findobj(tiledAxes.Axes, "Type", "patch", "Tag", num2str(tileNum));
                outlineCenter = [min(hOutline.XData) + max(hOutline.XData), ...
                    min(hOutline.YData) + max(hOutline.YData)] / 2;

                testCase.verifyEqual(tiledAxes.hittest(outlineCenter(1), outlineCenter(2)), ...
                    tileNum, sprintf("Tile %d is hit at the centre of its outline.", tileNum));
                testCase.verifyEqual(tiledAxes.getTileCenterAxesCoords(tileNum), ...
                    outlineCenter, "AbsTol", 1, ...
                    sprintf("Tile %d's centre is inside its outline.", tileNum));
            end
        end

        function tiledAxesShowsImagesAndTextPerTile(testCase)
            [~, tiledAxes] = createTiledAxes(testCase, [2, 2], [8, 8]);

            tiledAxes.updateTileImage(uint8(200*ones(8)), 3)
            tiledAxes.updateTileText({'three'}, 3)
            drawnow

            hImage = findobj(tiledAxes.Axes, "Type", "image");
            testCase.verifyNumElements(hImage, 1, "All tiles share one image object.");
            centerPoint = tiledAxes.getTileCenterAxesCoords(3);
            testCase.verifyEqual(hImage.CData(round(centerPoint(2)), round(centerPoint(1))), ...
                uint8(200));
        end

        function tiledAxesReconfiguresWhenGridSizeChanges(testCase)
            [~, tiledAxes] = createTiledAxes(testCase, [2, 2], [8, 8]);
            tiledAxes.GridSize = [3, 4];
            testCase.verifyEqual(tiledAxes.NumTiles, 12);
            testCase.verifyEqual(tiledAxes.hittest(...
                tiledAxes.getTileCenterAxesCoords(12) * [1; 0], ...
                tiledAxes.getTileCenterAxesCoords(12) * [0; 1]), 12);
        end

        function tiledAxesWithoutParentAppliesOptionsToItsFigure(testCase)
            tiledAxes = uim.graphics.TiledImageAxes("GridSize", [2, 2], "Visible", "off");
            testCase.addTeardown(@deleteValid, tiledAxes.Figure);

            testCase.verifyEqual(tiledAxes.NumTiles, 4);
            testCase.verifyEqual(char(tiledAxes.Figure.Visible), 'off', ...
                "Options reach the figure the object creates.");
        end

        function tiledAxesMatchesOptionNamesCaseInsensitively(testCase)
            tiledAxes = uim.graphics.TiledImageAxes("gridsize", [2, 3], "visible", "off");
            testCase.addTeardown(@deleteValid, tiledAxes.Figure);

            testCase.verifyEqual(tiledAxes.GridSize, [2, 3]);
        end

        function tiledAxesRejectsOtherOptions(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);

            testCase.verifyError(@() uim.graphics.TiledImageAxes(hFigure, "NoSuchOption", 1), ...
                "MATLAB:TooManyInputs");
            testCase.verifyError(@() uim.graphics.TiledImageAxes(hFigure, ...
                "HighlightTileOnMouseOver", true), "MATLAB:TooManyInputs", ...
                "Only the documented options are accepted at construction.");
        end

        function tiledAxesAcceptsAnEmptyParent(testCase)
            tiledAxes = uim.graphics.TiledImageAxes([], "GridSize", [1, 2], "Visible", "off");
            testCase.addTeardown(@deleteValid, tiledAxes.Figure);

            testCase.verifyEqual(tiledAxes.NumTiles, 2, "Options after an empty parent apply.");
        end

        function tiledAxesRejectsAParentThatIsNotAContainer(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            hAxes = axes(hFigure);

            testCase.verifyError(@() uim.graphics.TiledImageAxes(hAxes), ...
                "uim:TiledImageAxes:InvalidParent");
        end

        function escapeEndsUiwaitWithNaN(testCase)
            tiledAxes = uim.graphics.TiledImageAxes("GridSize", [1, 2], "Visible", "off");
            hFigure = tiledAxes.Figure;
            testCase.addTeardown(@deleteValid, hFigure);
            tiledAxes.selectTile([], [], 2)

            for key = ["return", "escape"]
                if ~isvalid(hFigure)
                    tiledAxes = uim.graphics.TiledImageAxes("GridSize", [1, 2], "Visible", "off");
                    hFigure = tiledAxes.Figure;
                    testCase.addTeardown(@deleteValid, hFigure);
                    tiledAxes.selectTile([], [], 2)
                end
                pressTimer = timer("StartDelay", 0.3, "TimerFcn", ...
                    @(~, ~) tiledAxes.keypress([], struct("Key", key)));
                testCase.addTeardown(@delete, pressTimer);
                start(pressTimer)

                ind = tiledAxes.uiwait();

                if key == "return"
                    testCase.verifyEqual(ind, 2, "Return returns the selected tile.");
                else
                    testCase.verifyTrue(isnan(ind), "Escape returns NaN.");
                end
                testCase.verifyFalse(isvalid(hFigure), "The figure is closed.");
            end
        end

        function tileCallbacksSurviveAGridRebuild(testCase)
            [hFigure, tiledAxes] = createTiledAxes(testCase, [2, 2], [8, 8]);
            callback = @(~, ~) setappdata(hFigure, "Clicked", true);
            tiledAxes.tileCallbackFcn(callback, 2)

            tiledAxes.GridSize = [2, 3];

            hOutline = findobj(tiledAxes.Axes, "Type", "patch", "Tag", "2");
            testCase.verifyEqual(hOutline.ButtonDownFcn, callback, ...
                "A callback set with tileCallbackFcn is kept.");
            hOther = findobj(tiledAxes.Axes, "Type", "patch", "Tag", "3");
            testCase.verifyClass(hOther.ButtonDownFcn, "cell", ...
                "Other tiles keep the default selectTile callback.");
        end

        function spacingSetsTheGapInPixels(testCase)
            hFigure = figure("Visible", "off", "Position", [100, 100, 400, 300]);
            testCase.addTeardown(@deleteValid, hFigure);
            tiledAxes = uim.graphics.TiledImageAxes(hFigure, "GridSize", [2, 3], ...
                "ImageSize", [16, 24], "Spacing", 3);
            testCase.addTeardown(@deleteValid, tiledAxes);

            % Tile 5 is row 2, column 2: one tile and one gap along each
            % axis, plus half a tile and the half-pixel offset.
            testCase.verifyEqual(tiledAxes.getTileCenterAxesCoords(5), [24 + 12, 16 + 8] + 3 + 0.5);

            tiledAxes.Spacing = 0;
            testCase.verifyEqual(tiledAxes.getTileCenterAxesCoords(5), [24 + 12, 16 + 8] + 0.5);
            testCase.verifyEqual(tiledAxes.Axes.XLim, [0, 3*24] + 0.5, ...
                "Changing Spacing rebuilds the grid.");
        end

        function tilePlotAcceptsANumericVector(testCase)
            [~, tiledAxes] = createTiledAxes(testCase, [2, 2], [8, 8]);

            tiledAxes.updateTilePlot([1, 2, 3], [1, 2, 3], [1, 4])

            plotXData = get(findobj(tiledAxes.Axes, "Tag", "TilePlotHandle"), {'XData'});
            for tileNum = [1, 4]
                tileCenter = tiledAxes.getTileCenterAxesCoords(tileNum);
                isTilePlot = cellfun(@(x) isequal(x(:), [1; 2; 3] + tileCenter(1)), plotXData);
                testCase.verifyTrue(any(isTilePlot), sprintf("Tile %d gets the vector.", tileNum));
            end
        end

        function deletingTiledAxesRemovesItsAxes(testCase)
            [hFigure, tiledAxes] = createTiledAxes(testCase, [1, 2], [8, 8]);
            hAxes = tiledAxes.Axes;
            delete(tiledAxes)
            testCase.verifyFalse(isvalid(hAxes));
            testCase.verifyTrue(isvalid(hFigure), "The host figure is left alone.");
        end
    end
end

function [hFigure, tiledAxes] = createTiledAxes(testCase, gridSize, imageSize, options)
    arguments
        testCase
        gridSize
        imageSize
        options.NormalizedPadding
    end

    hFigure = figure("Visible", "off", "Position", [100, 100, 400, 300]);
    testCase.addTeardown(@deleteValid, hFigure);
    optionArgs = namedargs2cell(options);
    tiledAxes = uim.graphics.TiledImageAxes(hFigure, ...
        "GridSize", gridSize, "ImageSize", imageSize, optionArgs{:});
    testCase.addTeardown(@deleteValid, tiledAxes);
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
