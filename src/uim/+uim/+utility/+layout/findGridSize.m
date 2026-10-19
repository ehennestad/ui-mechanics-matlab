function [nRows, nCols] = findGridSize(n, ~, fullAr)
%findGridSize Rows and columns of a landscape grid for n tiles
%
%   [nRows, nCols] = uim.utility.layout.findGridSize(n) returns a grid
%   whose aspect ratio nCols/nRows lies strictly between 4/3 and 16/9.
%   Only grids with at least two rows and two columns are considered.
%   When no such grid has exactly n tiles, n is increased until one does,
%   so the grid can have more tiles than n: findGridSize(6) gives 2-by-3,
%   findGridSize(7) gives 3-by-5, and every n from 1 to 6 gives 2-by-3.
%
%   [nRows, nCols] = uim.utility.layout.findGridSize(n, [], aspectRatio)
%   targets nCols/nRows within 0.2 of aspectRatio instead. The second
%   input is ignored.
%
%   Example:
%       [nRows, nCols] = uim.utility.layout.findGridSize(4, [], 1)  % 2, 2

if nargin < 3
    lowerlim = 4/3;
    upperlim = 16/9;
else
    upperlim = fullAr+0.2;
    lowerlim = fullAr-0.2;
end

% Candidate grids are divisor pairs [d, n/d] with 1 < d < n, where d is
% a product of at most half of the prime factors of n, ordered by d and
% followed by the same pairs flipped. The first pair whose aspect ratio
% lies within the limits is used.
while true

    factors = factor(n);

    if isscalar(factors)
        n = n + 1;
        continue
    end

    divisors = find(mod(n, 1:n) == 0);
    divisors = divisors(divisors > 1 & divisors < n);
    numDivisorFactors = arrayfun(@(d) numel(factor(d)), divisors);
    divisors = divisors(numDivisorFactors <= floor(numel(factors) / 2));

    candidates = [divisors(:), n ./ divisors(:)];
    candidates = vertcat(candidates, fliplr(candidates)); %#ok<AGROW> rebuilt for each n, not grown

    ratio = candidates(:,1) ./ candidates(:,2);
    hits = ratio < upperlim & ratio > lowerlim;

    if any(hits)
        candidates = candidates(hits, :);
        nCols = candidates(1, 1); nRows = candidates(1, 2);
        return
    end

    n = n + 1;
end
end
