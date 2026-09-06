classdef TestGraphicsHelpers < matlab.unittest.TestCase
%TestGraphicsHelpers ImageVector transforms, line-drawing tracing and IconSet
%
%   ImageVector wraps a set of polyshapes plotted into an axes; these
%   tests drive its transforms and read the resulting bounding box back.

    properties (Access = private)
        Icons
    end

    methods (TestClassSetup)
        function addStandaloneSource(testCase)
            repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
            sourcePath = fullfile(repositoryRoot, "src", "uim");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(sourcePath));
            testCase.Icons = uim.style.getDefaultIcons();
        end
    end

    methods (Test) % ImageVector transforms

        function vectorImageReportsBoundingBoxAndShapes(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.zoomIn);
            testCase.addTeardown(@deleteValid, vectorImage);

            bbox = vectorImage.BoundingBox;
            testCase.verifySize(bbox, [1, 4]);
            testCase.verifyEqual(vectorImage.Width, bbox(3));
            testCase.verifyEqual(vectorImage.Height, bbox(4));

            shapes = vectorImage.getVectorStruct();
            testCase.verifyTrue(isfield(shapes, "Shape") && isfield(shapes, "Color"));
            testCase.verifyNotEmpty(findobj(hAxes, "Type", "polygon"));
        end

        function translateMovesWithoutResizing(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.zoomIn);
            testCase.addTeardown(@deleteValid, vectorImage);
            before = vectorImage.BoundingBox;

            vectorImage.translate([10, -5])
            after = vectorImage.BoundingBox;
            testCase.verifyEqual(after(1:2), before(1:2) + [10, -5], "AbsTol", 1e-9);
            testCase.verifyEqual(after(3:4), before(3:4), "AbsTol", 1e-9);
        end

        function scaleResizesAboutTheOrigin(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.zoomIn);
            testCase.addTeardown(@deleteValid, vectorImage);
            before = vectorImage.BoundingBox;

            vectorImage.scale(2)
            testCase.verifyEqual(vectorImage.BoundingBox(3:4), 2*before(3:4), "AbsTol", 1e-9);

            vectorImage.scale([0.5, 1])
            testCase.verifyEqual(vectorImage.BoundingBox(3), before(3), "AbsTol", 1e-9);
        end

        function widthAndHeightKeepTheAspectRatio(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.zoomIn);
            testCase.addTeardown(@deleteValid, vectorImage);
            aspectRatio = vectorImage.Width / vectorImage.Height;

            vectorImage.Width = 40;
            testCase.verifyEqual(vectorImage.Width, 40, "AbsTol", 1e-9);
            testCase.verifyEqual(vectorImage.Width/vectorImage.Height, aspectRatio, "AbsTol", 1e-9);

            vectorImage.Height = 10;
            testCase.verifyEqual(vectorImage.Height, 10, "AbsTol", 1e-9);
            testCase.verifyEqual(vectorImage.Width/vectorImage.Height, aspectRatio, "AbsTol", 1e-9);

            vectorImage.LockAspectRatio = false;
            vectorImage.Width = 60;
            testCase.verifyEqual(vectorImage.Height, 10, "AbsTol", 1e-9, ...
                "Unlocked, the other dimension stays put.");
        end

        function flipsPreserveTheBoundingBox(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.auto);
            testCase.addTeardown(@deleteValid, vectorImage);
            before = vectorImage.BoundingBox;

            vectorImage.fliplr()
            testCase.verifyEqual(vectorImage.BoundingBox, before, "AbsTol", 1e-6);
            vectorImage.flipud()
            testCase.verifyEqual(vectorImage.BoundingBox, before, "AbsTol", 1e-6);
        end

        function rotationTurnsAboutTheBoxCentre(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.zoomIn);
            testCase.addTeardown(@deleteValid, vectorImage);
            before = vectorImage.BoundingBox;
            centreBefore = before(1:2) + before(3:4)/2;

            vectorImage.rotate(90)
            after = vectorImage.BoundingBox;
            testCase.verifyEqual(after(1:2) + after(3:4)/2, centreBefore, "AbsTol", 1e-6);
            testCase.verifyEqual(after(3:4), fliplr(before(3:4)), "AbsTol", 1e-6, ...
                "A quarter turn swaps width and height.");
            testCase.verifyEqual(vectorImage.Angle, 90);
        end

        function positionMovesTheAlignmentAnchor(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.zoomIn);
            testCase.addTeardown(@deleteValid, vectorImage);

            vectorImage.HorizontalAlignment = 'left';
            vectorImage.VerticalAlignment = 'bottom';
            vectorImage.Position = [100, 50];
            testCase.verifyEqual(vectorImage.BoundingBox(1:2), [100, 50], "AbsTol", 1e-6);

            vectorImage.HorizontalAlignment = 'right';
            vectorImage.VerticalAlignment = 'top';
            vectorImage.Position = [200, 150];
            bbox = vectorImage.BoundingBox;
            testCase.verifyEqual(bbox(1:2) + bbox(3:4), [200, 150], "AbsTol", 1e-6);

            vectorImage.HorizontalAlignment = 'center';
            vectorImage.VerticalAlignment = 'middle';
            vectorImage.Position = [10, 20];
            bbox = vectorImage.BoundingBox;
            testCase.verifyEqual(bbox(1:2) + bbox(3:4)/2, [10, 20], "AbsTol", 1e-6);
        end

        function stylePropertiesReachEveryPolygon(testCase)
            [~, hAxes] = createAxes(testCase);
            vectorImage = uim.graphics.ImageVector(hAxes, testCase.Icons.zoomIn);
            testCase.addTeardown(@deleteValid, vectorImage);
            polygons = findobj(hAxes, "Type", "polygon");

            vectorImage.Color = [1, 0, 0];
            testCase.verifyTrue(all(arrayfun(@(h) isequal(h.FaceColor, [1, 0, 0]), polygons)));
            vectorImage.Alpha = 0.25;
            testCase.verifyTrue(all(arrayfun(@(h) h.FaceAlpha == 0.25, polygons)));
            vectorImage.PickableParts = 'none';
            testCase.verifyTrue(all(strcmp(get(polygons, "PickableParts"), 'none')));
            vectorImage.HitTest = 'off';
            testCase.verifyTrue(all(strcmp(get(polygons, "HitTest"), 'off')));
            vectorImage.Clipping = 'off';
            testCase.verifyEqual(char(vectorImage.Clipping), 'off');
            vectorImage.Visible = 'off';
            testCase.verifyTrue(all(strcmp(get(polygons, "Visible"), 'off')));
        end

        function vectorImageRejectsAnUnsupportedParent(testCase)
            hFigure = figure("Visible", "off");
            testCase.addTeardown(@deleteValid, hFigure);
            testCase.verifyError(...
                @() uim.graphics.ImageVector(hFigure, testCase.Icons.zoomIn), ?MException);
        end
    end

    methods (Test) % patchLineDrawing

        function lineDrawingTracesShapesAsPolygons(testCase)
            [~, hAxes] = createAxes(testCase);
            image = drawingWithSquares();

            hPolygon = uim.graphics.patchLineDrawing(hAxes, image, "plotType", "polygon");
            testCase.verifyClass(hPolygon, "matlab.graphics.primitive.Polygon");
            testCase.verifyEqual(hPolygon.FaceColor, [0, 0, 0]);
            testCase.verifyGreaterThanOrEqual(hPolygon.Shape.NumRegions, 2, ...
                "Both squares are traced.");
        end

        function lineDrawingTracesShapesAsPatchesWithHoles(testCase)
            [~, hAxes] = createAxes(testCase);
            image = drawingWithRing();

            hPatches = uim.graphics.patchLineDrawing(hAxes, image, "plotType", "patch");
            testCase.verifyGreaterThanOrEqual(numel(hPatches), 1);
            testCase.verifyTrue(all(strcmp(get(hPatches, "EdgeColor"), 'none')));
        end

        function croppingIsOptional(testCase)
            [~, hAxes] = createAxes(testCase);
            image = drawingWithSquares();

            cropped = uim.graphics.patchLineDrawing(hAxes, image, "plotType", "polygon");
            uncropped = uim.graphics.patchLineDrawing(hAxes, image, ...
                "plotType", "polygon", "cropImage", false);

            croppedVertices = cropped.Shape.Vertices;
            uncroppedVertices = uncropped.Shape.Vertices;
            testCase.verifyNotEqual(min(croppedVertices(:, 1)), min(uncroppedVertices(:, 1)), ...
                "Cropping shifts the traced coordinates.");
        end
    end

    methods (Test) % IconSet

        function iconSetLoadsAndListsTheShippedLibrary(testCase)
            iconFolder = shippedIconFolder();
            iconSet = uim.style.IconSet(iconFolder);

            testCase.verifyNotEmpty(iconSet.IconNames);
            testCase.verifyTrue(ismember('zoomIn', iconSet.IconNames));
            testCase.verifyEqual(iconSet.zoomIn, iconSet.IconData.zoomIn, ...
                "Icons are reachable by name through subsref.");

            output = evalc("iconSet.listIcons()");
            testCase.verifyTrue(contains(output, 'zoomIn'));
        end

        function iconSetAddsAndRemovesIconsInACopy(testCase)
            workingFolder = copyIconLibrary(testCase);
            iconSet = uim.style.IconSet(workingFolder);
            originalCount = numel(iconSet.IconNames);

            newIcon = struct('myIcon', iconSet.IconData.zoomIn);
            iconSet.addIcon('myIcon', newIcon)
            testCase.verifyEqual(numel(iconSet.IconNames), originalCount + 1);
            testCase.verifyTrue(ismember('myIcon', iconSet.IconNames));

            % The addition is persisted, so a fresh set sees it too
            reloaded = uim.style.IconSet(workingFolder);
            testCase.verifyTrue(ismember('myIcon', reloaded.IconNames));

            iconSet.removeIcon('myIcon')
            testCase.verifyFalse(ismember('myIcon', iconSet.IconNames));
            iconSet.removeIcon('notThere')
            testCase.verifyEqual(numel(iconSet.IconNames), originalCount);
        end

        function iconSetCreatesIconDataFromAPngFile(testCase)
            workingFolder = copyIconLibrary(testCase);
            imwrite(drawingWithSquares(), fullfile(workingFolder, 'square.png'))

            iconData = uim.style.IconSet.createIcon(workingFolder, 'square');
            testCase.verifyTrue(isfield(iconData, 'square'));
            testCase.verifyTrue(isfield(iconData.square, 'Shape'));

            iconSet = uim.style.IconSet(workingFolder);
            iconSet.addIcon('square')
            testCase.verifyTrue(ismember('square', iconSet.IconNames));
            iconSet.setSimplifyFalse()
            testCase.verifyTrue(ismember('square', iconSet.IconNames));
        end

        function missingLibraryYieldsAnEmptySet(testCase)
            emptyFolder = createTemporaryFolder(testCase);
            iconSet = uim.style.IconSet(emptyFolder);
            testCase.verifyEmpty(iconSet.IconNames);
        end
    end
