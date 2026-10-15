function [ hex ] = rgb2hex(rgb)
%rgb2hex Convert RGB triplets to hexadecimal colour codes
%
%   hex = uim.utility.rgb2hex(rgb) converts the n-by-3 array of RGB
%   values to an n-by-7 character array of codes such as '#00FF00', one
%   per row, with upper-case letters. Values are read on the 0 to 1
%   scale, unless any value exceeds 1, in which case all values are read
%   on the 0 to 255 scale. Values are rounded to whole steps of 1/255.
%
%   Examples:
%       uim.utility.rgb2hex([0, 1, 0])       % '#00FF00'
%       uim.utility.rgb2hex([0, 255, 0])     % '#00FF00'
%       uim.utility.rgb2hex([0.2, 0.3, 0.4; 0.5, 0.6, 0.7])
%
%   Errors:
%       uim:rgb2hex:InvalidNumberOfInputs - Not exactly one input
%       uim:rgb2hex:InvalidType           - rgb is not numeric
%       uim:rgb2hex:InvalidSize           - rgb does not have 3 columns
%       uim:rgb2hex:ValueOutOfRange       - A value is below 0 or
%                                           above 255
%
%   Original author: Chad A. Greene, 2014, with improvements suggested by
%   Stephen Cobeldick.
%
%   See also uim.utility.hex2rgb

%% Check inputs:

assert(nargin==1,"uim:rgb2hex:InvalidNumberOfInputs",'This function requires an RGB input.')
assert(isnumeric(rgb),"uim:rgb2hex:InvalidType",'Function input must be numeric.')

sizergb = size(rgb);
assert(sizergb(2)==3,"uim:rgb2hex:InvalidSize", ...
    'rgb value must have three components in the form [r g b].')
assert(max(rgb(:))<=255& min(rgb(:))>=0,"uim:rgb2hex:ValueOutOfRange", ...
    'rgb values must be on a scale of 0 to 1 or 0 to 255')

%% If no value in RGB exceeds unity, scale from 0 to 255:
if max(rgb(:))<=1
    rgb = round(rgb*255);
else
    rgb = round(rgb);
end

%% Convert (Thanks to Stephen Cobeldick for this clever, efficient solution):

hex(:,2:7) = reshape(sprintf('%02X',rgb.'),6,[]).';
hex(:,1) = '#';
end
