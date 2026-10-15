classdef PointerToolBinding < handle
%PointerToolBinding Wire toolbar toggle buttons to pointer-tool modes
%
%   binding = uim.interface.PointerToolBinding(hToolbar, hPointerManager,
%   modes) adds one toggle button per mode to the toolbar and keeps the
%   buttons and the pointer tools in sync in both directions: clicking a
%   button toggles the corresponding tool, and toggling a tool by any
%   other means (keyboard shortcut, programmatic togglePointerMode, or
%   activation of a competing tool) updates the button states.
%
%   modes is a string array of mode keys that must exist in the pointer
%   manager's Pointers struct, e.g. ["zoomIn", "zoomOut", "pan"].
%
%   binding = uim.interface.PointerToolBinding(..., Name=Value) also
%   accepts:
%     Icons      - struct mapping a mode key to an icon (any value the
%                  Button Icon property accepts). Modes without an entry
%                  use the toolbox's shipped icon for that mode
%                  (uim.style.getDefaultIcons) when one exists, and the
%                  mode key as text otherwise.
%     Tooltips   - struct mapping a mode key to a tooltip string.
%                  Defaults to the mode key.
%     ButtonProps - cell array of additional Name-Value pairs forwarded
%                  to every created button (e.g. {'Style', ...}).
%
%   Deleting the binding removes the buttons it created. The binding
%   does not own the toolbar or the pointer manager.
%
%   Example:
%       manager = uim.interface.PointerManager(hFigure, hAxes, ...
%           {"zoomIn", "zoomOut", "pan"});
%       toolbar = uim.widget.Toolbar(hAxes, Location="northeast");
%       binding = uim.interface.PointerToolBinding(toolbar, manager, ...
%           ["zoomIn", "zoomOut", "pan"]);
%
%   An unknown mode raises uim:PointerToolBinding:UnknownMode.
%
%   See also uim.interface.PointerManager, uim.widget.Toolbar

    properties (SetAccess = private)
        Toolbar uim.widget.Toolbar % Toolbar that holds the buttons
        PointerManager uim.interface.PointerManager % Manager whose tools the buttons toggle
        Modes (1,:) string = string.empty % Tool keys, one per button, in button order
        Buttons uim.control.Button % Toggle buttons created by the binding, in Modes order
    end

    methods % Structors

        function obj = PointerToolBinding(hToolbar, hPointerManager, modes, options)
        %PointerToolBinding Add toggle buttons for pointer tools to a toolbar
        %
        %   binding = uim.interface.PointerToolBinding(hToolbar,
        %       hPointerManager, modes, Name=Value)

            arguments
                hToolbar (1,1) uim.widget.Toolbar
                hPointerManager (1,1) uim.interface.PointerManager
                modes (1,:) string
                options.Icons (1,1) struct = struct()
                options.Tooltips (1,1) struct = struct()
                options.ButtonProps (1,:) cell = {}
            end

            unknownModes = setdiff(modes, ...
                string(fieldnames(hPointerManager.Pointers)));
            if ~isempty(unknownModes)
                error('uim:PointerToolBinding:UnknownMode', ...
                    ['The pointer manager has no tool for mode "%s". ', ...
                     'Initialize the manager with this mode first, or ', ...
                     'remove it from the binding.'], unknownModes(1))
            end

            obj.Toolbar = hToolbar;
            obj.PointerManager = hPointerManager;
            obj.Modes = modes;

            obj.createButtons(options)
        end

        function delete(obj)
            % Remove buttons through the toolbar, so its layout
            % bookkeeping (button list, positions, count) stays
            % consistent for later addButton/resize operations.
            for i = 1:numel(obj.Buttons)
                if ~isvalid(obj.Buttons(i)); continue; end

                if isvalid(obj.Toolbar)
                    obj.Toolbar.removeButton(obj.Buttons(i))
                else
                    delete(obj.Buttons(i))
                end
            end
        end
    end

    methods (Access = private)

        function createButtons(obj, options)

            try
                defaultIcons = uim.style.getDefaultIcons();
            catch ME
                % Without the shipped icon library the buttons fall back
                % to text labels; any other failure is a real error.
                if ~strcmp(ME.identifier, 'uim:getDefaultIcons:IconLibraryNotFound')
                    rethrow(ME)
                end
                defaultIcons = struct();
            end

            for mode = obj.Modes

                buttonArgs = {'Mode', 'togglebutton', ...
                    'MechanicalAction', 'Switch when pressed', ...
                    'Tag', char(mode)};

                if isfield(options.Icons, mode)
                    buttonArgs = [buttonArgs, ...
                        {'Icon', options.Icons.(mode)}]; %#ok<AGROW>
                elseif isfield(defaultIcons, mode)
                    buttonArgs = [buttonArgs, ...
                        {'Icon', defaultIcons.(mode)}]; %#ok<AGROW>
                else
                    buttonArgs = [buttonArgs, {'Text', char(mode)}]; %#ok<AGROW>
                end

                if isfield(options.Tooltips, mode)
                    tooltip = options.Tooltips.(mode);
                else
                    tooltip = char(mode);
                end
                buttonArgs = [buttonArgs, {'Tooltip', tooltip}]; %#ok<AGROW>

                hButton = obj.Toolbar.addButton(...
                    buttonArgs{:}, options.ButtonProps{:});

                % Button -> tool: clicking toggles the pointer mode.
                % Capturing the mode key by value is intended.
                thisMode = char(mode);
                hButton.Callback = ...
                    @(~, ~) obj.PointerManager.togglePointerMode(thisMode);

                % Tool -> button: any (de)activation of the tool updates
                % the button state, including deactivation caused by a
                % competing tool or a keyboard shortcut.
                hButton.addToggleListener(...
                    obj.PointerManager.Pointers.(mode), 'ToggledPointerTool')

                obj.Buttons = [obj.Buttons, hButton];
            end
        end
    end
end
