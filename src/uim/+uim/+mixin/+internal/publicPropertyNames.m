function propertyNames = publicPropertyNames(obj)
%publicPropertyNames Names of the properties that get can read
%
%   propertyNames = uim.mixin.internal.publicPropertyNames(obj) returns a
%   cell array with the names of the properties of obj that have public
%   GetAccess and are not Hidden. get reads only public properties, so
%   toStruct uses this list.

    arguments
        obj % An object or object array; all elements share one class
    end

    mc = metaclass(obj);
    propertyList = mc.PropertyList;
    isReadable = arrayfun(@(p) isequal(p.GetAccess, 'public') && ~p.Hidden, propertyList);
    propertyNames = {propertyList(isReadable).Name};
end
