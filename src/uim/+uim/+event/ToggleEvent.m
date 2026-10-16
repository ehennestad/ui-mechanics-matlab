classdef ToggleEvent < event.EventData
%ToggleEvent Event data carrying an on/off state
%
%   evt = uim.event.ToggleEvent(value) stores a toggle state, which
%   senders in this toolbox give as 1 (on) or 0 (off). The sender
%   defines what the state means: uim.widget.PlaybackControl sends 1 when
%   playback starts and 0 when it stops.
%
%   See also uim.event.EventData

   properties
       Value % Toggle state, 1 (on) or 0 (off) as sent in this toolbox
   end

   methods
       function obj = ToggleEvent(value)
       %ToggleEvent Create toggle event data
           obj.Value = value;
       end
   end
end
