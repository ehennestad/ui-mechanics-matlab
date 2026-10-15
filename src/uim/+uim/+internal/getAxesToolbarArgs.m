function args = getAxesToolbarArgs()
%getAxesToolbarArgs Get name-value pair for suppressing the axes toolbar
%
%   args = getAxesToolbarArgs() returns {'Toolbar', []} on MATLAB
%   releases that support suppressing the built-in axes toolbar
%   (R2018b or later), otherwise an empty cell array.

    matlabVersion = version('-release');
    doDisableToolbar = str2double(matlabVersion(1:4))>2018 || ...
                               strcmp(matlabVersion, '2018b');

    if doDisableToolbar
        args = {'Toolbar', []};
    else
        args = {};
    end
end
