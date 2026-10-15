# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed — Widget-layer arithmetic lives in `internal` namespaces

- `uim.control.internal`: `contentOffsetInBox` (button text and icon
  placement), `fittedIconDimension` (icon sizing).
- `uim.widget.internal`: `alignRunStart` (toolbar button runs),
  `wrapMessageLines` (message box folding).
- `uim.graphics.internal`: `boundingBoxAnchor` (vector-image
  positioning), `cropImageToContent` (icon rasters).
- `uim.mixin.internal`: `rescaleChildPosition` (resizable children).

### Added

- New `uim.geometry` package for axis-limit, range and rectangle
  arithmetic that hosts can use too: `scaleLimits`, `intersectRanges`,
  `fitRangeInside`, `isPointInsideLimits`, `fitLimitsToAspectRatio`,
  `centeredLimits` and `letterboxFit`. The helpers that encode one
  tool's conventions live in `uim.geometry.internal`:
  `zoomLimitsAboutPoint`, `panLimits`, `stretchLimits`,
  `limitsToRectangle`, `rectangleToLimits`, `isRangeStrictlyInside` and
  `shiftLimitsInside`. Interaction helpers (`cropMaskOutline`,
  `isClickWithoutDrag`, `keyToPointerToolName`,
  `rectangleOutlineBetween`, `selectionTypeToButton`) stay in
  `uim.interface.internal`. `TestGeometry` covers both packages.

### Changed

- Every class in `uim.style` now has help text saying what it looks like
  and when to reach for it.
- Renamed style classes whose numeric suffixes said nothing about what they
  look like: `ButtonDarkMode3` -> `ButtonDarkModeBold`, `ButtonLightMode2`
  -> `ButtonLightModeTranslucent`, `TabButton2` -> `TabButtonDark`. Each
  now carries help text naming the variant it differs from.
  `ButtonSymbol2` is deliberately left alone: it differs from
  `ButtonSymbol` only in `BorderWidth` while both set `BorderColor` to
  `none`, so it has no visible difference to name it after, and it is a
  deletion candidate rather than a rename candidate.
- Renamed `uim.utility.layout.findgridsize` to
  `uim.utility.layout.findGridSize`, the lowerCamelCase the rest of the
  toolbox uses.
- Moved classes and functions into the package that owns them:
  `uim.interface.Zoomable` and `uim.abstract.ToolbarComponent` are now
  `uim.mixin.Zoomable` and `uim.mixin.ToolbarComponent` (both are mixins,
  not interaction machinery or abstract bases), and the single-function
  `uim.menu` package is gone — `createColormapList` now lives in
  `uim.graphics.internal` beside its only caller.

### Removed

- `uim.shape.getIcon`, which returned play/pause glyph coordinates. It was
  unreferenced — `uim.widget.PlaybackControl` defines its own glyphs — and
  it was not a shape.
- `uim.utility.setpixelpositionnonscalar`, an adaptation of MATLAB's
  `setpixelposition` that the MATLAB licence does not allow
  redistributing. Nothing called it; call `setpixelposition` for each
  handle instead.

### Fixed

- `uim.graphics.ImageVector`: `Position` is the point named by the
  alignment pair, also after a resize or rotation, and changing
  `HorizontalAlignment` or `VerticalAlignment` keeps it and moves the
  image around it. The alignment change used to move the image by the
  wrong amount, and `Position` read back the box centre or, after a
  resize, a point the image had left.
- `uim.widget.ChannelIndicator`: assigning a `ChannelColors` list shorter
  than the previous one errored; the update now covers the indicators
  the new list describes.
- `uim.widget.MessageBox`: a word longer than the per-line budget made
  the rest of the message disappear; such a word now takes a line of
  its own. Lines also hold as many words as fit, where the old length
  estimate over-counted the spaces.
- `uim.widget.FrameMarker`: a marker constructed with a `Value` was drawn
  at x = 1 instead, and assigning `Visible` did nothing. Both properties
  now reach the graphics.
- `uim.widget.PlaybackControl`: the active-range handles offset a value
  from zero and the range bar offset it from 1, so the handles sat one
  step right of the bar, and with `Minimum` above 1 both were shifted.
  Both now offset from `Minimum`.

### Changed — Pointer-tool arithmetic is extracted into pure functions

