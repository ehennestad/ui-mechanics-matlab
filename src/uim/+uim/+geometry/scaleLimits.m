function limits = scaleLimits(limits, zoomFactor)
%scaleLimits Grow or shrink a [min, max] interval about its centre
%
%   limits = uim.geometry.scaleLimits(limits, zoomFactor) moves
%   each end outwards by zoomFactor times the interval width, so a
%   positive zoomFactor zooms out and a negative one zooms in
%   (zoomFactor -0.25 halves the width; 0.5 doubles it).

    arguments
        limits (1,2) double
        zoomFactor (1,1) double
    end

    limits = limits + [-1, 1] .* zoomFactor .* diff(limits);
end
