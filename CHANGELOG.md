# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed — Breaking: app-coupled widgets decoupled from ParentApp

`ChannelIndicator`, `PlaneSwitcher` and `PlaybackControl` previously
required a `parentGui` object as their first constructor argument and
reached into it (`ParentApp.Figure`, `ParentApp.Axes`, and — for
`PlaybackControl` — a `PostSet` listener on `ParentApp.currentFrameNo`
plus direct calls to `changeFrame`/`playVideo`/`changeChannel`/
`changePlane`/`changeChannelColor` and writes to `isPlaying`/
`playbackspeed`). They are now standalone widgets: the constructor takes
only a graphics parent, the host application *pushes* state in through
properties, and user interactions come *out* through callback
properties. Migration notes per widget:

#### `uim.widget.ChannelIndicator`

- Constructor: `ChannelIndicator(parentGui, hParent, ...)` →
  `ChannelIndicator(hParent, ...)`. The figure is resolved via
  `ancestor(hParent, 'figure')`; nothing else was ever read from
  `parentGui`.
- The `ParentApp` property is removed.
- Callbacks are unchanged (`Callback`, `ChannelColorCallback`,
  `ChangeDefaultsCallback`).

### Changed — Breaking: full API rename to PascalCase

Every class, property, and several methods across the toolbox have been
renamed to comply with the project's coding standards (PascalCase classes
and properties, camelCase functions and methods). The previous API grew
ad hoc since the project's ~2018 extraction from a larger library and mixed
casing conventions inconsistently; this is a clean-break rename with **no
backward-compatibility aliases**. Code written against the pre-rename API
will not run unmodified.

#### Class renames

All classes are now PascalCase. Representative examples (not exhaustive —
see git history for the complete list):

| Old | New |
|---|---|
| `uim.handle` | `uim.Handle` |
| `uim.panel` | `uim.Panel` |
| `uim.tab` | `uim.Tab` |
| `uim.tabgroup` | `uim.TabGroup` |
| `uim.interface.abstractPointer` | `uim.interface.PointerTool` |
| `uim.interface.zoom` | `uim.interface.Zoomable` |
| `uim.interface.pointerManager` | `uim.interface.PointerManager` |
| `uim.interface.pointerTool.*` (namespace) | `uim.interface.pointertools.*` |
| `uim.interface.pointertools.axisZoom/crop/dataCursor/pan/zoomIn/zoomOut` | `AxisZoom/Crop/DataCursor/Pan/ZoomIn/ZoomOut` |
| `uim.mixin.assignProperties` | `uim.mixin.NameValueAssignable` |
| `uim.mixin.isResizable` | `uim.mixin.Resizable` |
| `uim.mixin.structAdapter` | `uim.mixin.StructConvertible` |
| `uim.widget.slidebar` | `uim.widget.Slider` |
| `uim.widget.rangeslider` | `uim.widget.RangeSlider` |
| `uim.widget.scrollerBar` | `uim.widget.ScrollBar` |
| `uim.widget.messageBox` | `uim.widget.MessageBox` |
| `uim.widget.toolbar` | `uim.widget.Toolbar` |
| `uim.widget.tabbar` | `uim.widget.TabBar` |
| `uim.style.*` (18 classes) | PascalCase (`uim.style.ButtonScheme`, `uim.style.TableTheme`, etc.) |
| `uim.decorator.box/image` | `uim.decorator.Box/Image` |
| `uim.graphics.imageVector/tiledImageAxes` | `uim.graphics.ImageVector/TiledImageAxes` |
| `uim.abstract.toolbarComponent` | `uim.abstract.ToolbarComponent` |

The `+pointerTool` namespace was renamed to `+pointertools` (lowercase,
plural) rather than `+pointerTool`, to avoid a case-only collision with the
new `PointerTool` class on case-insensitive filesystems (macOS/Windows).

