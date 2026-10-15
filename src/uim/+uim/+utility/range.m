function result = range(values)
%range Difference between the largest and smallest values
%
%   result = uim.utility.range(values) returns max(values) - min(values)
%   for numeric values. For a matrix it works per column, as max and min
%   do, and returns a row vector.
%
%   Example:
%       uim.utility.range([1, 5; 4, 2])   % [3, 3]

    arguments
        values {mustBeNumeric}
    end

    result = max(values) - min(values);
end