The zoom, pan, axis-drag, selection-rectangle and crop arithmetic of the
pointer tools, plus the PointerManager's press and key translations, are
pure functions now, in `uim.geometry` (`isPointInsideLimits`,
`fitRangeInside`, `intersectRanges`, `scaleLimits`,
`fitLimitsToAspectRatio`), `uim.geometry.internal`
(`zoomLimitsAboutPoint`, `panLimits`, `isRangeStrictlyInside`,
`stretchLimits`, `limitsToRectangle`, `rectangleToLimits`) and
`uim.interface.internal` (`rectangleOutlineBetween`,
`isClickWithoutDrag`, `cropMaskOutline`, `selectionTypeToButton`,
`keyToPointerToolName`). Tool behaviour is unchanged apart from the fix
below and one edge case: an axes collapsed to zero width or height skips
the aspect-ratio fit, so the requested limits are only fitted inside the
original limits.

### Fixed — Crop tool shrank the crop by one pixel per activation

`uim.interface.pointertools.Crop` converted limits to an ROI rectangle
with an exclusive width but read the rectangle back with an inclusive
one, so re-activating the tool on an existing crop lost a pixel each
time. Both conversions now use inclusive pixel limits.

### Changed — UI-free widget geometry is extracted into pure functions

The coordinate and value arithmetic of the slider family, the scrollbar,
the overview indicator and the tiled image axes is extracted into pure
functions that are unit-tested without graphics. Apart from the fixes
listed below, one input is handled differently: `Slider.TickMode` is
case-insensitive, and an unknown mode raises
`uim:widget:InvalidTickMode` instead of drawing ticks under the track.
The widgets delegate to:

- `uim.widget.internal` — `mapValueToPixel`/`mapPixelToValue`,
  `snapToStep`, `nearestRangeKnob`, `tickMarkCoordinates`, `knobOutline`
  (Slider, RangeSlider, PlaybackControl); `clampScrollChange`,
  `acceptScrollStep`, `scrollBarSize` (ScrollBar);
  `mapDataToFrame`/`mapFrameToData` (OverviewIndicator).
- `uim.geometry` — `letterboxFit`, `centeredLimits`, and
  `uim.geometry.internal` — `shiftLimitsInside` (OverviewIndicator).
- `uim.graphics.internal` — `computeTileLayout`, `tileGridPixelSize`,
  `tileCenter`, `tileAtPoint` (TiledImageAxes).
- `uim.utility.internal` — `findMonitorContainingPoint`
  (getCurrentScreenSize).

Namespace policy: `uim.utility` and `uim.geometry` are the public
helper API, frozen from the first release. An `internal` namespace is
not public API. A helper lives in the `internal` namespace of the domain
it belongs to, not necessarily its caller's package: the tool-specific
limit arithmetic in `uim.geometry.internal` is called from
`uim.interface`, `uim.widget` and `uim.mixin`.

### Fixed

- `uim.widget.ScrollBar`: a horizontal scrollbar wrote its track extent
  to `YData` instead of `XData` when the limits changed.
- `uim.graphics.TiledImageAxes`: `hittest()` without coordinates read a
  single element of `CurrentPoint` and errored.
- `uim.widget.Slider`: the value label was positioned on the full widget
  width instead of the padded knob track.
- `uim.utility.getCurrentScreenSize`: a point on the last pixel column
  or row of a monitor counted as outside that monitor.
- `uim.graphics.TiledImageAxes` with `TileUnits = 'scaled'`: the axes
  limits, tile outlines, tile centres and hit-testing read the scale
  factor in different orders ([height, width] and [x, y]). With images
  rescaled unevenly the axes did not span the original pixels, and
  `hittest` and `getTileCenterAxesCoords` disagreed with the drawn
  tiles. The scale factor is now [x, y] throughout.

### Tests

New headless test classes: `TestWidgetGeometry`, `TestTileLayout`,
`TestLayoutUtilities`, `TestColorAndDataUtilities`, `TestSliderWidgets`.

### Added — New widgets: DropDown, Spinner, Readout

Three new Component-family controls, usable on any supported parent
(figure, panel, canvas, or — via the overlay canvas — a data axes):

