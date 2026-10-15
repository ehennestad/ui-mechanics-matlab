classdef IconSet < uim.Handle
%IconSet Library of vector icons stored in a folder
%
%   An IconSet reads and extends icon_library.mat in a folder. Each icon
%   is vector data (a struct array with polyshape Shape and Color fields)
%   that uim.graphics.ImageVector and the Icon property of
%   uim.control.Button accept. New icons are traced from PNG files in
%   the same folder; use high-resolution, single-colour drawings.
%
%   iconSet = uim.style.IconSet(folderPath) loads the library in
%   folderPath. When the folder has no icon_library.mat, the set starts
%   empty and addIcon creates the file.
%
%   iconSet.iconName returns the data of the icon called iconName, for
%   example iconSet.zoomIn. A requested name is treated as an icon when
%   any icon name is contained in it, so an icon whose name is part of a
%   property or method name (for example an icon named "Icon") hides
%   that property or method.
%
%   Methods:
%       addIcon         - Trace a PNG in the folder and save it as an icon
%       addIconFromFile - Add an icon from a .mat file with an imageVector
%       removeIcon      - Remove an icon from the set in memory
%       listIcons       - Print the icon names
%       loadIcons       - Reload the library file
%       saveIcons       - Save icons to the library file
%       createIcon      - (Static) Trace PNG files into icon data
%
%   See also uim.style.getDefaultIcons, uim.graphics.ImageVector

% Todo:
%   Add multiple icons in one go
%   Create colorful icons

    properties
        IconDir                 % Path to folder where icons are saved
        FilePath                % File path to the icon library file
        IconNames               % Name of icons in set
        IconData = struct       % Struct with one field of vector icon data per icon
    end

    methods %Structors
        function obj = IconSet(pathStr)
        %IconSet Create an IconSet for the library in a folder
        %
        %   iconSet = uim.style.IconSet(folderPath)

            obj.IconDir = pathStr;
            obj.FilePath = fullfile(obj.IconDir, 'icon_library.mat');

            obj.loadIcons();
        end
    end

    methods

        function varargout = subsref(obj, s)
        %subsref Return icon data for iconSet.iconName; otherwise index as usual
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
        %loadIcons Reload the icons from the library file
        %
        %   iconSet.loadIcons() reads FilePath into IconData when the file
        %   exists, and updates IconNames.

            if isfile(obj.FilePath)
                obj.IconData = load(obj.FilePath);
            end

            obj.IconNames = fieldnames(obj.IconData);
        end

        function saveIcons(obj, S)
        %saveIcons Save icons to the library file
        %
        %   iconSet.saveIcons() saves IconData to FilePath.
        %   iconSet.saveIcons(S) saves the fields of the struct S, one per
        %   icon. Icons are added to an existing file; icons already in
        %   the file and not in S are kept.

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
        %listIcons Print the icon names, one per line
            fprintf([strjoin(obj.IconNames, '\n'), '\n'])
        end

        function addIcon(obj, iconName, S)
        %addIcon Add an icon to the set and save it to the library file
        %
        %   iconSet.addIcon(iconName) traces iconName.png in IconDir with
        %   createIcon, saves the result to the library file and adds it
        %   to IconData. Nothing is added when no such PNG exists.
        %
        %   iconSet.addIcon(iconName, S) saves and adds the icons in the
        %   struct S (one field per icon) instead; iconName is not used.
        %
        %   Calling addIcon without iconName raises an error, because
        %   createIcon requires an icon name.

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
        %addIconFromFile Add an icon from a .mat file holding an imageVector
        %
        %   iconSet.addIconFromFile(iconName, filePath) loads the variable
        %   imageVector from the .mat file filePath and adds it as iconName
        %   with addIcon, which also saves it to the library file.
        %
        %   iconSet.addIconFromFile(iconName) asks for the file in a file
        %   dialog, and iconSet.addIconFromFile() also asks for the name.

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
        %removeIcon Remove an icon from the set in memory
        %
        %   iconSet.removeIcon(iconName) removes iconName from IconData and
        %   IconNames. The library file is not changed, so loadIcons or a
        %   new IconSet brings the icon back. A name that matches no icon
        %   does nothing, but a name that is only part of an icon name
        %   raises an error.

            isMatch = contains(obj.IconNames, iconName);

            if any(isMatch)
                obj.IconData = rmfield(obj.IconData, iconName);
            end

            obj.IconNames = fieldnames(obj.IconData);
        end

        function setSimplifyFalse(obj)
        %setSimplifyFalse Rebuild every icon polyshape with Simplify false
        %
        %   Changes IconData in memory only; call saveIcons to keep it.

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
        %createIcon Trace a PNG file into vector icon data
        %
        %   S = uim.style.IconSet.createIcon(rootDir, iconName) reads
        %   iconName.png from rootDir (an extension on iconName is
        %   ignored), traces its shapes with uim.graphics.patchLineDrawing
        %   and returns a struct with one field, iconName, holding the
        %   vector data (polyshape Shape and Color), scaled to height 1.
        %   S is empty when the PNG is not found. A hidden figure is
        %   created for the tracing and closed afterwards.
        %
        %   S = uim.style.IconSet.createIcon(rootDir, iconName, plotType)
        %   sets the trace type: 'polygon' (default) or 'patch'. The
        %   'patch' path calls an ImageVector method that does not exist
        %   and raises an error.

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
