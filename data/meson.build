# UI Resources
ui_files = []

# Compile Blueprint files to UI files
blueprint_files = [
  'ui/window.blp',
  'ui/dialogs/help.blp',
  'ui/dialogs/preferences.blp',
  'ui/dialogs/variant-selector.blp',
  'ui/dialogs/variant-rules.blp',
  'ui/dialogs/game-preferences.blp',
  'ui/dialogs/game-end.blp',
  'ui/dialogs/game-history.blp',
  'ui/dialogs/game-replay.blp',
  'ui/dialogs/new-game.blp',
  'ui/dialogs/multiplayer.blp',
  'ui/widgets/game-controls.blp',
  'ui/widgets/timer-display.blp',
  'ui/widgets/move-history.blp',
]

foreach blueprint_file : blueprint_files
  ui_file = blueprint_file.replace('.blp', '.ui')
  ui_filename = fs.name(ui_file)
  ui_files += custom_target(
    ui_file.underscorify(),
    input: blueprint_file,
    output: ui_filename,
    command: [blueprint_compiler, 'compile', '--output', '@OUTPUT@', '@INPUT@'],
  )
endforeach

# Generate GResource file
gresource_xml = configure_file(
  input: 'io.github.tobagin.Draughts.gresources.xml.in',
  output: 'io.github.tobagin.Draughts.gresources.xml',
  configuration: conf_data
)

app_resources = gnome.compile_resources(
  'app-resources',
  gresource_xml,
  dependencies: ui_files,
  source_dir: [meson.current_build_dir(), meson.current_source_dir()],
  c_name: 'draughts_resources'
)

# Install metainfo
metainfo_file = configure_file(
  input: 'io.github.tobagin.Draughts.metainfo.xml.in',
  output: '@0@.metainfo.xml'.format(project_id),
  configuration: conf_data,
  install: true,
  install_dir: get_option('datadir') / 'metainfo'
)

# Install desktop file
desktop_file = configure_file(
  input: 'io.github.tobagin.Draughts.desktop.in',
  output: '@0@.desktop'.format(project_id),
  configuration: conf_data,
  install: true,
  install_dir: get_option('datadir') / 'applications'
)

# Install MIME type
install_data(
  'io.github.tobagin.Draughts.mime.xml',
  install_dir: get_option('datadir') / 'mime' / 'packages',
  rename: '@0@.xml'.format(project_id)
)

# GSchema
gschema_file = configure_file(
    input: 'io.github.tobagin.Draughts.gschema.xml.in',
    output: project_id + '.gschema.xml',
    configuration: conf_data
)

install_data(
    gschema_file,
    install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

# Compile schemas after installation
gnome = import('gnome')
meson.add_install_script('glib-compile-schemas', get_option('prefix') / get_option('datadir') / 'glib-2.0' / 'schemas')

# Install piece images for development
install_data([
  'red-checker.png',
  'red-king.png',
  'black-checker.png',
  'black-king.png',
  'red-checker-metal.png',
  'red-king-metal.png',
  'black-checker-metal.png',
  'black-king-metal.png',
  'red-checker-wood.png',
  'red-king-wood.png',
  'black-checker-wood.png',
  'black-king-wood.png',
  'red-checker-bottle-cap.png',
  'red-king-bottle-cap.png',
  'black-checker-bottle-cap.png',
  'black-king-bottle-cap.png'
], install_dir: get_option('datadir') / 'draughts')

# Install sound effects
install_data([
  'sounds/move.ogg',
  'sounds/capture.ogg',
  'sounds/king.ogg',
  'sounds/game-start.ogg',
  'sounds/game-end.ogg',
  'sounds/timer-warning.ogg',
  'sounds/illegal-move.ogg',
  'sounds/undo.ogg',
  'sounds/redo.ogg'
], install_dir: get_option('datadir') / 'draughts' / 'sounds')

# Install UI icons
install_data([
  'icons/hicolor/scalable/apps/io.github.tobagin.Draughts-undo-symbolic.svg',
  'icons/hicolor/scalable/apps/io.github.tobagin.Draughts-redo-symbolic.svg',
  'icons/hicolor/scalable/apps/io.github.tobagin.Draughts-chckerboard-symbolic.svg',
  'icons/hicolor/scalable/apps/io.github.tobagin.Draughts-draw-symbolic.svg',
  'icons/hicolor/scalable/apps/io.github.tobagin.Draughts-connected-symbolic.svg',
  'icons/hicolor/scalable/apps/io.github.tobagin.Draughts-disconnected-symbolic.svg'
], install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps')

# Install SVG icon
# Note: No SVG icon currently, using PNG icons instead
# install_data(
#   '../io.github.tobagin.Draughts.svg',
#   install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps',
#   rename: '@0@.svg'.format(project_id)
# )

# Install PNG icons in all required sizes
icon_sizes = ['16x16', '32x32', '48x48', '64x64', '128x128', '256x256', '512x512']
foreach size : icon_sizes
  install_data(
    'icons/hicolor' / size / 'apps' / 'io.github.tobagin.Draughts.png',
    install_dir: get_option('datadir') / 'icons/hicolor' / size / 'apps',
    rename: '@0@.png'.format(project_id)
  )
endforeach