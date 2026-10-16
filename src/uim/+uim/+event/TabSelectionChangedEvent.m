classdef TabSelectionChangedEvent < event.EventData
%TabSelectionChangedEvent Event data for a change of the selected tab
%
%   evt = uim.event.TabSelectionChangedEvent(oldValue, newValue) stores
%   the tab that was selected before and after the change.
%   uim.container.TabGroup sends it with its SelectionChanged event and
%   passes it to SelectionChangedFcn, with both values as
%   uim.container.Tab objects.
%
%   See also uim.container.TabGroup, uim.container.Tab

   properties
       OldValue % Previously selected tab (uim.container.Tab)
       NewValue % Newly selected tab (uim.container.Tab)
   end

   methods
       function obj = TabSelectionChangedEvent(oldValue, newValue)
       %TabSelectionChangedEvent Create tab-selection event data
           obj.OldValue = oldValue;
           obj.NewValue = newValue;
       end
   end
end
