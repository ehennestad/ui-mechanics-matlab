function data = circularSmooth(data, windowSize, method)
%CIRCULARSMOOTH Smooth a vector using circular boundary padding.

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
