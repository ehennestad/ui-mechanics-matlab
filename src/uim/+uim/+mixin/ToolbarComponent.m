classdef ToolbarComponent < matlab.mixin.Heterogeneous
%ToolbarComponent Heterogeneous base class for toolbar children
%
%   An empty matlab.mixin.Heterogeneous subclass meant to let toolbar
%   buttons and separators share one object array. No uim class inherits
%   it; uim.widget.Toolbar stores its children as uim.abstract.Component
%   objects instead.
%
%   See also uim.widget.Toolbar

   % Dummy class for allowing toolbar buttons and toolbar separators as
   % toolbar children.
end
