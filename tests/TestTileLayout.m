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
                "uim:graphics:InvalidPlotOrder");
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
    end

    methods (Test) % TiledImageAxes

        function tiledAxesGeometryMatchesLayoutHelpers(testCase)
            [hFigure, tiledAxes] = createTiledAxes(testCase, [2, 3], [16, 24]);

            testCase.verifyEqual(tiledAxes.NumTiles, 6);
            testCase.verifyEqual(tiledAxes.NumRows, 2);
            testCase.verifyEqual(tiledAxes.NumColumns, 3);

            % PixelPadding is derived from NormalizedPadding and the grid.
            % Tile 5 is row 2, column 2 of 16-by-24 tiles: one tile and one
            % padding along each axis, plus half a tile and the half-pixel
            % offset.
            expectedPadding = round(2 * 16 * tiledAxes.NormalizedPadding);
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

        function deletingTiledAxesRemovesItsAxes(testCase)
            [hFigure, tiledAxes] = createTiledAxes(testCase, [1, 2], [8, 8]);
            hAxes = tiledAxes.Axes;
            delete(tiledAxes)
            testCase.verifyFalse(isvalid(hAxes));
            testCase.verifyTrue(isvalid(hFigure), "The host figure is left alone.");
        end
    end
end

function [hFigure, tiledAxes] = createTiledAxes(testCase, gridSize, imageSize)
    hFigure = figure("Visible", "off", "Position", [100, 100, 400, 300]);
    testCase.addTeardown(@deleteValid, hFigure);
    tiledAxes = uim.graphics.TiledImageAxes(hFigure, ...
        "GridSize", gridSize, "ImageSize", imageSize);
    testCase.addTeardown(@deleteValid, tiledAxes);
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
