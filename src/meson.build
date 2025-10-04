# Source files
draughts_sources = [
  'Main.vala',
  'Application.vala',
  'Window.vala',
  'Constants.vala',
  'utils/Logger.vala',
  'utils/ErrorHandler.vala',
  'utils/ResourceManager.vala',
  'utils/KeyboardNavigationHandler.vala',
  'utils/AccessibilityAnnouncer.vala',
  'managers/SettingsManager.vala',
  'managers/SoundManager.vala',
  'managers/MoveHistoryManager.vala',
  'managers/GameHistoryManager.vala',
  'dialogs/About.vala',
  'dialogs/HelpDialog.vala',
  'dialogs/KeyboardShortcuts.vala',
  'dialogs/Preferences.vala',
  'dialogs/VariantSelector.vala',
  'dialogs/VariantRulesDialog.vala',
  'dialogs/GamePreferences.vala',
  'dialogs/GameEndDialog.vala',
  'dialogs/GameHistoryDialog.vala',
  'dialogs/GameReplayDialog.vala',
  'dialogs/NewGameDialog.vala',
  'dialogs/MultiplayerDialog.vala',
  'widgets/DraughtsBoard.vala',

  # Draughts widgets
  'widgets/DraughtsBoardAdapter.vala',
  'widgets/BoardRenderer.vala',
  'widgets/BoardInteractionHandler.vala',
  'widgets/GameControls.vala',
  'widgets/TimerDisplay.vala',
  'widgets/MoveHistory.vala',

  # Draughts game models
  'models/draughts/DraughtsConstants.vala',
  'models/draughts/BoardPosition.vala',
  'models/draughts/GamePiece.vala',
  'models/draughts/DraughtsMove.vala',
  'models/draughts/DraughtsGameState.vala',
  'models/draughts/GameVariant.vala',
  'models/draughts/GamePlayer.vala',
  'models/draughts/Timer.vala',
  'models/draughts/Game.vala',
  'models/draughts/GameHistory.vala',

  # Draughts game services
  'services/draughts/IRuleEngine.vala',
  'services/draughts/BaseRuleEngine.vala',
  'services/draughts/BoardValidator.vala',
  'services/draughts/MoveGenerator.vala',
  'services/draughts/IAIPlayer.vala',
  'services/draughts/PositionEvaluator.vala',
  'services/draughts/MinimaxAI.vala',
  'services/draughts/AIDifficultyManager.vala',
  'services/draughts/IGameController.vala',
  'services/draughts/GameController.vala',
  'services/draughts/TimerController.vala',

  # Network multiplayer services
  'services/network/NetworkMessage.vala',
  'services/network/NetworkClient.vala',
  'services/network/NetworkSession.vala',
  'services/network/MultiplayerGameController.vala',

  # Draughts variant rule engines
  'services/draughts/UnifiedRuleEngine.vala',
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
    gee_dep,
    libsoup_dep,
    dependency('json-glib-1.0'),
    dependency('gstreamer-1.0'),
    declare_dependency(link_args: ['-lm']),
  ],
  install: true,
  install_dir: get_option('bindir')
)