function options = parseNameValue(defaults, nameValuePairs)
%parseNameValue Apply name-value options to a struct of defaults
%
%   options = uim.utility.parseNameValue(defaults, Name1, Value1, ...)
%   returns defaults with each field named in the pairs replaced by its
%   value. Names are matched to the fields of defaults without regard to
%   case and may be abbreviated to any unique prefix. Names that match no
%   field are ignored. The output has the fields of defaults, in the same
%   order.
%
%   options = uim.utility.parseNameValue(defaults, nameValueCell) takes
%   the pairs as one cell array.
%
%   options = uim.utility.parseNameValue(defaults, optionsStruct) takes
%   the values from the fields of optionsStruct that have exactly the
%   name of a field in defaults; other fields are ignored.
%
%   Example:
%       defaults = struct("Color", "k", "LineWidth", 1);
%       opts = uim.utility.parseNameValue(defaults, "linew", 2)
%
%   Malformed pairs raise the inputParser error.
%
%   See also inputParser

    arguments
        defaults (1,1) struct
    end
    arguments (Repeating)
        nameValuePairs
    end

    inputs = nameValuePairs;
    if isscalar(inputs) && iscell(inputs{1})
        inputs = inputs{1};
    end

    if isscalar(inputs) && isstruct(inputs{1})
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