- `uim.widget.DropDown` — popup selector. `Items` (string array) /
  `Value`, click-to-open list below the control (drawn with clipping
  off, so it may extend past the canvas bounds), item hover highlight
  (needs Image Processing Toolbox; degrades gracefully), outside-click
  closes, programmatic `open()`/`close()`. User selections fire
  `ValueChangedFcn` with `uim.event.ValueChangedEventData`;
  programmatic `Value` assignment is silent and validated against
  `Items` (`uim:DropDown:InvalidValue`).
- `uim.widget.Spinner` — numeric value with -/+ step buttons and
  click-to-type editing via a temporary edit box (classic uicontrol;
  the buttons work everywhere). User interactions are clamped to
  `[Minimum, Maximum]` and fire `ValueChangedFcn`; programmatic
  `Value` assignment is silent.
- `uim.widget.Readout` — display-only label + formatted-value chip
  (`Label`, `Value`, sprintf-style `Format`), for live readouts such
  as cursor position or current frame.

### Added — Overlay canvas: components anchor inside a data axes

Component-family widgets (`uim.widget.Toolbar`, `uim.widget.RangeSlider`,
`uim.widget.PageIndicator`, buttons, ...) now accept an **axes** as their
parent, e.g. `uim.widget.Toolbar(hAxes, "Location", "northeast")` places
a toolbar in the northeast corner of a data axes. This is non-breaking:
all previously supported parents behave as before.

Under the hood this is a new *overlay mode* for `uim.UIComponentCanvas`:

- `uim.UIComponentCanvas(hAxes)` (or `getOrCreate(hAxes)`) creates an
  invisible canvas axes covering the pixel rectangle of the target axes
  and tracking its position and size, so component layout runs in
  rect-local pixel coordinates. The target axes' data limits and
  contents are untouched.
- An axes holds at most one overlay canvas (`getOrCreate` returns the
  existing one; a direct constructor call raises
  `uim:UIComponentCanvas:DuplicateCanvas`). Overlay canvases coexist
  with a whole-container canvas on the same figure/panel: canvas
  ownership is keyed on the target axes, not the container.
- Deleting the target axes deletes the overlay canvas and every
  component on it, and restores the container's `DefaultAxesCreateFcn`.
- `reparent` is not supported on an overlay canvas
  (`uim:UIComponentCanvas:OverlayReparentNotSupported`).

Known limitations in this first version:

- The overlay anchors to the axes **Position rectangle**, not the
  visible plot box — under `axis image`/`axis equal` these differ, so
  components anchor to the rect edges, not the image edges.
- Z-order among multiple canvases in one container follows canvas
  creation order (canvases created later stack on top).
- The target axes must be parented directly in a figure, uifigure,
  panel or tab; axes inside a `TiledChartLayout` raise
  `uim:UIComponentCanvas:UnsupportedAxesParent`.
- Containers with `CanvasMode='private'` are rejected on an overlay
  canvas (`uim:Container:PrivateCanvasUnsupportedOnOverlay`).

Internal supporting change: the per-canvas `DefaultAxesCreateFcn`
chaining (used to keep canvas axes on top of the uistack) was replaced
by a per-container registry with a single shared hook, so multiple
canvases on one container can be created and deleted in any order
without corrupting the hook chain.

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

#### `uim.widget.PlaneSwitcher`

- Constructor: `PlaneSwitcher(parentGui, hParent, ...)` →
  `PlaneSwitcher(hParent, ...)`. The figure is resolved via
  `ancestor(hParent, 'figure')`.
- The `ParentApp` property is removed. The pop-out plane slider is now
  parented in the container of the switcher's own axes rather than
  `parentGui.Axes.Parent` (for the typical case — both axes living in
  the same figure/panel — this is the same container as before).
- `Callback` is unchanged, and is now optional: dragging the plane
  slider with no callback set no longer errors.

#### `uim.widget.PlaybackControl`

- Constructor: `PlaybackControl(parentGui, parentHandle, ...)` →
  `PlaybackControl(parentHandle, ...)`. The figure is resolved via
  `ancestor(parentHandle, 'figure')`.
- The `ParentApp` property is removed, along with every implicit
  contract on the app object. The widget no longer listens to
  `parentGui.currentFrameNo` via `PostSet` (and the public
  `changeValue` method that serviced that listener is removed) — the
  host now pushes the current value by assigning `Value` directly.
- The widget owns playback speed state: a new public `PlaybackSpeed`
  property replaces reads/writes of `parentGui.playbackspeed`
  (doubling/halving on the speed buttons and the speed label are
  handled internally).
