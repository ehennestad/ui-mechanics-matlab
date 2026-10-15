classdef Handle < handle
%Handle Handle base class that hides the inherited handle methods
%
%   Inherit from uim.Handle instead of handle to keep the methods and
%   doc listings of a class short. It redeclares addlistener, listener,
%   notify, findobj, findprop and the relational operators (eq, ne, lt,
%   le, gt, ge) as Hidden, forwarding each call to handle. The methods
%   keep working as usual.
%
%   The redeclared methods are Sealed, so subclasses can not override
%   them.
%
%   See also handle

    %Overload matlab handle methods to hide them
    methods(Sealed, Hidden)

        function lh = addlistener(varargin)
            lh = addlistener@handle(varargin{:});
        end

        function eL = listener(varargin)
            eL = listener@handle(varargin{:});
        end

        function notify(varargin)
            notify@handle(varargin{:});
        end

        function Hmatch = findobj(varargin)
            Hmatch = findobj@handle(varargin{:});
        end

        function p = findprop(varargin)
            p = findprop@handle(varargin{:});
        end

        function TF = eq(varargin)
            TF = eq@handle(varargin{:});
        end

        function TF = ne(varargin)
            TF = ne@handle(varargin{:});
        end

        function TF = lt(varargin)
            TF = lt@handle(varargin{:});
        end

        function TF = le(varargin)
            TF = le@handle(varargin{:});
        end

        function TF = gt(varargin)
            TF = gt@handle(varargin{:});
        end

        function TF = ge(varargin)
            TF = ge@handle(varargin{:});
        end
    end
end
