function value = snapToStep(value, step)
%snapToStep Round values to the nearest multiple of a step size
%
%   value = uim.widget.internal.snapToStep(value, step) rounds each element
%   of value to the closest integer multiple of step. Sliders use this to
%   quantise a continuous pointer position onto their tick grid.

    arguments
        value {mustBeNumeric}
        step (1,1) double {mustBePositive, mustBeFinite}
    end

    value = round(value ./ step) .* step;
end
