classdef StructConvertible < uim.Handle & matlab.mixin.SetGet
%StructConvertible Mixin for struct export and option parsing
%
%   Subclasses get toStruct, which returns the property values as a
%   struct, and a protected parseInputs, which initializes properties
%   from name-value pairs, a cell array of pairs, or a struct.
%
%   Contract for subclasses:
%       - Call parseInputs(obj, varargin{:}) from the constructor. It
%         assigns every property that is not Transient: the property
%         default value, replaced by a matching input when one is given.
%         Every non-transient property therefore needs a default value
%         and must be settable from the class. Inputs are matched with
%         uim.utility.parseNameValue: names are case-insensitive, may be
%         abbreviated, and unknown names are ignored.
%       - Mark a property Hidden to leave it out of toStruct. toStruct
%         selects properties by the Hidden attribute while parseInputs
%         selects them by the Transient attribute.
%
%   Methods:
%       toStruct - Property values as a struct (object arrays allowed)
%
%   See also uim.mixin.NameValueAssignable, uim.utility.parseNameValue

%   Todo:
%       2) apply on children objects as well.
%       3) remove point 2 from list above. if there is no default property
%       value, this class should just assume it is empty.

% NB: Need to resolve the discrepancy with using transient attribute in
% parser and hidden attribute in toStruct.

    methods (Access = protected)

        function parseInputs(obj, varargin)
        %parseInputs Assign defaults and options to non-transient properties
        %
        %   obj.parseInputs(Name1, Value1, ...), obj.parseInputs(nvCell)
        %   or obj.parseInputs(optionsStruct) assigns each non-transient
        %   property its default value or the matching input (see class
        %   help).

            mc = metaclass(obj);

            % Get all property names
            propertyNames = {mc.PropertyList.Name};
            isTransient = [mc.PropertyList.Transient];
            propertyNames = propertyNames(~isTransient);

            % todo:
%             hasDefault = [mc.PropertyList.HasDefault];
%             defaultValues = cell(1, sum(isTransient));

            % Get default values.
            defaultValues = {mc.PropertyList(~isTransient).DefaultValue};
            S = cell2struct(defaultValues, propertyNames, 2);
            S = uim.utility.parseNameValue(S, varargin{:});

            for i = 1:numel(propertyNames)
                obj.(propertyNames{i}) = S.(propertyNames{i});
            end
        end
    end

    methods

        function S = toStruct(obj)
        %toStruct Property values as a struct
        %
        %   S = obj.toStruct() returns one struct element per object in
        %   obj, with a field for every property that is not Hidden.
        %   Property values that are themselves StructConvertible objects
        %   are converted with their own toStruct. Only public properties
        %   are read.

            propertyNames = uim.mixin.internal.publicPropertyNames(obj);

            % Get all values for these properties
            values = get(obj, propertyNames);

            % Assign names and values to a struct.
            S = cell2struct(values, propertyNames, 2);

            % Check if any of the properties are instances of the
            % structAdatpter class.

            for iProp = 1:numel(propertyNames)
                thisProp = propertyNames{iProp};
                for jInstance = 1:numel(S)
                    if isa( S(jInstance).(thisProp), 'uim.mixin.StructConvertible' )
                        S(jInstance).(thisProp) = S(jInstance).(thisProp).toStruct();
                    end
                end
            end
        end

% % %         function saveobj()
% % %
% % %         end
    end
end
