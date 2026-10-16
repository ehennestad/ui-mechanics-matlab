function data = circularSmooth(data, windowSize, method)
%circularSmooth Smooth a vector that wraps around at its ends
%
%   data = uim.utility.circularSmooth(data, windowSize) smooths data with a
%   moving mean over windowSize samples, treating the data as circular:
%   samples near one end are averaged with samples from the other end.
%   windowSize is a positive integer; a window longer than the data is
%   reduced to the data length. Row vectors stay row vectors; any other
%   shape is returned as a column vector. Empty data is returned as is.
%
%   data = uim.utility.circularSmooth(data, windowSize, method) uses
%   another smoothdata method, for example "movmedian" or "gaussian".
%
%   See also smoothdata

    arguments
        data {mustBeNumeric}
        windowSize (1,1) double {mustBeInteger, mustBePositive}
        method (1,1) string = "movmean"
    end

    if isempty(data)
        return
    end

    windowSize = min(windowSize, numel(data));
    wasRowVector = isrow(data);
    data = data(:);

    paddedData = [data(end-windowSize+1:end); data; data(1:windowSize)];
    paddedData = smoothdata(paddedData, 1, method, windowSize);
    data = paddedData(windowSize+1:end-windowSize);

    if wasRowVector
        data = data.';
    end
end
