classdef TabBar < uim.widget.Toolbar
%TabBar Toolbar variant with short, light separators
%
%   A uim.widget.Toolbar whose addSeparator draws a short, thin, light
%   grey line centred on the button row instead of the toolbar's default
%   separator. Everything else, including construction, options
%   and addButton, is inherited from uim.widget.Toolbar.
%
%   tabBar = uim.widget.TabBar(parent)
%   tabBar = uim.widget.TabBar(parent, Name=Value)
%
%   Unlike Toolbar.addSeparator, TabBar.addSeparator takes no options
%   and returns no output.
%
%   See also uim.widget.Toolbar

    % Todo: Create customized versions for addButton and addSeparator
    % methods

    % Automatically fit button size to extent of text.

    methods

        function obj = TabBar(hParent, propertyValues)
        %TabBar Create an empty tab bar
        %
        %   tabBar = uim.widget.TabBar(parent, Name=Value) accepts the same
        %   parents and options as uim.widget.Toolbar.

            arguments
                hParent
                propertyValues.?uim.widget.TabBar
                propertyValues.CanvasMode
            end

            toolbarArgs = namedargs2cell(propertyValues);
            obj@uim.widget.Toolbar(hParent, toolbarArgs{:})
        end

        function addSeparator(obj)
        %addSeparator Add a short separator at the end of the tab bar
        %
        %   tabBar.addSeparator() adds a uim.decorator.Separator after the
        %   last button: a light grey line with LineWidth 0.5 in a
        %   10-pixel-high slot, centred vertically on the button row.

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
