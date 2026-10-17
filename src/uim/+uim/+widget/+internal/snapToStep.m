function value = snapToStep(value, step, origin)
%snapToStep Round values to the nearest point of a step grid
%
%   value = uim.widget.internal.snapToStep(value, step) rounds each element
%   of value to the closest integer multiple of step.
%
%   value = uim.widget.internal.snapToStep(value, step, origin) rounds to
%   the closest origin + k*step instead. Sliders pass their minimum as
%   origin, so pointer positions land on the values Min + k*Step.

    arguments
        value {mustBeNumeric}
        step (1,1) double {mustBePositive, mustBeFinite}
        origin (1,1) double {mustBeFinite} = 0
    end

    value = origin + round((value - origin) ./ step) .* step;
end
