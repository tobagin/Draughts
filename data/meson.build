# UI Resources
ui_files = []

# Compile Blueprint files to UI files
blueprint_files = [
  'ui/window.blp',
  'ui/dialogs/preferences.blp',
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
  source_dir: meson.current_build_dir(),
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

# Install SVG icon
install_data(
  '../io.github.tobagin.Draughts.svg',
  install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps',
  rename: '@0@.svg'.format(project_id)
)