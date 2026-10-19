classdef ResizableStub < uim.mixin.Resizable
%ResizableStub Minimal concrete uim.mixin.Resizable for tests
%
%   stub = ResizableStub(hAxes, position) gives a Resizable whose Parent is
%   hAxes and whose Position is position, in data units of hAxes. It draws
%   nothing; it exists to test the methods the mixin implements.

    properties
        Position % [x, y, width, height] in data units of Parent
    end

    methods
        function obj = ResizableStub(hAxes, position)
            obj.Parent = hAxes;
            obj.Position = position;
        end
    end

    methods (Access = protected)
        function setDefaultButtonDownFcn(~, ~)
            % Not needed: the stub creates no interactive rectangle
        end

        function resize(~, ~)
            % Not needed: the stub draws nothing
        end
    end
end
