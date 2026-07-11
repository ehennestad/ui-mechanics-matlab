function result = range(values)
%RANGE Return the difference between maximum and minimum values.

    arguments
        values {mustBeNumeric}
    end

    result = max(values) - min(values);
end
