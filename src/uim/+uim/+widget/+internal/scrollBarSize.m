function barSize = scrollBarSize(trackSizePixels, orientation, visibleAmount, maximum, barWidth)
%scrollBarSize Pixel size of a scrollbar's bar for the visible fraction
%
%   barSize = uim.widget.internal.scrollBarSize(trackSizePixels, ...
%       orientation, visibleAmount, maximum, barWidth) returns the rounded
%   [width, height] of the bar. Along the scroll direction the bar covers
%   visibleAmount/maximum of the track, but never less than barWidth so a
%   long document still leaves something to grab. Across the scroll
%   direction the bar is barWidth pixels.

    arguments
        trackSizePixels (1,2) double
        orientation {mustBeTextScalar}
        visibleAmount (1,1) double {mustBeNonnegative}
        maximum (1,1) double {mustBePositive}
        barWidth (1,1) double {mustBePositive}
    end

    switch lower(char(orientation))
        case 'horizontal'
            barLength = trackSizePixels(1) .* visibleAmount ./ maximum;
            barSize = [max(barLength, barWidth), barWidth];
        case 'vertical'
            barLength = trackSizePixels(2) .* visibleAmount ./ maximum;
            barSize = [barWidth, max(barLength, barWidth)];
        otherwise
            error("uim:scrollBarSize:InvalidOrientation", ...
                "Orientation must be 'horizontal' or 'vertical'; got ""%s"".", ...
                char(orientation))
    end

    barSize = round(barSize);
end
