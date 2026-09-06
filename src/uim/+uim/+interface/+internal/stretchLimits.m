function limits = stretchLimits(limits, deltaPixels, axisLengthPixels)
%stretchLimits Expand or contract limits by dragging along an axis
%
%   limits = uim.interface.internal.stretchLimits(limits, deltaPixels, ...
%       axisLengthPixels) moves both ends outwards by the fraction
%   deltaPixels/axisLengthPixels of the current width (inwards for a
%   negative delta). The axis-zoom tool maps a drag along an axis ruler
%   to this change.

    arguments
        limits (1,2) double
        deltaPixels (1,1) double
        axisLengthPixels (1,1) double {mustBeNonzero}
    end

    change = diff(limits) .* deltaPixels ./ axisLengthPixels;
    limits = [limits(1) - change, limits(2) + change];
end
