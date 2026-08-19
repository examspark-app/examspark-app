/// Voice-turn timing for English Roleplay. Keep turn detection centralized.
class RoleplayVoiceConfig {
  RoleplayVoiceConfig._();

  /// After actual speech ends, finish and submit this one recorded turn.
  static const endOfTurnSilence = Duration(milliseconds: 1800);

  /// A gentle nudge for a listener who has not started speaking yet.
  static const firstSpeechPromptDelay = Duration(seconds: 5);

  /// Keep the gentle nudge brief so it never obstructs the voice screen.
  static const speechPromptVisibleFor = Duration(seconds: 3);

  /// No user voice for one minute ends this active roleplay session.
  static const sessionInactivityTimeout = Duration(minutes: 1);
}
