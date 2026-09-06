function [dimension, value] = fittedIconDimension(iconAspectRatio, innerBoxSize, requestedSize)
%fittedIconDimension Which icon dimension to set, and to what, to fit a button
%
%   [dimension, value] = uim.control.internal.fittedIconDimension(...
%       iconAspectRatio, innerBoxSize, requestedSize) decides how an
%   aspect-locked icon is sized. With a requested size ([width, height],
%   NaN when unset) a landscape icon takes the requested width and a
%   portrait icon the requested height. Without one, the icon fills the
%   inner box ([width, height], the button minus its padding) along
%   whichever dimension limits it. dimension is 'width' or 'height'.

    arguments
        iconAspectRatio (1,1) double {mustBePositive}
        innerBoxSize (1,2) double
        requestedSize (1,2) double = [nan, nan]
    end

    if all(~isnan(requestedSize))
        if iconAspectRatio > 1
            dimension = 'width';
            value = requestedSize(1);
        else
            dimension = 'height';
            value = requestedSize(2);
        end
        return
    end

    boxAspectRatio = innerBoxSize(1) / innerBoxSize(2);
    if iconAspectRatio >= boxAspectRatio
        dimension = 'width';
        value = innerBoxSize(1);
    else
        dimension = 'height';
        value = innerBoxSize(2);
    end
end
