function propertyNames = findProperties(objectOrClassName, attributeName, attributeValue)
%findProperties Names of class properties, optionally filtered by an attribute
%
%   propertyNames = uim.utility.findProperties(objectOrClassName) returns
%   the names of all properties of an object or of the class named by a
%   character vector or string, as a 1-by-n cell array of character
%   vectors in class metadata order.
%
%   propertyNames = uim.utility.findProperties(objectOrClassName,
%   attributeName) returns the properties whose meta.property attribute
%   attributeName (for example "Transient" or "Dependent") is true.
%
%   propertyNames = uim.utility.findProperties(objectOrClassName,
%   attributeName, attributeValue) returns the properties whose attribute
%   equals attributeValue, for example "SetAccess" and "public".
%
%   Errors:
%       uim:findProperties:InvalidInput     - Input is not an object or
%                                             class name
%       uim:findProperties:InvalidAttribute - attributeName is not a
%                                             meta.property attribute,
%                                             or the class has no
%                                             properties
%
%   See also metaclass, meta.property

    arguments
        objectOrClassName
        attributeName (1,1) string = ""
        attributeValue = true
    end

    if ischar(objectOrClassName) || isstring(objectOrClassName)
        metaClass = meta.class.fromName(char(objectOrClassName));
    elseif isobject(objectOrClassName)
        metaClass = metaclass(objectOrClassName);
    else
        error("uim:findProperties:InvalidInput", ...
            "Input must be an object or class name.")
    end

    propertyList = metaClass.PropertyList;
    propertyNames = {propertyList.Name};
    if attributeName == ""
        return
    end

    attributeName = char(attributeName);
    if isempty(propertyList) || ~isprop(propertyList(1), attributeName)
        error("uim:findProperties:InvalidAttribute", ...
            "'%s' is not a property metadata attribute.", attributeName)
    end

    firstValue = propertyList(1).(attributeName);
    if islogical(firstValue)
        isMatch = [propertyList.(attributeName)] == attributeValue;
    else
        attributeValues = {propertyList.(attributeName)};
        isMatch = cellfun(@(value) isequal(value, attributeValue), attributeValues);
    end

    propertyNames = propertyNames(isMatch);
end
