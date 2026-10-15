classdef ValueChangedEventData < event.EventData
%ValueChangedEventData Event data for a change of a widget's value
%
%   evt = uim.event.ValueChangedEventData(oldValue, newValue) stores the
%   value before and after a change. Widgets such as uim.widget.Spinner,
%   uim.widget.DropDown and uim.widget.ContrastSlider pass it to their
%   value-changed callbacks. The type of the values is defined by the
%   sending widget.
%
%   See also uim.event.EventData

   properties
       OldValue % Value before the change
       NewValue % Value after the change
   end

   methods
       function obj = ValueChangedEventData(oldValue, newValue)
       %ValueChangedEventData Create value-changed event data
           obj.OldValue = oldValue;
           obj.NewValue = newValue;
       end
   end
end
