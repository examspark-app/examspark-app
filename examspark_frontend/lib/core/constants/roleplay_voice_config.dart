/// Voice-turn timing for English Roleplay. Keep turn detection centralized.
class RoleplayVoiceConfig {
  RoleplayVoiceConfig._();

  /// After actual speech ends, finish and submit this one recorded turn.
  static const endOfTurnSilence = Duration(milliseconds: 1800);

  /// No user voice after an AI reply ends this active roleplay session.
  static const sessionInactivityTimeout = Duration(seconds: 45);
}