Pointer-tool mode keys used by `PointerManager.togglePointerMode()` (e.g.
`'zoomIn'`, `'pan'`, `'dataCursor'`) remain camelCase strings — they are a
public mode API, not class names, and were not renamed.

#### Property renames

All public and internal properties are now PascalCase, with `h`-prefixed
Hungarian-notation names (`hAxes`, `hFigure`, `hBackground`, ...) replaced
by plain descriptive names (`Axes`, `Figure`, `Background`, ...). This
changes the name-value argument names accepted by every constructor that
uses them, for example:

- `uim.widget.Slider(..., 'nTicks', 10)` → `'NumTicks'`
- `uim.graphics.TiledImageAxes(..., 'gridSize', [3,5], 'imageSize', [128,128])` → `'GridSize'`, `'ImageSize'`
- `uim.interface.PointerManager.pointers` → `.Pointers`
- `uim.interface.PointerTool.exitMode` → `.ExitMode`

A few renames were adjusted to avoid collisions with inherited or sibling
properties, discovered by running the test suite after each change (not by
static analysis alone):

- `uim.abstract.Component`'s `hAxes` was merged into the pre-existing
  `CanvasAxes` dependent wrapper (which only ever returned `hAxes`
  unchanged) rather than becoming a separate `Axes` property.
- `uim.decorator.Image`'s public `Image` property (the pixel data) was
  renamed to `CData` — matching MATLAB's own `image()` function
  convention — because the class itself is now also named `Image`, and
  MATLAB forbids a property sharing its class's name.
- `uim.widget.RangeSlider`'s label-handle property is `LabelHandle`, not
  `Label`, because `Label` is already a public string property inherited
  from `uim.abstract.Control`.
- `uim.widget.MessageBox`'s `hParent` became `ReferenceAxes`, not `Parent`,
  because `Parent` is inherited from `uim.mixin.Resizable` and means
  something different (the interactive-rectangle host).
- `uim.interface.pointertools.mixin.DraggableRectangle`'s abstract `Axes`
  property needed an explicit `SetAccess = protected` to match the
  concrete `Axes` property it is satisfied by on `uim.interface.PointerTool`
  — a mismatch here raised `MATLAB:class:conflictingSuperClassProperty` at
  construction time, caught only by running the test suite.

### Changed — Access levels tightened

Several methods and properties that were public but only ever intended for
internal use are now `protected` or `private`, matching their actual call
sites (verified by a full-repository search, not assumption):

- `uim.abstract.Component`: `redraw`, `resize`, `relocate`, `move`,
  `updateSize`, `updateLocation` are now `Access = protected`. All
  subclass overrides of these methods were moved into protected blocks
  to match. `uicontrol`, `uitable`, `axes` wrapper methods are now
  `Hidden` (they exist to shadow the builtins of the same name for
  Component subclasses, not for direct external use).
- `uim.widget.Toolbar`: `NextButtonPosition` and `AllButtonPosition` are
  now `Access = protected`; `NumButtons` is `SetAccess = protected`
  (`TabBar`, a subclass, writes to it directly, so `private` was not an
  option). `relocate`, `onButtonSizeChanged`, `updateLocation`,
  `updateSize` are now `Access = protected`.
- `uim.interface.PointerManager`: `onButtonDown`, `onButtonMotion`,
  `onButtonRelease`, `isCursorInsideAxes` are now `Access = private`
  (they are only ever invoked via function handles created inside the
  class's own constructor and listeners). `updatePointerSymbol` and
  `onFigureChanged` are now `Hidden`. `togglePointerMode`,
  `initializePointers`, `onKeyPress`, `onKeyRelease` remain public, as
  the intended entry points for a host application.

### Fixed

- `PageIndicator.m` had a dead comment referencing
  `uim.style.nansenPageButton`, a class that never existed in this repo
  (leftover from the original extraction); it now references the real
  `uim.style.ButtonScheme`.
- `uim.mixin.Resizable`'s `isResizeable` property (typo) is now
  `IsResizable`.
