function propertyNames = findProperties(objectOrClassName, attributeName, attributeValue)
%FINDPROPERTIES Find class properties matching a metadata attribute.

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
        error("uim:utility:findProperties:InvalidInput", ...
            "Input must be an object or class name.")
    end

    propertyList = metaClass.PropertyList;
    propertyNames = {propertyList.Name};
    if attributeName == ""
        return
    end

    attributeName = char(attributeName);
    if isempty(propertyList) || ~isprop(propertyList(1), attributeName)
        error("uim:utility:findProperties:InvalidAttribute", ...
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
