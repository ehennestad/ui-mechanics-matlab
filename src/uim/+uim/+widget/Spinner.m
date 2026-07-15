classdef Spinner < uim.abstract.Control
%Spinner A numeric value control with increment/decrement buttons
%
%   spinner = uim.widget.Spinner(hParent) creates a spinner in hParent
%   (a figure, panel, axes or uim canvas).
%
%   spinner = uim.widget.Spinner(hParent, Name, Value, ...) also sets
%   property values, for example:
%
%       spinner = uim.widget.Spinner(hAxes, 'Value', 5, ...
%           'Minimum', 0, 'Maximum', 10, 'Step', 1, ...
%           'ValueChangedFcn', @(src, evt) disp(evt.NewValue));
%
%   Clicking the -/+ buttons steps the value by Step; clicking the value
%   itself opens a temporary edit box (when Editable is 'on') for typing
%   a new value. User interactions are clamped to [Minimum, Maximum] and
%   notify the host through ValueChangedFcn with a
%   uim.event.ValueChangedEventData (OldValue/NewValue). Programmatic
%   assignment to Value updates the display without firing the callback
%   (push model: the host owns the state it pushes).
%
%   Note: the edit box is a classic uicontrol; direct editing requires a
%   figure that supports uicontrol (traditional figures, or uifigures in
%   recent MATLAB releases). The -/+ buttons work everywhere.

    properties (Constant) % Inherited from Component
        Type = 'Spinner'
    end

    properties
        Value (1,1) double = 0
        Step (1,1) double {mustBePositive} = 1
        Minimum (1,1) double = -inf
        Maximum (1,1) double = inf
        Format (1,:) char = '%g'    % sprintf-style format for the displayed value
        Editable (1,:) char {mustBeMember(Editable, {'on', 'off'})} = 'on'

        ValueChangedFcn = []        % Fired on user interaction. (src, uim.event.ValueChangedEventData)

        FontName = 'helvetica'
        FontSize = 12
    end

    properties (Access = protected, Transient)
        ValueText = gobjects(0,1)
        DecrementButton = gobjects(0,1)
        IncrementButton = gobjects(0,1)
        EditBox = gobjects(0,1)
    end

    methods % Structors

        function obj = Spinner(hParent, varargin)

            obj@uim.abstract.Control(hParent, varargin{:})

            obj.plotSpinnerComponents()

            obj.IsConstructed = true;

            obj.updateValueText()
            obj.onVisibleChanged()
        end

        function delete(obj)
            deleteValidHandles([obj.ValueText, ...
                obj.DecrementButton, obj.IncrementButton])

            if ~isempty(obj.EditBox) && isvalid(obj.EditBox)
                delete(obj.EditBox)
            end
        end
    end

    methods % Set/Get

        function set.Value(obj, newValue)
            obj.Value = newValue;
            obj.updateValueText()
        end

        function set.Format(obj, newValue)
            obj.Format = newValue;
            obj.updateValueText()
        end
    end

    methods (Hidden, Access = protected)

        function plotSpinnerComponents(obj)

            obj.ValueText = obj.plotTextItem('', 'SpinnerValue');
            obj.ValueText.HorizontalAlignment = 'center';
            obj.ValueText.ButtonDownFcn = @(~, ~) obj.beginEdit();

            obj.DecrementButton = obj.plotTextItem('-', 'SpinnerDecrement');
            obj.DecrementButton.FontWeight = 'bold';
            obj.DecrementButton.ButtonDownFcn = @(~, ~) obj.applyStep(-1);

            obj.IncrementButton = obj.plotTextItem('+', 'SpinnerIncrement');
            obj.IncrementButton.FontWeight = 'bold';
            obj.IncrementButton.ButtonDownFcn = @(~, ~) obj.applyStep(1);

            obj.updateComponentLocations()
        end

        function hText = plotTextItem(obj, textString, tag)

            hText = text(obj.CanvasAxes, 0, 0, textString);
            hText.Interpreter = 'none';
            hText.Color = obj.ForegroundColor;
            hText.FontUnits = 'pixels';
            hText.FontName = obj.FontName;
            hText.FontSize = obj.FontSize;
            hText.VerticalAlignment = 'middle';
            hText.Tag = tag;
            hText.HitTest = 'on';
            hText.PickableParts = 'all';
        end

        function updateValueText(obj)
            if ~obj.IsConstructed || isempty(obj.ValueText); return; end
            obj.ValueText.String = sprintf(obj.Format, obj.Value);
        end

        function updateComponentLocations(obj)

            if isempty(obj.ValueText); return; end

            x0 = obj.Position(1);
            yCenter = obj.Position(2) + obj.Position(4)/2;
            width = obj.Position(3);

            obj.DecrementButton.Position(1:2) = ...
                [x0 + obj.Padding(1), yCenter];
            obj.IncrementButton.Position(1:2) = ...
                [x0 + width - obj.Padding(3), yCenter];
            obj.IncrementButton.HorizontalAlignment = 'right';
            obj.ValueText.Position(1:2) = [x0 + width/2, yCenter];
        end

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end

            obj.Background.Visible = obj.Visible;
            handles = [obj.ValueText, obj.DecrementButton, obj.IncrementButton];
            set(handles(isvalid(handles)), 'Visible', obj.Visible)
        end
    end

    methods (Access = private) % User interactions

        function applyStep(obj, direction)
            obj.applyValueFromUser(obj.Value + direction*obj.Step)
        end

        function applyValueFromUser(obj, newValue)
        %applyValueFromUser Clamp, update Value and notify the host

            newValue = min(max(newValue, obj.Minimum), obj.Maximum);

            oldValue = obj.Value;
            if newValue == oldValue; return; end

            obj.Value = newValue;

            if ~isempty(obj.ValueChangedFcn)
                evtData = uim.event.ValueChangedEventData(oldValue, newValue);
                obj.ValueChangedFcn(obj, evtData)
            end
        end

        function beginEdit(obj)
        %beginEdit Open a temporary edit box on top of the spinner

            if strcmp(obj.Editable, 'off'); return; end
            if ~isempty(obj.EditBox) && isvalid(obj.EditBox); return; end

            % The inherited uicontrol wrapper resolves the canvas to a
            % real graphics parent; getpixelposition gives the spinner's
            % rect in that same parent frame.
            obj.EditBox = obj.uicontrol('Style', 'edit', ...
                'String', sprintf(obj.Format, obj.Value), ...
                'Units', 'pixels', 'Position', obj.getpixelposition(), ...
                'Callback', @obj.finishEdit);

            uicontrol(obj.EditBox) % Give the edit box keyboard focus
        end

        function finishEdit(obj, src, ~)
        %finishEdit Apply the typed value and remove the edit box

            newValue = str2double(src.String);

            delete(src)
            obj.EditBox = gobjects(0,1);

            if ~isnan(newValue)
                obj.applyValueFromUser(newValue)
            end
        end
    end

    methods (Access = protected)

        function onStyleChanged(obj)
            onStyleChanged@uim.abstract.Component(obj)

            if obj.IsConstructed && ~isempty(obj.ValueText)
                handles = [obj.ValueText, ...
                    obj.DecrementButton, obj.IncrementButton];
                set(handles(isvalid(handles)), 'Color', obj.ForegroundColor)
            end
        end

        function onSizeChanged(obj, oldPosition, newPosition)
            onSizeChanged@uim.abstract.Control(obj, oldPosition, newPosition)
            obj.updateComponentLocations()
        end

        function relocate(obj, shift)
            relocate@uim.abstract.Control(obj, shift)
            obj.updateComponentLocations()
        end
    end

    methods (Static)

        function S = getTypeDefaults()
            S.IsFixedSize = [true, true];
            % Dark chip chrome so the control is visible on any plot.
            S.BackgroundColor = 'k';
            S.BackgroundAlpha = 0.6;
            S.CornerRadius = 3;
        end
    end
end

function deleteValidHandles(handleArray)
    delete(handleArray(isvalid(handleArray)))
end
