function limits = shiftLimitsInside(limits, extent)
%shiftLimitsInside Shift 2-D view limits inside an extent, never resizing them
%
%   limits = uim.geometry.internal.shiftLimitsInside(limits, extent)
%   translates each row of limits (2-by-2, [min, max] per dimension)
%   back inside the corresponding row of extent, without changing its
%   size. A window larger than the extent cannot fit; its two edge
%   corrections cancel to a net shift, so it ends up straddling the
%   extent.
%
%   This differs from uim.geometry.fitRangeInside, which narrows a range
%   that is too wide. Overview widgets rely on the size being preserved.
%
%   See also uim.geometry.fitRangeInside

    arguments
        limits (2,2) double
        extent (2,2) double
    end

    for dim = 1:2
        overshoot = max(0, extent(dim,1) - limits(dim,1)) ...
            - max(0, limits(dim,2) - extent(dim,2));
        limits(dim,:) = limits(dim,:) + overshoot;
    end
end
