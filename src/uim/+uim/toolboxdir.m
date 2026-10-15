function rootDir = toolboxdir()
%toolboxdir Return the root folder of the toolbox
%
%   rootDir = uim.toolboxdir() returns the absolute path of the folder
%   that contains the uim code folder, i.e. two levels above the +uim
%   namespace folder. In a source checkout this is the repository's src
%   folder. rootDir is a character vector.
%
%   Example:
%       rootDir = uim.toolboxdir()
%
%   See also uim.toolboxversion

    % Get the location of this function
    functionPath = mfilename('fullpath');
    
    % Get the package directory (+uim)
    packageDir = fileparts(functionPath);
    
    % Get the code directory (parent of package directory)
    codeDir = fileparts(packageDir);
    
    % Get the toolbox root directory (parent of code directory)
    rootDir = fileparts(codeDir);
end
