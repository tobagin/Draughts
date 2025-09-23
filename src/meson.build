# Source files
draughts_sources = [
  'Main.vala',
  'Application.vala',
  'Window.vala',
  'Constants.vala',
  'utils/Logger.vala',
  'utils/ErrorHandler.vala',
  'managers/SettingsManager.vala',
  'dialogs/About.vala',
  'dialogs/KeyboardShortcuts.vala',
  'dialogs/Preferences.vala',
  'widgets/DraughtsBoard.vala',
]

# Generated configuration and resources
draughts_sources += [
  meson.project_build_root() / 'Config.vala'
]

# Add compiled resources
draughts_sources += app_resources

# Main executable
draughts_exe = executable('draughts',
  draughts_sources,
  dependencies: [
    gtk4_dep,
    libadwaita_dep,
    glib_dep,
    gio_dep,
  ],
  install: true,
  install_dir: get_option('bindir')
)