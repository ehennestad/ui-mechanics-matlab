classdef Box < uim.abstract.Control
%Box A decorative background box.

    properties (Constant)
        Type = 'Box'
    end

    methods % Structors
        function obj = Box(varargin)

            obj@uim.abstract.Control(varargin{:})

            obj.IsConstructed = true;
        end
    end

    methods (Access = protected)
        function updateSize(obj, mode)
            if nargin < 2; mode = obj.PositionMode; end
            updateSize@uim.abstract.Component(obj, mode)
            obj.resize()
        end
    end
end
