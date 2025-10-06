project('draughts', 'vala', 'c',
  version : '2.0.1',
  license : 'GPL-3.0+',
  meson_version : '>= 1.9.0'
)

# Import modules
gnome = import('gnome')
i18n = import('i18n')
fs = import('fs')

# Project information
if get_option('profile') == 'development'
  project_name = 'Draughts (Dev)'
  project_id = 'io.github.tobagin.Draughts.Devel'
else
  project_name = 'Draughts'
  project_id = 'io.github.tobagin.Draughts'
endif

# Dependencies
gtk4_dep = dependency('gtk4', version: '>= 4.20')
libadwaita_dep = dependency('libadwaita-1', version: '>= 1.8')
glib_dep = dependency('glib-2.0', version: '>= 2.86')
gio_dep = dependency('gio-2.0', version: '>= 2.86')
gee_dep = dependency('gee-0.8', version: '>= 0.8')
libsoup_dep = dependency('libsoup-3.0', version: '>= 3.0')
json_glib_dep = dependency('json-glib-1.0', version: '>= 1.6')

# Vala compiler requirements
vala = meson.get_compiler('vala')
if not vala.version().version_compare('>= 0.56.0')
  error('Vala compiler >= 0.56.0 required')
endif

# Vala arguments
vala_args = [
    '--target-glib=2.86',
    '--pkg=posix',
]

# Add development flag for preprocessor directives
if get_option('profile') == 'development'
    vala_args += ['-D', 'DEVELOPMENT']
endif

# Add GETTEXT_PACKAGE definition
add_project_arguments('-DGETTEXT_PACKAGE="' + meson.project_name() + '"', language: 'c')

# Global arguments
add_global_arguments(vala_args, language: 'vala')

# Blueprint compiler
blueprint_compiler = find_program('blueprint-compiler', required: true)

# Configuration
conf_data = configuration_data()
# Configuration for Vala Config.vala (needs quoted values)
vala_conf_data = configuration_data()
vala_conf_data.set_quoted('NAME', project_name)
vala_conf_data.set_quoted('ID', project_id)
vala_conf_data.set_quoted('VERSION', meson.project_version())
vala_conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
vala_conf_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))

# Configuration for data files (needs unquoted values)
conf_data = configuration_data()
conf_data.set('NAME', project_name)
conf_data.set('ID', project_id)
conf_data.set('ID_PATH', project_id.replace('.', '/'))
conf_data.set('VERSION', meson.project_version())
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))

# Configure file
configure_file(
  input: 'src/Config.vala.in',
  output: 'Config.vala',
  configuration: vala_conf_data
)

# Subdirectories
subdir('data')
subdir('src')
subdir('help')
subdir('tests')

# Summary
summary({
  'Project': project_name,
  'Version': meson.project_version(),
  'GTK4': gtk4_dep.version(),
  'LibAdwaita': libadwaita_dep.version(),
  'Vala': vala.version(),
}, section: 'Configuration')