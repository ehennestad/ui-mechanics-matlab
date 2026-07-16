classdef TabBar < uim.widget.Toolbar

    % Todo: Create customized versions for addButton and addSeparator
    % methods

    % Automatically fit button size to extent of text.

    methods

        function obj = TabBar(hParent, varargin)
            obj@uim.widget.Toolbar(hParent, varargin{:})
        end

        function addSeparator(obj)

            separatorPosition = obj.NextButtonPosition;
            % todo: switch orientation...

            separatorPosition(3) = 0;
            separatorPosition(4) = 10;
            separatorPosition(2) = obj.NextButtonPosition(2) + (obj.NextButtonPosition(4)-10)/2;

            varargin = {'Position', separatorPosition, ...
                        'Size', separatorPosition(3:4), ...
                        'Color', ones(1,3)*0.9, ...
                        'LineWidth', 0.5};

            hSep = uim.decorator.Separator(obj, varargin{:});

            % Add listener for SizeChanged event on button
            el = addlistener(hSep, 'SizeChanged', @obj.onButtonSizeChanged);
            obj.ButtonSizeChangedListener(end+1) = el;

            obj.AllButtonPosition(end+1, :) = hSep.Position;
            try
                obj.Buttons(end+1) = hSep;
            catch
                obj.Buttons = cat(2, obj.Buttons, hSep);
            end
            obj.NumButtons = obj.NumButtons+1;

            obj.adjustButtonPositions()
            obj.setNextButtonPosition()
        end
    end
end
