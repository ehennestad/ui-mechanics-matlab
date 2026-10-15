classdef TestTiledAndPlaybackInteractions < matlab.unittest.TestCase
%TestTiledAndPlaybackInteractions Tile content, playback buttons and scrollbar drags

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
        end
    end

    methods (Test) % TiledImageAxes content

        function tileImagesAreWrittenAndRemoved(testCase)
            [~, tiledAxes] = createTiledAxes(testCase, [2, 2], [8, 8]);
            hImage = findobj(tiledAxes.Axes, "Type", "image");

            tiledAxes.updateTileImage(uint8(150*ones(8)), 2)
            centre = round(tiledAxes.getTileCenterAxesCoords(2));
            testCase.verifyEqual(hImage.CData(centre(2), centre(1)), uint8(150));
            testCase.verifyEqual(hImage.AlphaData(centre(2), centre(1)), 1);

            tiledAxes.removeTileImage(2)
            testCase.verifyEqual(hImage.CData(centre(2), centre(1)), uint8(0));
            testCase.verifyEqual(hImage.AlphaData(centre(2), centre(1)), 0);
        end

        function tilePlotsAreCentredOnTheirTile(testCase)
            [~, tiledAxes] = createTiledAxes(testCase, [2, 2], [8, 8]);

            tiledAxes.updateTilePlot({[-2, 0, 2]}, {[-2, 0, 2]}, 3)
            hPlots = findobj(tiledAxes.Axes, "Tag", "TilePlotHandle");
            hPlot = hPlots(arrayfun(@(h) ~any(isnan(h.XData)), hPlots));
            testCase.assertNumElements(hPlot, 1);

            centre = tiledAxes.getTileCenterAxesCoords(3);
            testCase.verifyEqual(mean(hPlot.XData), centre(1), "AbsTol", 1e-9);
            testCase.verifyEqual(mean(hPlot.YData), centre(2), "AbsTol", 1e-9);
            testCase.verifyEqual(hPlot.UserData.XLim, [centre(1) - 3.5, centre(1) + 3.5], ...
                "AbsTol", 1e-9, "The plot records the tile it may move within.");

            tiledAxes.updateTilePlotLinewidth(3, 2)
            testCase.verifyEqual(hPlot.LineWidth, 2);
        end

        function selectingATileRecoloursItAndCallsBack(testCase)
            [hFigure, tiledAxes] = createTiledAxes(testCase, [2, 2], [8, 8]);
            tiledAxes.TileCallbackFcn = @(~, ~, tileNum) setappdata(hFigure, "Tile", tileNum);
            outlines = tileOutlines(tiledAxes.Axes);

            pressTile(outlines(2))
            testCase.verifyEqual(tiledAxes.SelectedTiles, 2);
            testCase.verifyEqual(getappdata(hFigure, "Tile"), 2);
            testCase.verifyEqual(outlines(2).EdgeColor, ...
                tiledAxes.TileConfiguration.SelectedTileColor);

            pressTile(outlines(4))
            testCase.verifyEqual(tiledAxes.SelectedTiles, 4);
            testCase.verifyEqual(outlines(2).EdgeColor, ...
                tiledAxes.TileConfiguration.DefaultTileColor, ...
                "The previous selection is reset.");

            tiledAxes.setTileOutlineColor(1, [1, 0, 0])
            testCase.verifyEqual(outlines(1).EdgeColor, [1, 0, 0]);
            tiledAxes.setTileTransparency(1, 0.5)
            testCase.verifyEqual(outlines(1).FaceAlpha, 0.5);
        end

        function tileTextAndPlotStylingApplyToAllTiles(testCase)
            [~, tiledAxes] = createTiledAxes(testCase, [1, 3], [8, 8]);

            tiledAxes.updateTileText({'a', 'b', 'c'}, 1:3)
            texts = findobj(tiledAxes.Axes, "Tag", "TileTextHandle");
            testCase.verifyEqual(sort(string({texts.String})), ["a", "b", "c"]);

            tiledAxes.setTextColor([1, 0, 0])
            testCase.verifyTrue(all(arrayfun(@(h) isequal(h.Color, [1, 0, 0]), texts)));

            tiledAxes.setPlotVisibility('off')
            plots = findobj(tiledAxes.Axes, "Tag", "TilePlotHandle");
            testCase.verifyTrue(all(strcmp(get(plots, "Visible"), 'off')));

            tiledAxes.Visible = 'off';
            testCase.verifyEqual(char(findobj(tiledAxes.Axes, "Type", "image").Visible), 'off');
            tiledAxes.Visible = 'on';
        end

        function mouseOverHighlightingCanBeEnabled(testCase)
            [hFigure, tiledAxes] = createTiledAxes(testCase, [1, 2], [8, 8]);
            outlines = tileOutlines(tiledAxes.Axes);
            originalColor = outlines(1).EdgeColor;

            tiledAxes.HighlightTileOnMouseOver = true;
            behavior = iptGetPointerBehavior(outlines(1));
            testCase.assertNotEmpty(behavior, "Enabling installs pointer behaviour.");

            behavior.enterFcn(hFigure, [0, 0])
            testCase.verifyGreaterThan(sum(outlines(1).EdgeColor), sum(originalColor), ...
                "Entering a tile lightens its outline.");
            behavior.exitFcn(hFigure, [0, 0])
            testCase.verifyEqual(outlines(1).EdgeColor, originalColor);

            tiledAxes.HighlightTileOnMouseOver = false;
            testCase.verifyEmpty(iptGetPointerBehavior(outlines(1)));
        end

        function scaledTileUnitsRescaleTheCoordinateSystem(testCase)
            [~, tiledAxes] = createTiledAxes(testCase, [2, 2], [16, 16]);
            pixelCentre = tiledAxes.getTileCenterAxesCoords(4);

            tiledAxes.setOriginalImageSize([8, 8])
            tiledAxes.TileUnits = 'scaled';
            scaledCentre = tiledAxes.getTileCenterAxesCoords(4);

            testCase.verifyLessThan(scaledCentre(1), pixelCentre(1), ...
                "Scaled units map the grid onto the original image size.");
            testCase.verifyEqual(tiledAxes.hittest(scaledCentre(1), scaledCentre(2)), 4);
        end
    end

    methods (Test) % PlaybackControl buttons

        function playAndPauseNotifyTheHost(testCase)
            [hFigure, widget] = createPlaybackControl(testCase);
            widget.PlaybackStartedFcn = @(~, evt) setappdata(hFigure, "Started", evt.Value);
            widget.PlaybackStoppedFcn = @(~, evt) setappdata(hFigure, "Stopped", evt.Value);

            hPlay = findall(hFigure, "Tag", "Play");
            testCase.assertNumElements(hPlay, 1);
            hPlay.ButtonDownFcn(hPlay, [])
            testCase.verifyEqual(getappdata(hFigure, "Started"), 1);
            testCase.verifyEqual(hPlay.Tag, 'Pause', "The button becomes a pause button.");

            hPlay.ButtonDownFcn(hPlay, [])
            testCase.verifyEqual(getappdata(hFigure, "Stopped"), 0);
            testCase.verifyEqual(hPlay.Tag, 'Play');
        end

        function speedButtonsHalveAndDoubleThePlaybackSpeed(testCase)
            [hFigure, widget] = createPlaybackControl(testCase);
            widget.PlaybackSpeedChangedFcn = @(~, evt) setappdata(hFigure, "Speed", evt.NewValue);

            hIncrease = findall(hFigure, "Tag", "Incr");
            hDecrease = findall(hFigure, "Tag", "Decr");

            hIncrease.ButtonDownFcn(hIncrease, [])
            testCase.verifyEqual(widget.PlaybackSpeed, 2);
            testCase.verifyEqual(getappdata(hFigure, "Speed"), 2);

            hDecrease.ButtonDownFcn(hDecrease, [])
            hDecrease.ButtonDownFcn(hDecrease, [])
            testCase.verifyEqual(widget.PlaybackSpeed, 0.5);
            testCase.verifyNotEmpty(findall(hFigure, "Type", "text", "String", "0.5x"));
        end

        function pressingTheTrackJumpsToAFrame(testCase)
            [hFigure, widget] = createPlaybackControl(testCase);
            widget.ValueChangedFcn = @(~, evt) setappdata(hFigure, "Value", evt.NewValue);
            widget.Value = 25;

            hTrack = findall(hFigure, "Tag", "Scrollbar");
            testCase.assertNumElements(hTrack, 1);
            hTrack.ButtonDownFcn(hTrack, [])

            testCase.verifyTrue(isappdata(hFigure, "Value"), "A track press moves the frame.");
            newValue = getappdata(hFigure, "Value");
            testCase.verifyGreaterThanOrEqual(newValue, widget.Minimum);
            testCase.verifyLessThanOrEqual(newValue, widget.Maximum);
            testCase.verifyEqual(widget.Value, newValue);
        end

        function activeRangeHandlesAndBarAgreeAboveMinimum(testCase)
            hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 500, 200]);
            testCase.addTeardown(@deleteValid, hFigure);
            widget = uim.widget.PlaybackControl(hFigure, "Position", [10, 10, 400, 30], ...
                "Minimum", 11, "Maximum", 60, "Value", 20);
            testCase.addTeardown(@deleteValid, widget);
            hSliderAxes = findall(hFigure, "Tag", "Playback Widget (Slider Axes)");
            xFor = @(value) trackPosition(widget, hSliderAxes, value);

            % With Minimum above 1, the handles and the bar both offset
            % from Minimum, so they mark the same interval.
            widget.RangeSelectorEnabled = 'on';
            widget.ActiveRange = [15, 30];

            hRangeButtons = findobj(hSliderAxes, "Type", "line", "Marker", "o");
            testCase.verifyEqual(sort([hRangeButtons.XData]), [xFor(15), xFor(30)], "AbsTol", 1e-6);
            hRangeBar = findobj(hSliderAxes, "Type", "patch", "FaceColor", [0, 1, 0]);
            testCase.verifyEqual(min(hRangeBar.XData), xFor(15), "AbsTol", 1);
            testCase.verifyEqual(max(hRangeBar.XData), xFor(30), "AbsTol", 1);
        end

        function activeRangeSelectorDrawsAndResets(testCase)
            [hFigure, widget] = createPlaybackControl(testCase);
            hSliderAxes = findall(hFigure, "Tag", "Playback Widget (Slider Axes)");
            xFor = @(value) trackPosition(widget, hSliderAxes, value);

            widget.RangeSelectorEnabled = 'on';
            widget.ActiveRange = [5, 30];

            % The range handles sit at the ends of the selected interval
            hRangeButtons = findobj(hSliderAxes, "Type", "line", "Marker", "o");
            testCase.assertNumElements(hRangeButtons, 2);
            handleX = sort([hRangeButtons.XData]);
            testCase.verifyEqual(handleX, [xFor(5), xFor(30)], "AbsTol", 1e-6);
            testCase.verifyTrue(all(strcmp(get(hRangeButtons, "PickableParts"), 'all')), ...
                "Enabled handles accept presses.");

            % ... and the highlighted bar spans it
            hRangeBar = findobj(hSliderAxes, "Type", "patch", "FaceColor", [0, 1, 0]);
            testCase.assertNumElements(hRangeBar, 1);
            testCase.verifyEqual(max(hRangeBar.XData) - min(hRangeBar.XData), ...
                xFor(30) - xFor(5), "AbsTol", 1);

            widget.resetRangeSelector()
            testCase.verifyEqual(widget.ActiveRange, [1, 1]);
            testCase.verifyEqual(char(hRangeBar.Visible), 'off');
            testCase.verifyTrue(all(strcmp(get(hRangeButtons, "PickableParts"), 'none')), ...
                "Disabled handles ignore presses.");
        end
    end

    methods (Test) % ScrollBar interaction

        function hoveringHighlightsTheBarAndTrack(testCase)
            [hFigure, scrollBar] = createScrollBar(testCase);
            hAxes = findall(hFigure, "Tag", "Scrollbar Axes");
            hBar = findobj(hAxes, "Tag", "Scrollbar");
            hTrack = findobj(hAxes, "Tag", "Sidebar");

            scrollBar.hittest(hBar)
            testCase.verifyEqual(hFigure.Pointer, 'hand');
            testCase.verifyEqual(hBar.FaceAlpha, 0.8, "The bar lightens under the pointer.");

            scrollBar.hittest(hTrack)
            testCase.verifyEqual(hFigure.Pointer, 'hand');
            testCase.verifyEqual(hBar.FaceAlpha, 0.6, "Leaving the bar restores it.");

            scrollBar.hittest(gobjects(1))
            testCase.verifyEqual(hFigure.Pointer, 'arrow');
        end

        function draggingTheBarNotifiesOnRelease(testCase)
            [hFigure, scrollBar] = createScrollBar(testCase);
            scrollBar.StopMoveCallback = @(~, change) setappdata(hFigure, "Change", change);
            hBar = findobj(findall(hFigure, "Tag", "Scrollbar Axes"), "Tag", "Scrollbar");

            hBar.ButtonDownFcn(hBar, [])
            testCase.verifyNotEmpty(hFigure.WindowButtonMotionFcn, ...
                "The drag installs figure-level motion tracking.");
            testCase.verifyNotEmpty(hFigure.WindowButtonUpFcn);

            hFigure.WindowButtonUpFcn(hBar, [])
            testCase.verifyTrue(isappdata(hFigure, "Change"));
            testCase.verifyEqual(hBar.FaceColor, scrollBar.BarColor, ...
                "The bar colour is restored on release.");
        end
    end
