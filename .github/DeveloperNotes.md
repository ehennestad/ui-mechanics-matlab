# Developer Notes

This document provides guidance for developing and maintaining the UI Mechanics for MATLAB toolbox.

## 📁 Project Structure

```
ui-mechanics-matlab/
├── src/uim/                                       # Main toolbox source code
│   ├── +uim/                                      # MATLAB package namespace
│   ├── Contents.m                                 # Toolbox contents listing
│   └── gettingStarted.m                           # Getting started guide
├── tests/                                         # Unit tests and test utilities
│   ├── +uim/                                      # Namespace for unit tests and test utilites
├── tools/                                         # Development and build tools
│   ├── +uimtools/                                 # Toolbox utilities
│   └── MLToolboxInfo.json                         # Toolbox metadata
└── docs/                                          # Documentation
    ├── buildDocs.m                                # Documentation builder
    ├── README.md                                  # Documentation guide
    └── STYLE_GUIDE.md                             # Coding style guide
```

## 🚀 Development Workflow

### 1. Setting Up Development Environment

```matlab
% Add the toolbox to your MATLAB path
addpath(genpath('src/uim'));

% Verify installation
uim.toolboxversion()
```

### 2. Writing Functions

**Location**: Place your main functions in `src/uim/+uim/`

**Naming Convention**: Use camelCase for function names and PascalCase for class names

**Function Template**:
```matlab
function output = myFunction(input, options)
% MYFUNCTION Brief description of what the function does
%
% Syntax:
%   output = uim.myFunction(input)
%   output = uim.myFunction(input, options)
%
% Description:
%   Detailed description of the function's purpose and behavior.
%
% Input Arguments:
%   input - Description of input parameter
%       Type: double | logical | char
%       Size: [m,n] | scalar | vector
%
%   options - Optional parameters (optional)
%       Type: struct
%       Fields:
%         - field1: Description (default: value)
%         - field2: Description (default: value)
%
% Output Arguments:
%   output - Description of output
%       Type: double | logical | char
%       Size: [m,n] | scalar | vector
%
% Examples:
%   % Basic usage
%   result = uim.myFunction(data);
%
%   % With options
%   opts.field1 = value;
%   result = uim.myFunction(data, opts);
%
% See also: RELATEDFUNCTION1, RELATEDFUNCTION2
%
% UI Mechanics for MATLAB
% Copyright (c) Eivind Hennestad, University of Oslo

arguments
    input {mustBeNumeric}
    options.field1 (1,1) double = 1
    options.field2 (1,1) logical = false
end

% Function implementation here
output = processInput(input, options);

end
```

### 3. Writing Tests

**Location**: Place tests in `tests/` directory

**Test Template**:
```matlab
function tests = testMyFunction
% TESTMYFUNCTION Unit tests for myFunction
%
% Run tests:
%   runtests('testMyFunction')
%   results = runtests('testMyFunction')

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% Setup for the entire test suite
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src', 'uim'));
end

function setup(testCase)
% Setup for each test
testCase.TestData.sampleData = rand(10, 5);
end

function testBasicFunctionality(testCase)
% Test basic functionality
input = testCase.TestData.sampleData;
result = uim.myFunction(input);
verifySize(testCase, result, size(input));
end

function testWithOptions(testCase)
% Test with optional parameters
input = testCase.TestData.sampleData;
options.field1 = 2;
result = uim.myFunction(input, options);
verifyClass(testCase, result, 'double');
end

function testErrorHandling(testCase)
% Test error conditions
verifyError(testCase, @() uim.myFunction('invalid'), ...
    'MATLAB:validators:mustBeNumeric');
end
```

### 4. Running Tests

```matlab
% Run all tests
runtests('tests')

% Run specific test file
runtests('tests/testMyFunction')

% Run with coverage
import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport

suite = testsuite('tests');
runner = TestRunner.withTextOutput;
runner.addPlugin(CodeCoveragePlugin.forFolder('src'));
results = runner.run(suite);
```

### 5. Building Documentation
Todo

### 6. Packaging the Toolbox

**Requirements**: MATLAB R2023a or later for toolbox packaging

```matlab
% Package the toolbox
uimtools.packageToolbox()

% Install locally for testing
uimtools.installMatBox()
```

## 📝 Coding Standards

### Documentation Standards

- **Function Headers**: Use the template above with complete argument descriptions
- **Comments**: Explain complex algorithms and non-obvious code
- **Examples**: Provide practical usage examples in function headers
- **See Also**: Reference related functions

### Code Style

- **Indentation**: 4 spaces (no tabs)
- **Line Length**: Maximum 80 characters
- **Variable Names**: Use descriptive camelCase names
- **Constants**: Use UPPER_CASE for constants
- **Function Names**: Use camelCase, start with lowercase letter

### Error Handling

```matlab
% Use arguments blocks for input validation
arguments
    input {mustBeNumeric, mustBeFinite}
    options.tolerance (1,1) double {mustBePositive} = 1e-6
end

% Provide meaningful error messages
if size(input, 2) ~= 3
    error('UIM:invalidInput', ...
        'Input must have exactly 3 columns, got %d', size(input, 2));
end
```

