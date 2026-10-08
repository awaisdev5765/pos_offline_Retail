/// Returns true only for Flutter's known hardware-key state desynchronization
/// assertions. These can occur when a desktop window loses a key-up event
/// during focus changes and must not replace the POS with an error screen.
bool isRecoverableKeyboardStateError(Object error) {
  final message = error.toString();
  final isKeyboardDispatchAssertion = message
      .contains('is dispatched, but the state shows that the physical key');
  final isKnownStateMismatch =
      message.contains('physical key is already pressed') ||
          message.contains('physical key is not pressed') ||
          message.contains('pressed on a different logical key');
  return isKeyboardDispatchAssertion && isKnownStateMismatch;
}