end

function [hFigure, tiledAxes] = createTiledAxes(testCase, gridSize, imageSize)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 300]);
    testCase.addTeardown(@deleteValid, hFigure);
    tiledAxes = uim.graphics.TiledImageAxes(hFigure, ...
        "GridSize", gridSize, "ImageSize", imageSize);
    testCase.addTeardown(@deleteValid, tiledAxes);
end

function [hFigure, widget] = createPlaybackControl(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 500, 200]);
    testCase.addTeardown(@deleteValid, hFigure);
    widget = uim.widget.PlaybackControl(hFigure, "Position", [10, 10, 400, 30], ...
        "Minimum", 1, "Maximum", 50, "Value", 10);
    testCase.addTeardown(@deleteValid, widget);
end

function [hFigure, scrollBar] = createScrollBar(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 300]);
    testCase.addTeardown(@deleteValid, hFigure);
    hPanel = uipanel(hFigure, "Units", "pixels", "Position", [10, 10, 20, 200]);
    scrollBar = uim.widget.ScrollBar(hPanel, "Maximum", 10, "VisibleAmount", 2);
    testCase.addTeardown(@deleteValid, scrollBar);
end

function x = trackPosition(widget, hSliderAxes, value)
%trackPosition Pixel position of a slider value along the playback track
    trackLength = hSliderAxes.Position(3) - 2*widget.BarPadding;
    x = widget.BarPadding + ...
        trackLength*(value - widget.Minimum)/(widget.Maximum - widget.Minimum);
end

function pressTile(hOutline)
%pressTile Invoke a tile's ButtonDownFcn, which carries its tile number
    callback = hOutline.ButtonDownFcn;
    callback{1}(hOutline, [], callback{2:end})
end

function outlines = tileOutlines(hAxes)
%tileOutlines Tile outline patches, ordered by tile number
    patches = findobj(hAxes, "Type", "patch");
    tileNumbers = str2double(get(patches, "Tag"));
    isOutline = ~isnan(tileNumbers);
    patches = patches(isOutline);
    [~, order] = sort(tileNumbers(isOutline));
    outlines = patches(order);
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
