# Native workbench direction

The user's confirmed direction is a native macOS workbench: device/space sidebar, central tabs and full-fidelity terminals, no built-in file browser or preview. Code first, run and inspect the actual app. The visual assignment is bounded by that explicit native choice.

The first viewport is a Herdr Space workbench. The interface uses macOS system type, semantic colors and standard settings controls. Terminal content owns most of the window. Ordinary text stays neutral within the selected palette; emphasis, focus and native actions use the chosen accent, with raw selection hue separate from contrast-adjusted text. Status must distinguish device connection from terminal attachment and agent execution. Hidden surfaces retain their dimensions and suspend drawing.

The signature interaction is retaining native terminal surfaces while switching tabs, rather than reattaching processes. The current icon is the user's purple slash on a pale rounded tile; its provenance is in [Resources/Icon/README.md](../Resources/Icon/README.md). Plugin actions, logs and panels inherit the same native language, using the official Herdr API. The switchable theme contract and its bounded terminal adaptations are recorded in [theme validation](theme-correction/VALIDATION.md).

The user explicitly removed native directory browsing and previews. Toolbar controls and shortcuts for that feature are absent.

Risk: compact tab labels and long remote names must truncate without covering controls. Verify main window, split shell, Jump and settings at the actual desktop size. This is a native application; no web detector applies.
