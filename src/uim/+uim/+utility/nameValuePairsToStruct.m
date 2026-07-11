function result = nameValuePairsToStruct(nameValuePairs)
%NAMEVALUEPAIRSTOSTRUCT Convert a cell array of name-value pairs to a struct.

    arguments
        nameValuePairs (1,:) cell
    end

    if isempty(nameValuePairs)
        result = struct();
        return
    end
    if mod(numel(nameValuePairs), 2) ~= 0
        error("uim:utility:nameValuePairsToStruct:InvalidPairs", ...
            "Name-value inputs must contain an even number of elements.")
    end

    names = string(nameValuePairs(1:2:end));
    if any(strlength(names) == 0)
        error("uim:utility:nameValuePairsToStruct:InvalidName", ...
            "Property names must be nonempty text values.")
    end

    values = nameValuePairs(2:2:end);
    result = cell2struct(values, cellstr(names), 2);
end