## 🔧 Development Tools

### Useful MATLAB Commands

```matlab
% Check code quality
checkcode('src/uim/')

% Profile performance
profile on
uim.myFunction(data);
profile viewer

% Dependency analysis
[fList, pList] = matlab.codetools.requiredFilesAndProducts('src/uim');
```

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/new-functionality

# Make changes and commit
git add .
git commit -m "Add new functionality for X"

# Push and create pull request
git push origin feature/new-functionality
```

## ⚠️ Important Notes

- **MATLAB Version Compatibility**: Toolbox packaging using [MatBox](https://github.com/ehennestad/MatBox) requires R2023a+.

- **Path Management**: Always use relative paths and the `uimtools.projectdir()` function
- **Testing**: Run tests before committing changes
- **Documentation**: Update documentation when adding new features
- **Versioning**: Follow semantic versioning (MAJOR.MINOR.PATCH)

## 🖱️ Graphics Interaction Gotchas

Hard-won rules for widget interaction code. These failure modes are
**invisible to headless tests** (which drive callbacks directly) and to
web-based figures (new desktop) — they only surface with a real mouse in
java-based figures (classic desktop). Test interactively in both figure
regimes before trusting a widget.

### CurrentPoint freezes without a WindowButtonMotionFcn

- **Symptom**: dragging a knob/handle changes the value once (computed
  from the press point) and then stops following the mouse, even though
  `WindowMouseMotion` listeners keep firing.
- **Cause**: in java-based figures, the figure and axes `CurrentPoint`
  only update during mouse motion while the figure has a **non-empty
  `WindowButtonMotionFcn`**. Event listeners fire regardless — but they
  read a stale point. The bug hides whenever something else installs a
  motion callback (a `PointerManager`, a host app, a debug callback),
  which makes it look intermittent.
- **Rule**: every widget that reads `CurrentPoint` from motion listeners
  must call `uim.utility.ensurePointerMotionTracking(hFigure)` in its
  constructor. It assigns a no-op `WindowButtonMotionFcn` only when the
  slot is empty. (This has been independently rediscovered at least
  twice; `PointerManager`'s dummy motion callback is the same fix from
  an earlier round.)

### Data objects swallow clicks before the axes callback

- **Symptom**: tools/callbacks wired to an axes' `ButtonDownFcn` never
  fire when the axes displays an image or other data.
- **Cause**: data objects have `HitTest = 'on'` by default and capture
  every click; the axes callback only fires for clicks on empty axes
  regions.
- **Rule**: capture presses at the window level (`WindowMousePress`
  listener) and gate on `event.HitObject` (ignore objects with their own
  `ButtonDownFcn`, and objects outside the managed axes) — see
  `uim.interface.PointerManager.onWindowMousePress`. Do not require apps
  to set `HitTest = 'off'` on their data.

### Data tips attach to widget graphics

- **Symptom**: clicking widget parts pins MATLAB data tips on them.
- **Cause**: three independent mechanisms, varying by figure regime:
  the default interaction set, `InteractionOptions.DatatipsSupported`
  (web figures), and the per-object `DataCursor` behavior (java
  figures).
- **Rule**: every axes the toolbox creates must go through
  `uim.utility.disableAxesInteractivity(hAxes)`, which handles all
  three (including a `ChildAdded` listener for objects plotted later).
  Widgets drawing into a *caller's* axes must not touch the axes —
  use primitive `line()` objects (no `DataTipTemplate`) for
  interactive parts instead, as `FrameMarker` does.

### Pointer hover behaviors outlive their graphics

- **Symptom**: an endless stream of "Invalid or deleted object" listener
  warnings on every mouse move after deleting a widget or part of one.
- **Cause**: `iptPointerManager` keeps invoking registered enter/exit
  callbacks for the object the cursor was on, even after that object is
  deleted.
- **Rule**: deregister before deleting —
  `uim.utility.setPointerBehavior(h, [])` for every registered object in
  the teardown path (see `uim.abstract.Control.delete` and
  `uim.widget.DropDown.close`), and make hover callbacks
  `isvalid`-guarded.

### Stale sessions after pulling changes

- **Symptom**: phantom bugs (or phantom fixes) after `git pull` into a
  running MATLAB session — behavior does not match the code on disk.
- **Cause**: MATLAB caches class definitions and `persistent` variables.
- **Rule**: run `clear all; clear functions` (or restart MATLAB) after
  pulling before judging behavior. Utility caches keyed on file
  timestamps (see `uim.style.getDefaultIcons`) avoid one class of this,
  but class definitions still require clearing.

## 🐛 Troubleshooting

### Common Issues

1. **Path Problems**: Ensure the toolbox is properly added to MATLAB path
2. **Test Failures**: Check that all dependencies are available
3. **Packaging Errors**: Verify MATLAB version and toolbox metadata
4. **Performance Issues**: Use MATLAB Profiler to identify bottlenecks

### Getting Help

- Check existing issues in the repository
- Review the documentation in `docs/`
- Consult the MATLAB documentation
- Contact the maintainers: eivihe@uio.no
