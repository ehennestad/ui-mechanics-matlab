classdef Readout < uim.abstract.Control
%Readout A label + formatted-value chip for displaying live values
%
%   readout = uim.widget.Readout(hParent) creates a readout in hParent
%   (a figure, panel, axes or uim canvas).
%
%   readout = uim.widget.Readout(hParent, Name, Value, ...) also sets
%   property values, for example:
%
%       readout = uim.widget.Readout(hAxes, 'Label', 'Frame', ...
%           'Format', '%d', 'Location', 'southeast');
%       readout.Value = 42;   % Displays "Frame: 42"
%
%   The Value property accepts a numeric scalar (rendered with the
%   sprintf-style Format property) or text. When the inherited Label
%   property is nonempty, the displayed text is "<Label>: <value>".
%
%   The readout is display-only: it captures no mouse events beyond the
%   inherited tooltip behavior.

    properties (Constant) % Inherited from Component
        Type = 'Readout'
    end

    properties
        Value = []                  % Numeric scalar or text to display
        Format (1,:) char = '%g'    % sprintf-style format for numeric values

        FontName = 'helvetica'
        FontSize = 12
        FontWeight = 'normal'
    end

    properties (Dependent, Transient)
        String % The currently displayed text (read-only)
    end

    properties (Access = protected, Transient)
        TextHandle = gobjects(0,1)
    end

    methods % Structors

        function obj = Readout(hParent, varargin)

            obj@uim.abstract.Control(hParent, varargin{:})

            obj.plotValueText()

            obj.IsConstructed = true;

            obj.updateDisplayedText()
            obj.onVisibleChanged()
        end

        function delete(obj)
            if ~isempty(obj.TextHandle) && isvalid(obj.TextHandle)
                delete(obj.TextHandle)
            end
        end
    end

    methods % Set/Get

        function set.Value(obj, newValue)
            obj.Value = newValue;
            obj.updateDisplayedText()
        end

        function set.Format(obj, newValue)
            obj.Format = newValue;
            obj.updateDisplayedText()
        end

        function set.FontName(obj, value)
            obj.FontName = value;
            obj.onFontStyleChanged()
        end

        function set.FontSize(obj, value)
            obj.FontSize = value;
            obj.onFontStyleChanged()
        end

        function set.FontWeight(obj, value)
            obj.FontWeight = value;
            obj.onFontStyleChanged()
        end

        function value = get.String(obj)
            if isempty(obj.TextHandle)
                value = '';
            else
                value = obj.TextHandle.String;
            end
        end
    end

    methods (Hidden, Access = protected)

        function plotValueText(obj)

            obj.TextHandle = text(obj.CanvasAxes, 0, 0, '');
            obj.TextHandle.Interpreter = 'none';
            obj.TextHandle.Color = obj.ForegroundColor;
            obj.TextHandle.FontUnits = 'pixels';
            obj.TextHandle.FontName = obj.FontName;
            obj.TextHandle.FontSize = obj.FontSize;
            obj.TextHandle.FontWeight = obj.FontWeight;
            obj.TextHandle.VerticalAlignment = 'middle';
            obj.TextHandle.PickableParts = 'none';
            obj.TextHandle.HitTest = 'off';

            obj.updateTextLocation()
        end

        function updateDisplayedText(obj)

            if ~obj.IsConstructed || isempty(obj.TextHandle); return; end

            if isempty(obj.Value)
                valueText = '';
            elseif isnumeric(obj.Value)
                valueText = sprintf(obj.Format, obj.Value);
            else
                valueText = char(string(obj.Value));
            end

            if isempty(obj.Label)
                obj.TextHandle.String = valueText;
            else
                obj.TextHandle.String = sprintf('%s: %s', obj.Label, valueText);
            end

            obj.updateTextLocation()
        end

        function updateTextLocation(obj)

            if isempty(obj.TextHandle); return; end

            x = obj.Position(1) + obj.Padding(1);
            y = obj.Position(2) + obj.Position(4)/2;

            obj.TextHandle.Position(1:2) = [x, y];
        end

        function onFontStyleChanged(obj)

            if ~obj.IsConstructed || isempty(obj.TextHandle); return; end

            obj.TextHandle.FontName = obj.FontName;
            obj.TextHandle.FontSize = obj.FontSize;
            obj.TextHandle.FontWeight = obj.FontWeight;

            obj.updateTextLocation()
        end

        function onVisibleChanged(obj, ~)
            if ~obj.IsConstructed; return; end

            obj.Background.Visible = obj.Visible;
            if ~isempty(obj.TextHandle) && isvalid(obj.TextHandle)
                obj.TextHandle.Visible = obj.Visible;
            end
        end
    end

    methods (Access = protected)

        function onStyleChanged(obj)
            onStyleChanged@uim.abstract.Component(obj)

            if obj.IsConstructed && ~isempty(obj.TextHandle)
                obj.TextHandle.Color = obj.ForegroundColor;
            end
        end

        function onSizeChanged(obj, oldPosition, newPosition)
            onSizeChanged@uim.abstract.Control(obj, oldPosition, newPosition)
            obj.updateTextLocation()
        end

        function relocate(obj, shift)
            relocate@uim.abstract.Control(obj, shift)
            obj.updateTextLocation()
        end
    end

    methods (Static)

        function S = getTypeDefaults()
            S.IsFixedSize = [true, true];
            % Dark chip chrome so the readout is visible on any plot.
            S.BackgroundColor = 'k';
            S.BackgroundAlpha = 0.6;
            S.CornerRadius = 3;
            S.Padding = [8, 3, 8, 3]; % Text inset from the chip edges
        end
    end
end
