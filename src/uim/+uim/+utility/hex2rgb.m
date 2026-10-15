function [ rgb ] = hex2rgb(hex,range)
%hex2rgb Convert hexadecimal colour codes to RGB triplets
%
%   rgb = uim.utility.hex2rgb(hex) converts hex colour codes such as
%   '#334D66' to an n-by-3 array of RGB values from 0 to 1. hex is a
%   character vector, a character matrix with one code per row, or a
%   cell vector of character vectors of equal length. The '#' is
%   optional, and letters may be upper or lower case.
%
%   rgb = uim.utility.hex2rgb(hex, 256) returns values from 0 to 255
%   instead; a range of 255 does the same.
%
%   Examples:
%       uim.utility.hex2rgb('#334D66')       % [0.2000, 0.3020, 0.4000]
%       uim.utility.hex2rgb('334D66', 256)   % [51, 77, 102]
%       uim.utility.hex2rgb({'#334D66'; '#8099B3'})
%
%   Errors:
%       uim:hex2rgb:InvalidNumberOfInputs - Not one or two inputs
%       uim:hex2rgb:InvalidRange          - range is not 1, 255 or 256
%       uim:hex2rgb:InvalidSize           - hex is a cell array that is
%                                           not a vector
%
%   Original author: Chad A. Greene, 2014, with improvements suggested by
%   Stephen Cobeldick.
%
%   See also uim.utility.rgb2hex

%% Input checks:

assert(nargin>0&nargin<3,"uim:hex2rgb:InvalidNumberOfInputs", ...
    'hex2rgb function must have one or two inputs.')

if nargin==2
    assert(isscalar(range),"uim:hex2rgb:InvalidRange", ...
        'Range must be a scalar, either "1" to scale from 0 to 1 or "256" to scale from 0 to 255.')
end

%% Tweak inputs if necessary:

if iscell(hex)
    assert(isvector(hex),"uim:hex2rgb:InvalidSize",'Unexpected dimensions of input hex values.')

    % In case cell array elements are separated by a comma instead of a
    % semicolon, reshape hex:
    if isrow(hex)
        hex = hex';
    end

    % If input is cell, convert to matrix:
    hex = cell2mat(hex);
end

if strcmpi(hex(1,1),'#')
    hex(:,1) = [];
end

if nargin == 1
    range = 1;
end

%% Convert from hex to rgb:

switch range
    case 1
        rgb = reshape(sscanf(hex.','%2x'),3,[]).'/255;

    case {255,256}
        rgb = reshape(sscanf(hex.','%2x'),3,[]).';

    otherwise
        error("uim:hex2rgb:InvalidRange", ...
            'Range must be either "1" to scale from 0 to 1 or "256" to scale from 0 to 255.')
end
end