end

function [hFigure, hAxes] = createAxes(testCase)
    hFigure = figure("Visible", "off", "Units", "pixels", "Position", [100, 100, 400, 300]);
    testCase.addTeardown(@deleteValid, hFigure);
    hAxes = axes(hFigure);
    hold(hAxes, "on")
end

function image = drawingWithSquares()
%drawingWithSquares White image with two black squares
    image = 255*ones(80, 120, 3, 'uint8');
    image(20:45, 20:45, :) = 0;
    image(20:45, 70:95, :) = 0;
end

function image = drawingWithRing()
%drawingWithRing White image with a black square that has a hole in it
    image = 255*ones(80, 80, 3, 'uint8');
    image(15:65, 15:65, :) = 0;
    image(30:50, 30:50, :) = 255;
end

function iconFolder = shippedIconFolder()
    repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
    iconFolder = fullfile(repositoryRoot, "src", "uim", "resources", "icons");
end

function workingFolder = copyIconLibrary(testCase)
%copyIconLibrary Temporary copy so tests never write to the shipped library
    workingFolder = createTemporaryFolder(testCase);
    copyfile(fullfile(shippedIconFolder(), "icon_library.mat"), workingFolder)
end

function folder = createTemporaryFolder(testCase)
    fixture = testCase.applyFixture(...
        matlab.unittest.fixtures.TemporaryFolderFixture);
    folder = fixture.Folder;
end

function deleteValid(object)
    if isvalid(object)
        delete(object)
    end
end
