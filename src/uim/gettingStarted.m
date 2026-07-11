function gettingStarted()
    % GETTINGSTARTED Open the getting started guide for the toolbox
    %
    %   GETTINGSTARTED() opens the getting started guide for the toolbox.
    %
    %   Example:
    %       uim.gettingStarted()
    %
    %   See also uim.toolboxdir, uim.toolboxversion

    % Display welcome message
    fprintf('Welcome to UI Mechanics for MATLAB!\n\n');
    fprintf('Composable controls and interactions for MATLAB figures.\n\n');
    
    % Display version information
    fprintf('Version: %s\n', uim.toolboxversion());
    
    % Display directory information
    fprintf('Toolbox directory: %s\n\n', uim.toolboxdir());
    
    % Display available functions
    fprintf('Available functions:\n');
    fprintf('  - uim.toolboxdir\n');
    fprintf('  - uim.toolboxversion\n');
    fprintf('  - uim.gettingStarted\n\n');
    
    % Display examples
    fprintf('Examples:\n');
    examplesDir = fullfile(uim.toolboxdir(), 'code', 'examples');
    if exist(examplesDir, 'dir')
        exampleFiles = dir(fullfile(examplesDir, '*.m'));
        if ~isempty(exampleFiles)
            for i = 1:length(exampleFiles)
                fprintf('  - %s\n', exampleFiles(i).name);
            end
        else
            fprintf('  No examples found.\n');
        end
    else
        fprintf('  Examples directory not found.\n');
    end
    
    % Display documentation
    fprintf('\nDocumentation:\n');
    docsDir = fullfile(uim.toolboxdir(), 'docs');
    if exist(docsDir, 'dir')
        fprintf('  Documentation is available in the docs directory:\n');
        fprintf('  %s\n', docsDir);
    else
        fprintf('  Documentation directory not found.\n');
    end
    
    fprintf('\nFor more information, see the README.md file in the toolbox directory.\n');
end