- User interactions notify the host through new callback properties
  instead of calling app methods:
  - `ValueChangedFcn(src, evt)` — knob drag or slider-bar click;
    replaces `parentGui.changeFrame(...)`. `evt` is a
    `uim.event.ValueChangedEventData` (`OldValue`/`NewValue`).
  - `PlaybackStartedFcn(src, evt)` / `PlaybackStoppedFcn(src, evt)` —
    play/pause button; replace `parentGui.playVideo(...)` and the
    write to `parentGui.isPlaying`. `evt` is a `uim.event.ToggleEvent`.
  - `PlaybackSpeedChangedFcn(src, evt)` — speed buttons;
    `uim.event.ValueChangedEventData`.
  - `CurrentChannelsChangedFcn(src, evt)` — replaces
    `parentGui.changeChannel(...)`; `evt` is a `uim.event.EventData`
    with a `CurrentChannels` property.
  - `CurrentPlaneChangedFcn(src, evt)` — replaces
    `parentGui.changePlane(...)`; `evt` has a `CurrentPlane` property.
  - `ChannelColorChangedFcn(src, evt)` — replaces
    `parentGui.changeChannelColor(...)`; `evt` has `ChannelNumber` and
    `RgbColor` properties. (The old wiring passed the wrong arguments
    to `changeChannelColor` — it forwarded the sub-widget handle and
    event object as if they were an index and a color — so hosts that
    relied on channel-color changes were receiving garbage arguments
    already.)

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
| `uim.interface.zoom` | `uim.mixin.Zoomable` |
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
| `uim.style.buttonDarkMode3` | `uim.style.ButtonDarkModeBold` |
| `uim.style.buttonLightMode2` | `uim.style.ButtonLightModeTranslucent` |
| `uim.style.tabButton2` | `uim.style.TabButtonDark` |
| `uim.style.*` (other classes) | PascalCase (`uim.style.ButtonScheme`, `uim.style.TableTheme`, etc.) |
| `uim.utility.setpixelpositionnonscalar` | Removed; call `setpixelposition` for each handle |
| `uim.utility.layout.findgridsize` | `uim.utility.layout.findGridSize` |
| `uim.decorator.box/image` | `uim.decorator.Box/Image` |
| `uim.graphics.imageVector/tiledImageAxes` | `uim.graphics.ImageVector/TiledImageAxes` |
| `uim.abstract.toolbarComponent` | `uim.mixin.ToolbarComponent` |

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

- Pointer tools now receive mouse presses over data objects.
  `uim.interface.PointerManager` previously took over the managed
  axes' `ButtonDownFcn` to detect presses — but data objects such as
  images have `HitTest` on by default and swallow every click before
  it reaches that callback, so zoom/pan tools were dead over an
  `imagesc` display unless the app made its image click-transparent
  (as imviewer does with `HitTest = 'off'`). Presses are now captured
  by a window-level `WindowMousePress` listener, gated so that presses
  on interactive objects (anything with its own `ButtonDownFcn`) or
  outside the managed axes are ignored. The axes' own `ButtonDownFcn`
  is set aside only while a pointer tool is active (see below);
  existing `HitTest = 'off'` workarounds remain harmless.
- `PageIndicator.m` had a dead comment referencing
  `uim.style.nansenPageButton`, a class that never existed in this repo
  (leftover from the original extraction); it now references the real
  `uim.style.ButtonScheme`.
- `uim.mixin.Resizable`'s `isResizeable` property (typo) is now
  `IsResizable`.

### Changed — Pointer manager, data cursor and dropdown

- `uim.interface.PointerManager` sets a host's axes `ButtonDownFcn`
  aside while a pointer tool is active and gives it back when no tool
  is, so each press on the axes background has exactly one handler. A
  callback the host assigns while a tool is active is kept.
- `uim.interface.pointertools.DataCursor` reports cursor movement
  through the new `CursorMovedFcn` instead of the inherited
  `ButtonMotionFcn`.
- `uim.widget.DropDown` accepts `Value = ""` as "no selection". Assigning
  `Items` while nothing is selected selects the first item, so to switch
  to an `Items` list that lacks the current `Value`, set `Value` to `""`
  first.
- MATLAB R2020b is the minimum supported release.
