function limits = clampLimitsToExtent(limits, extent)
%clampLimitsToExtent Shift a view window so it stays inside a data extent
%
%   limits = uim.widget.internal.clampLimitsToExtent(limits, extent)
%   translates each row of limits (2-by-2, [min, max] per dimension) back
%   inside the corresponding row of extent without changing its size. A
%   window larger than the extent cannot fit; its two edge corrections
%   cancel to a net shift, so it ends up straddling the extent.

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
