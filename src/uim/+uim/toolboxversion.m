function versionStr = toolboxversion()
%toolboxversion Return the version of the toolbox
%
%   versionStr = uim.toolboxversion() reads the Contents.m file in the
%   folder that contains the +uim namespace folder (src/uim in a source
%   checkout) and returns its first version token, including the
%   "Version" prefix, as a character vector (e.g. 'Version 1.2.3'). A
%   four-part version (X.Y.Z.W) is preferred over X.Y.Z when both are
%   present. The token must be followed by a space to match.
%
%   Errors:
%       UIM:Version:VersionNotFound - Contents.m has no version token.
%       MATLAB:fileread:cannotOpenFile - Contents.m does not exist in
%           that folder, which is the case in a source checkout.
%
%   Example:
%       versionStr = uim.toolboxversion()
%
%   See also uim.toolboxdir

    rootPath = fileparts(fileparts(mfilename('fullpath')));
    contentsFile = fullfile(rootPath, 'Contents.m');

    fileStr = fileread(contentsFile);
   
    % First try to get a version with a sub-patch version number
    matchedStr = regexp(fileStr, 'Version \d*\.\d*\.\d*.\d*(?= )', 'match');

    % If not found, get major-minor-patch
    if isempty(matchedStr)
        matchedStr = regexp(fileStr, 'Version \d*\.\d*\.\d*(?= )', 'match');
    end

    if isempty(matchedStr)
        error('UIM:Version:VersionNotFound', ...
            'No version was detected for this UI Mechanics for MATLAB installation.')
    end
    versionStr = matchedStr{1};
end
