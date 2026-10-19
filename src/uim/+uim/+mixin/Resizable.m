classdef Resizable < uim.Handle
%Resizable Mixin for an object moved and resized with an interactive rectangle
%
%   Gives a subclass an imrect (Image Processing Toolbox) that the user
%   drags to move or resize the object in an axes. When the rectangle
%   changes, the object's Position is updated, the subclass resize method
%   runs, Children are rescaled to follow, and SizeChangedFcn is called.
%   uim.widget.MessageBox uses this mixin.
%
%   Contract for subclasses:
%       - Define the Position property ([x, y, width, height] in the
%         units of the Parent axes).
%       - Implement the protected methods
%             setDefaultButtonDownFcn(obj, fcnHandle), called when
%                 DefaultButtonDownFcn is set, and
%             resize(obj, newPosition, oldPosition), called after
%                 Position is updated from the rectangle.
%       - Set Parent (the axes) before calling createInteractiveRectangle.
%
%   Children must be objects with a Position property and a
%   setPosition(position, mode) method, for example other Resizable
%   objects.
%
%   See also uim.widget.MessageBox

% Todo:
%   [ ] Generalize so that it can be used on any object that implements a
%       position property. Especially virtual containers?
%   [ ] Update references in different apps/scripts/functions

    properties (Abstract)
        Position % [x, y, width, height] of the object; subclasses define it
    end

    properties
        % Objects rescaled with this one when it is moved or resized.
        Children = []            % Should maybe not be transient
        IsMovable = true % When true, showInteractiveRectangle makes the rectangle respond to clicks.
        IsResizable = true % When true, showInteractiveRectangle shows the resize handles.
    end

    properties (Hidden, Transient)
        Parent              % (InteractionAxes) % should be protected and hidden....
        SizeChangedFcn      % Function handle. Function must accept two inputs (newPosition, oldPosition)
        DefaultButtonDownFcn = []
        ResizeButtonDownFcn = []
    end

    properties (Hidden, Transient, Access = protected)
        PickableParts = 'all'; % When visible... Is set to none when invisible.
        ImrectCallbacks = [];
        RectDestroyedListener = event.listener.empty
        IsConstructed = false;
    end

    properties (Hidden, Transient, Access = public)
        InteractiveRectangle
    end

    methods (Abstract, Access = protected)
        setDefaultButtonDownFcn(obj, fcnHandle)
        resize(obj, pos)
    end

    methods

        function delete(obj)
            for i = numel(obj.Children):-1:1
                delete(obj.Children(i))
            end

            if ~isempty(obj.InteractiveRectangle) && isvalid(obj.InteractiveRectangle)
                delete(obj.InteractiveRectangle)
            end
        end

        function createInteractiveRectangle(obj)
        %createInteractiveRectangle Create the imrect that moves the object
        %
        %   obj.createInteractiveRectangle() replaces any existing
        %   rectangle with an imrect at Position in the Parent axes.
        %   Deleting the rectangle deletes the object.

            % Make an imrect for interactively moving and resizing the
            % virtualPanel.

            if ~isempty(obj.InteractiveRectangle)
                delete(obj.InteractiveRectangle)
            end

            hRect = imrect(obj.Parent, obj.Position);

            hRect.setColor([0.7608    0.6471    0.8118]) %obj.rectColors.Default)
            hRect.addNewPositionCallback(@(pos) obj.onSizeChanged(pos));

            el = addlistener(hRect, 'ObjectBeingDestroyed', @(src,evt) delete(obj));
            obj.RectDestroyedListener = el;

            % todo: work on this....
% % %             hFunc = makeConstrainToRectFcn('imrect', obj.margins([1,3]), obj.margins([2,4]));
% % %             hRect.setPositionConstraintFcn(hFunc);

% % %             % Modify button down to also run mousepress callback.
% % %             ptmp = findobj(hRect,'Type', 'patch');
% % %             funhandle = ptmp.ButtonDownFcn;
% % %             set(ptmp, 'ButtonDownFcn', {@obj.mousePressed, funhandle, 'interior'} )
% % %
% % %             ctmp = findobj(hRect, '-regexp', 'Tag', 'corner');
% % %             set(ctmp, 'ButtonDownFcn', {@obj.mousePressed, ctmp(1).ButtonDownFcn, 'corner'} );
% % %
% % %             ltmp = findobj(hRect, '-regexp', 'Tag', 'top line');
% % %             set(ltmp, 'ButtonDownFcn', {@obj.mousePressed, ltmp(1).ButtonDownFcn, 'side'} );

            % set all context menus for the underlying line and patch objects

