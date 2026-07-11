# UI Mechanics for MATLAB

[![Version Number](https://img.shields.io/github/v/release/ehennestad/ui-mechanics-matlab?label=version)](https://github.com/ehennestad/ui-mechanics-matlab/releases/latest)
[![MATLAB Tests](.github/badges/tests.svg)](https://github.com/ehennestad/ui-mechanics-matlab/actions/workflows/test-code.yml)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/ehennestad/ui-mechanics-matlab/security/code-scanning)
[![Run Codespell](https://github.com/ehennestad/ui-mechanics-matlab/actions/workflows/run-codespell.yml/badge.svg)](https://github.com/ehennestad/ui-mechanics-matlab/actions/workflows/run-codespell.yml)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ehennestad/ui-mechanics-matlab/graphs/commit-activity)

Composable controls and interactions for MATLAB figures.

## Description

UI Mechanics (uim) provides reusable interface components and interaction infrastructure for programmatic MATLAB applications. It is designed for scientific viewers, image tools and other graphics-heavy apps that need controls and pointer interactions tightly integrated with plotted data. The toolbox includes composable controls, toolbars, message overlays, layout utilities, styling, and tools for zooming, panning, selection and data interaction. Its core is designed to work across traditional MATLAB figures and modern UI figures without depending on a larger application framework.

## Requirements and installation
It is recommended to use **MATLAB R2019b** or later.
The following MathWorks products are required:
- MATLAB
- Image Processing Toolbox

Users or developers who clone the repository using git can use [MatBox](https://github.com/ehennestad/MatBox) to quickly install this project's [requirements](./requirements.txt) (if any):

```matlab
uimtools.installMatBox() % If MatBox is not installed
matbox.installRequirements(path/to/toolboxRootDir)
```

## Getting started

```matlab
< add some code examples here >
```

## Contributing
Please see the [Contributing guidelines](.github/CONTRIBUTING.md) and the [Developer notes](.github/DeveloperNotes.md)

## License

This project is available under the MIT License. See the LICENSE file for details.

## Author

Eivind Hennestad (eivihe@uio.no)
University of Oslo
