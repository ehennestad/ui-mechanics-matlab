function options = parseNameValue(defaults, nameValuePairs)
%PARSENAMEVALUE Apply supported name-value pairs to a defaults structure.

    arguments
        defaults (1,1) struct
    end
    arguments (Repeating)
        nameValuePairs
    end

    inputs = nameValuePairs;
    if numel(inputs) == 1 && iscell(inputs{1})
        inputs = inputs{1};
    end

    if numel(inputs) == 1 && isstruct(inputs{1})
        inputStruct = inputs{1};
        inputNames = intersect(fieldnames(defaults), fieldnames(inputStruct), "stable");
        inputs = reshape([inputNames.'; cellfun(@(name) inputStruct.(name), ...
            inputNames.', "UniformOutput", false)], 1, []);
    end

    parser = inputParser;
    parser.FunctionName = "UI Mechanics name-value parser";
    parser.KeepUnmatched = true;
    parser.PartialMatching = true;

    optionNames = fieldnames(defaults);
    for i = 1:numel(optionNames)
        parser.addParameter(optionNames{i}, defaults.(optionNames{i}));
    end

    parser.parse(inputs{:});
    options = orderfields(parser.Results, optionNames);
end
