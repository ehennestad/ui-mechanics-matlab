classdef IconSet < uim.Handle
%IconSet Class for interfacing an icon library.
%
% How to use: Create a folder and add pngs with icons. Preferably high
% resolution (Also, currently, only monocolor icons are supported).
% Initialize the IconSet with a reference (path string) to the folder and
% use the addIcon method to add icons to the library. New icons are
% automatically saved in the library file.
%
% IconData for an icon is received by calling iconSet.iconName where
% iconName is the name of the icon.

% Todo:
%   Implement remove icons
%   Add multiple icons in one go
%   Create colorful icons

    properties
        IconDir                 % Path to folder where icons are saved
        FilePath                % File path to the icon library file
        IconNames               % Name of icons in set
        IconData = struct       % Data of icons in set
    end

    methods %Structors
        function obj = IconSet(pathStr)
        %IconSet Initialize an IconSet for an icon library
        %
        %   obj = IconSet(pathStr)

            obj.IconDir = pathStr;
            obj.FilePath = fullfile(obj.IconDir, 'icon_library.mat');

            obj.loadIcons();
        end
    end

    methods

        function varargout = subsref(obj, s)
            varargout = cell(1, nargout);

            switch s(1).type

                % Use builtin if a property is requested.
                case '.'
                    if ~isempty(obj.IconNames) && isscalar(s) && contains(s.subs, obj.IconNames)
                        if ~nargout
                            varargout = {obj.IconData.(s.subs)};
                        else
                            [varargout{:}] = obj.IconData.(s.subs);
                        end
                    else
                        if ~nargout
                            builtin('subsref', obj, s)
                        else
                            [varargout{:}] = builtin('subsref', obj, s);
                        end
                    end
                % Use builtin if a parenthesis are used.
                case '()'
                    if ~nargout
                        builtin('subsref', obj, s)
                    else
                        [varargout{:}] = builtin('subsref', obj, s);
                    end
            end
        end

        function loadIcons(obj)
        %LOADICONS Load icons from matfile

            if isfile(obj.FilePath)
                obj.IconData = load(obj.FilePath);
            end

            obj.IconNames = fieldnames(obj.IconData);
        end

        function saveIcons(obj, S)
        %SAVEICONS Save icons to matfile

            if nargin < 2
                S = obj.IconData;
            end

            if ~isfile(obj.FilePath)
                save(obj.FilePath, '-struct', 'S');
            else
                save(obj.FilePath, '-struct', 'S', '-append');
            end
        end

        function listIcons(obj)
            fprintf([strjoin(obj.IconNames, '\n'), '\n'])
        end

        function addIcon(obj, iconName, S)
        %addIcon Add icon to the library
        %
        %   addIcon(obj, iconName) converts a png to matlab patch data and
        %   saves it to the icon library. iconName must be the name of a
        %   png-file in the iconSet's root directory.

            if nargin < 2
                S = obj.createIcon(obj.IconDir);
            elseif nargin < 3
                S = obj.createIcon(obj.IconDir, iconName);
            end

            if ~isempty(S)
                obj.saveIcons(S)
            end

            newIconNames = fieldnames(S);

            for i = 1:numel(newIconNames)
                obj.IconData.(newIconNames{i}) = S.(newIconNames{i});
            end

            obj.IconNames = fieldnames(obj.IconData);
        end

        function addIconFromFile(obj, iconName, filePath)

            if nargin < 3
                [fileName, folder] = uigetfile();
                if fileName == 0; return; end
                filePath = fullfile(folder, fileName);
            end

            S = load(filePath);

            if nargin < 2
                iconName = inputdlg();
                if isempty(iconName); return; end
                iconName = iconName{1};
            end

            newS = struct();
            newS.(iconName) = S.imageVector;
            obj.addIcon(iconName, newS)
        end

        function removeIcon(obj, iconName)

            isMatch = contains(obj.IconNames, iconName);

            if any(isMatch)
                obj.IconData = rmfield(obj.IconData, iconName);
            end

            obj.IconNames = fieldnames(obj.IconData);
        end

        function setSimplifyFalse(obj)

            names = obj.IconNames;

            for i = 1:numel(names)
                for j = 1:numel(obj.IconData.(names{i}))
                    p1 = obj.IconData.(names{i})(j).Shape;
                    p2 = polyshape(p1.Vertices, 'Simplify', false);
                    obj.IconData.(names{i})(j).Shape = p2;
                end
            end
        end
    end

    methods (Access = private)
% %         function filePath = getIconPackagePath(obj)
% %
% %         end
    end

    methods (Static)

        function S = createIcon(rootDir, iconName, plotType)
        %createIcon Create icondata from a png file
        %
        %   Loads the pngs, converts the shapes in the png to boundary
        %   coordinates and creates a set of patch properties that can
        %   later be plotted using the patch function.
        %
        %   S = createIcon(rootDir, iconName, plotType) returns a struct of
        %   patch properties (S) given rootDir (directory with png files) and
        %   iconName (name of icon png file). plotType can be 'patch'
        %   (default) or 'polygon'. Not sure why I would ever want to use
        %   polygon...

            % Preallocate output
            S = struct.empty();

            if nargin < 3; plotType = 'polygon'; end

            L = dir(fullfile(rootDir, '*.png'));

            [~, iconName] = fileparts(iconName);

            if nargin >= 2 || exist('iconName', 'var')
                IND = find(strcmp({L.name}, [iconName, '.png'] ));
            else
                IND = 1:numel(L);
            end

            fig = figure('Visible', 'off');
            ax = axes(fig);
            axis equal

            for i = IND
                imageName = L(i).name;

                loadPath = fullfile(rootDir, imageName);

                im = imread(loadPath);
                hP = uim.graphics.patchLineDrawing(ax, im, 'cropImage', true, ...
                    'SmoothWindow', 5, 'plotType', plotType);

                switch plotType
                    case 'polygon'
                        % Get the shape and the colors and save to a mat-file
                        polyShape = arrayfun(@(h) h.Shape, hP, 'uni', 0);
                        colors = arrayfun(@(h) h.FaceColor, hP, 'uni', 0);

                        V = struct('Shape', polyShape, 'Color', colors);
                        delete(hP)

                        hV = uim.graphics.ImageVector(ax, V);

                    case 'patch'
                        V = struct('Faces', {hP.Faces}, 'Vertices', {hP.Vertices}, ...
                            'FaceColor', {hP.FaceColor}, 'EdgeColor', {'none'});
                        delete(hP)

                        hV = uim.graphics.ImageVector(ax, V);
                        hV.center()
                end

                % normalize vector image to have height 1.
                hV.Height = hV.Height/hV.Height;

                if isempty(S)
                    S = struct(iconName, hV.getVectorStruct);
                else
                    S.(iconName) = hV.getVectorStruct;
                end

                delete(hV)
            end

            close(fig)
        end
    end
end
