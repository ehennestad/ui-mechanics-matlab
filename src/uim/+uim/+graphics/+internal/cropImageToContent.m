function imageData = cropImageToContent(imageData, backgroundValue)
%cropImageToContent Trim the background border around the content of an image
%
%   imageData = uim.graphics.internal.cropImageToContent(imageData, ...
%       backgroundValue) removes rows and columns at the edges whose
%   first channel equals backgroundValue (default 255, white), keeping
%   a one-pixel background margin around the content. An image with no
%   content is returned unchanged.

    arguments
        imageData
        backgroundValue (1,1) double = 255
    end

    isContent = imageData(:, :, 1) ~= backgroundValue;
    if ~any(isContent(:))
        return
    end

    rows = find(any(isContent, 2));
    columns = find(any(isContent, 1));

    rowRange = [max(rows(1) - 1, 1), min(rows(end) + 1, size(imageData, 1))];
    columnRange = [max(columns(1) - 1, 1), min(columns(end) + 1, size(imageData, 2))];

    imageData = imageData(rowRange(1):rowRange(2), columnRange(1):columnRange(2), :);
end
