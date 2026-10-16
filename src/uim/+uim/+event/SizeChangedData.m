classdef SizeChangedData < event.EventData
%SizeChangedData Event data for a change of size
%
%   evt = uim.event.SizeChangedData(oldSize, newSize) stores the size
%   before and after the change, each as [width, height] in pixels.
%   uim.abstract.Component and uim.UIComponentCanvas send it with their
%   SizeChanged events. For the canvas's first sizing, OldSize is
%   [NaN, NaN].
%
%   See also uim.event.LocationChangedData, uim.abstract.Component,
%   uim.UIComponentCanvas

   properties
       OldSize % Size before the change, [width, height] in pixels
       NewSize % Size after the change, [width, height] in pixels
   end

   methods
       function obj = SizeChangedData(oldSize, newSize)
       %SizeChangedData Create size-changed event data
           obj.OldSize = oldSize;
           obj.NewSize = newSize;
       end
   end
end
