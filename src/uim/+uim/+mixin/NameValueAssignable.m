classdef NameValueAssignable < uim.Handle & matlab.mixin.SetGet
%NameValueAssignable Mixin that assigns name-value pairs to properties
%
%   Subclasses call obj.parseInputs(varargin{:}) in their constructor to
%   assign name-value pairs to properties. Most uim components and
%   widgets get their Name=Value construction syntax from this class.
%
%   Contract for subclasses:
%       - Call parseInputs(obj, Name1, Value1, ...) from the constructor.
%         Values are assigned to public, settable, non-transient
%         properties in the order the properties appear in the class
%         metadata, not in argument order. Names that match no such
%         property are ignored without an error.
%         Names are case-sensitive.
%       - Optionally override the static, protected method
%         getDefaultPropertyValues to return a struct of default values.
%         These are merged in before the caller's name-value pairs, which
%         take precedence.
%
%   Methods:
%       toStruct   - Property values as a struct
%       fromStruct - Not implemented; does nothing
%
%   See also uim.abstract.Component

%   Todo: implement fromStruct method...

    methods (Access = protected)

        function parseInputs(obj, varargin)
        %parseInputs Assign name-value pairs to public properties
        %
        %   obj.parseInputs(Name1, Value1, ...) merges the pairs into the
        %   defaults from getDefaultPropertyValues and assigns the result to
        %   public, settable, non-transient properties (see class help).

            % NOTE! It is important that the varargin inputs are set to
            % property values after default because some properties depend
            % on each other.

            % NOTE2. No idea why I use utility.parsenvpairs here. Is it
            % just something I did for speed, but which creates problem
            % with dependent properties??

            nvPairs = obj.addComponentDefaultValues(varargin);

            mc = metaclass(obj);

            % Find all public & non transient properties
            isTransient = [ mc.PropertyList.Transient ];
            isPublic = strcmp( { mc.PropertyList.SetAccess }, 'public');

            keep = ~isTransient & isPublic;

            % Get names of the properties to keep.
            propArray = mc.PropertyList(keep);
            propertyNames = {propArray.Name};

            S = uim.mixin.internal.nameValuePairsToStruct(nvPairs);

            % Only set varargins...

            for i = 1:numel(propertyNames)
                if isfield(S, propertyNames{i})
                    obj.(propertyNames{i}) = S.(propertyNames{i});
                end
            end
        end

        function varargout = addComponentDefaultValues(obj, cellOfArgin)
        %addComponentDefaultValues Merge name-value pairs into the defaults
        %
        %   C = obj.addComponentDefaultValues(nameValueCell) returns the
        %   defaults from getDefaultPropertyValues, overridden by the pairs
        %   in nameValueCell, as one name-value cell array.

            % Question: Are subclass defaults overriding superclass
            % defaults now?

            S = obj.getDefaultPropertyValues;

            propNames = cellOfArgin(1:2:end);
            propValues = cellOfArgin(2:2:end);

            for i = 1:numel(propNames)
                S.(propNames{i}) = propValues{i};
            end

            C = cat(1, fieldnames(S)', struct2cell(S)');
            C = C(:)';

            varargout = {C};

            %parseInputs@uim.mixin.NameValueAssignable(obj, C{:})
        end
    end

    methods (Static, Access = protected)

        function S = getDefaultPropertyValues()
        %getDefaultPropertyValues Default property values for parseInputs
        %
        %   S = getDefaultPropertyValues() returns a struct whose fields
        %   are property names. This implementation returns an empty
        %   struct; subclasses may override it.
            S = struct;
        end
    end

    methods

        function S = toStruct(obj)
        %toStruct Property values as a struct
        %
        %   S = obj.toStruct() reads every public, non-Hidden property,
        %   including Dependent ones, with get and returns them as struct
        %   fields.

            propertyNames = uim.mixin.internal.publicPropertyNames(obj);
            values = get(obj, propertyNames);
            S = cell2struct(values, propertyNames, 2);
        end

        function fromStruct(obj)
        %fromStruct Not implemented; does nothing
        end

% % %         function saveobj()
% % %
% % %         end
    end
end