% % %             % Edit the context menu of the rectangle. TODO: Add customs..
% % %             hComp = findobj(hRect, 'Type', 'line', '-or', 'Type', 'patch');
% % %
% % %             cmHandle = obj.configContextMenu(hComp(1).UIContextMenu);
% % %             set(hComp, 'uicontextmenu', cmHandle);

            obj.InteractiveRectangle = hRect;
         end

        function hideInteractiveRectangle(obj)
        %hideInteractiveRectangle Hide the rectangle and stop it taking clicks
            if isempty(obj.InteractiveRectangle); return; end

            imrectGroup = findobj(obj.InteractiveRectangle, ...
                'Type', 'hggroup', 'Tag', 'imrect');
            set(imrectGroup, 'Visible', 'off');

            pTmp = findobj(obj.InteractiveRectangle, 'Type', 'patch');
            pTmp.HitTest = 'off';
            pTmp.PickableParts = 'none';
        end

        function showInteractiveRectangle(obj)
        %showInteractiveRectangle Show the rectangle and its handles
        %
        %   The resize handles are shown only when IsResizable is true. The
        %   rectangle takes clicks when IsMovable or IsResizable is true.
            if isempty(obj.InteractiveRectangle); return; end

            if obj.IsResizable
                imrectGroup = findobj(obj.InteractiveRectangle, ...
                    'Type', 'hggroup', 'Tag', 'imrect');
                set(imrectGroup, 'Visible', 'on');
            end

            if obj.IsMovable || obj.IsResizable
                pTmp = findobj(obj.InteractiveRectangle, 'Type', 'patch');
                pTmp.HitTest = 'on';
                pTmp.PickableParts = obj.PickableParts;
            end
        end

        function setPositionConstraintFcn(obj, hFunc)
        %setPositionConstraintFcn Set the imrect position constraint function
        %
        %   obj.setPositionConstraintFcn(fcn) passes fcn to the imrect
        %   method of the same name.
            obj.InteractiveRectangle.setPositionConstraintFcn(hFunc);
        end

        function setPosition(obj, newPosition, mode)
        %setPosition Move the rectangle, and with it the object
        %
        %   obj.setPosition(newPosition) moves the rectangle to
        %   newPosition ([x, y, width, height]) within its position
        %   constraint. obj.setPosition(newPosition, "unconstrained")
        %   ignores the constraint. Any other mode does nothing.

            if nargin < 3 || isempty(mode)
                mode = 'constrained';
            end

            if strcmp(mode, 'constrained')
                obj.InteractiveRectangle.setConstrainedPosition(newPosition)
            elseif strcmp(mode, 'unconstrained')
                obj.InteractiveRectangle.setPosition(newPosition)
            end
        end

        function setColor(obj, newColor)
        %setColor Set color of imrect
            obj.InteractiveRectangle.setColor(newColor)
        end

        function pos = getPosition(obj)
        %getPosition Current [x, y, width, height] of the rectangle
            pos = obj.InteractiveRectangle.getPosition();
        end

        function lim = getPositionLimits(obj)
        %getPositionLimits Position as corner coordinates [x1, y1, x2, y2]
            lim = obj.Position([1,2,1,2]) + [0, 0, obj.Position(3:4)];
        end

        function pixelpos = getpixelposition(obj, recursive)
        %getpixelposition Return the position in pixels
        %
        %   pixelpos = obj.getpixelposition() converts Position, which is
        %   in data units of the Parent axes, to [x, y, width, height] in
        %   pixels from the lower-left corner of that axes.
        %
        %   pixelpos = obj.getpixelposition(true) returns the pixels
        %   relative to the figure instead.
        %
        %   See also uim.utility.du2px
            if nargin < 2; recursive = false; end

            corners = [obj.Position(1:2); obj.Position(1:2) + obj.Position(3:4)];
            corners = uim.utility.du2px(obj.Parent, corners, recursive);
            % A reversed axis direction swaps the corners
            pixelpos = [min(corners, [], 1), abs(diff(corners, 1, 1))];
        end

        function hArray = getImrectHandles(obj)
        %getImrectHandles Line and patch objects that make up the rectangle
            hArray = findobj( obj.InteractiveRectangle, ...
                                'Type', 'line', '-or', 'Type', 'patch');
        end

        function set.ResizeButtonDownFcn(obj, newFunc)
            obj.configNewResizeButtonDownFcn(newFunc)
            obj.ResizeButtonDownFcn = newFunc;
        end

        function set.DefaultButtonDownFcn(obj, newValue)
            obj.DefaultButtonDownFcn = newValue;

            % Call subclass method
            obj.setDefaultButtonDownFcn(newValue)
        end

        function resizeChildren(obj, newPosition, oldPosition)
        %resizeChildren Rescale Children from the old to the new position
        %
        %   obj.resizeChildren(newPosition, oldPosition) maps each child's
        %   Position from oldPosition to newPosition and applies it with
        %   setPosition(..., "unconstrained"). A resize made while the
        %   figure SelectionType is 'extend' leaves the children unchanged.

            hFig = ancestor(obj.Parent, 'figure');

            oldLim = [oldPosition(1:2), oldPosition(1:2) + oldPosition(3:4)];
            newLim = [newPosition(1:2), newPosition(1:2) + newPosition(3:4)];

            % Calculate normalized change in position and size of panels
            % based on change in the canvas.
            dW = (diff(newLim([1,3])) - diff(oldLim([1,3]))) / diff(oldLim([1,3]));
            dH = (diff(newLim([2,4])) - diff(oldLim([2,4]))) / diff(oldLim([2,4]));

            %fprintf('dH: %g, dW: %g\n', dH, dW)
            isResized = abs(dH) > 1e-9 || abs(dW) > 1e-9; % Take care of imprecision

            if isResized && strcmp(hFig.SelectionType, 'extend'); return; end

            %xLim = [newPosition(1), sum(newPosition([1,3]))];
            %yLim = [newPosition(2), sum(newPosition([2,4]))];
            %fcn = makeConstrainToRectFcn('imrect', xLim, yLim);

            for i = 1:numel(obj.Children)
                childPosition = uim.mixin.internal.rescaleChildPosition(...
                    obj.Children(i).Position, oldPosition, newPosition);
                obj.Children(i).setPosition(childPosition, 'unconstrained')
            end
        end
    end

    methods (Access = protected)

        % Work in progress.
        function onSizeChanged(obj, newPosition)
        %onSizeChanged

            oldPosition = obj.Position;

            % Assign new position to the position property. Do this before
            % calling the resize method, because this method will depend on
            % the position property.
            obj.Position = newPosition;

            % Call the resize method. This is an abstract method, so each
            % subclass will have its own implementation
            obj.resize(newPosition, oldPosition)

            if ~isempty(obj.Children)
                obj.resizeChildren(newPosition, oldPosition)
            end

            if ~isempty(obj.SizeChangedFcn)
                obj.SizeChangedFcn(newPosition, oldPosition)
            end
        end

        function configNewResizeButtonDownFcn(obj, newFunc)
        %configNewResizeButtonDownFcn

            if isempty(obj.InteractiveRectangle); return; end

            pTmp = findobj(obj.InteractiveRectangle, 'Type', 'patch');
            cTmp = findobj(obj.InteractiveRectangle, '-regexp', 'Tag', 'corner');
            lTmp = findobj(obj.InteractiveRectangle, '-regexp', 'Tag', 'top line');

            if isempty(obj.ImrectCallbacks)
                obj.ImrectCallbacks = {pTmp.ButtonDownFcn, ...
                    cTmp(1).ButtonDownFcn, lTmp(1).ButtonDownFcn};
            end

            set(pTmp, 'ButtonDownFcn', {newFunc, obj.ImrectCallbacks{1}, obj, 'interior'} )
            set(cTmp, 'ButtonDownFcn', {newFunc, obj.ImrectCallbacks{2}, obj, 'corner'} );
            set(lTmp, 'ButtonDownFcn', {newFunc, obj.ImrectCallbacks{3}, obj, 'side'} );
        end
    end

    methods (Static)

        function BW = rect2mask(rectCoords, maskSize)
        %rect2mask Logical mask of a normalized rectangle
        %
        %   BW = uim.mixin.Resizable.rect2mask(rectCoords, maskSize)
        %   returns a maskSize(2)-by-maskSize(1) logical array that is true
        %   inside rectCoords. rectCoords is [x, y, width, height] as
        %   fractions of maskSize ([width, height] in pixels); x indexes
        %   columns and y indexes rows from the top. Corners are rounded to
        %   whole pixels and clipped to the mask, and both end pixels are
        %   included.

            maskSize = round(maskSize);

            BW = false(maskSize(2), maskSize(1));
            pos = round(rectCoords .* [maskSize, maskSize]);
            pos(3:4) = pos(1:2) + pos(3:4);

            pos(pos<1) = 1;
            if pos(3) > maskSize(1); pos(3)=maskSize(1); end
            if pos(4) > maskSize(2); pos(4)=maskSize(2); end

            BW(pos(2):pos(4), pos(1):pos(3)) = true;
        end
    end
end
