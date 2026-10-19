classdef AxesAttached < handle
%AxesAttached Abstract base for an object that acts on one axes and its figure
%
%   AxesAttached declares the Axes and Figure properties without
%   defining them. uim.interface.PointerTool implements them, and mixins
%   that pointer tools combine with (uim.mixin.Zoomable,
%   uim.interface.pointertools.mixin.DraggableRectangle) inherit this
%   class so that they can use Axes and Figure.
%
%   The declaration lives here because MATLAB lets a class inherit a
%   property with validation from several superclasses only when every
%   one of them declares it Abstract. A mixin that inherits this class
%   shares the one declaration with PointerTool instead of making a
%   second one.
%
%   Contract for subclasses:
%       - Define Figure and Axes in a properties (SetAccess = protected)
%         block, with the same or no validation.
%
%   AxesAttached properties:
%     Figure - Figure that contains Axes
%     Axes   - Axes the object acts on
%
%   See also uim.interface.PointerTool

    properties (Abstract, SetAccess = protected)
        Figure matlab.ui.Figure % Figure that contains Axes
        Axes matlab.graphics.axis.Axes % Axes the object acts on
    end
end
