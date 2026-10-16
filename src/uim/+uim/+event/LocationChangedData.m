classdef LocationChangedData < event.EventData
%LocationChangedData Event data for a change of a component's location
%
%   evt = uim.event.LocationChangedData(oldLocation, newLocation) stores
%   the location before and after the change. uim.abstract.Component
%   sends it with its LocationChanged event, with locations as [x, y] in
%   pixels (Position(1:2)).
%
%   See also uim.event.SizeChangedData, uim.abstract.Component

   properties
       OldLocation % Location before the change, [x, y] in pixels
       NewLocation % Location after the change, [x, y] in pixels
   end

   methods
       function obj = LocationChangedData(oldLocation, newLocation)
       %LocationChangedData Create location-changed event data
           obj.OldLocation = oldLocation;
           obj.NewLocation = newLocation;
       end
   end
end
