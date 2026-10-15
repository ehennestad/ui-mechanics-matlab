function [isAccepted, history] = acceptScrollStep(history, scrollCount)
%acceptScrollStep Filter jittery scroll-wheel steps against recent history
%
%   [isAccepted, history] = uim.widget.internal.acceptScrollStep(history,
%       scrollCount) appends scrollCount to the sliding history (dropping
%   the oldest entry) and accepts the step only when it agrees with the
%   net direction of the history. Trackpads deliver sequences such as
%   0, 1, 1, -1, 1 while the fingers move in one direction; the stray -1
%   would make the bar flicker backwards. A zero step is never accepted.

    arguments
        history (:,1) double
        scrollCount (1,1) double
    end

    history = [history(2:end); scrollCount];
    netDirection = sum(history);

    isAccepted = (scrollCount > 0 && netDirection > 0) || ...
                 (scrollCount < 0 && netDirection < 0);
end
