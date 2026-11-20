import 'package:allen_ai/agent/confirmation_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const yes = ['yes', 'Yes please', 'okay', 'go ahead', 'ha', 'ha koro', 'thik ache', 'হ্যাঁ', 'ঠিক আছে', 'করো', 'ওকে', 'পাঠাও'];
  const no = ['no', 'No!', 'cancel', 'na', 'thak', 'না', 'থাক', 'বাদ দাও', 'করো না', 'stop', 'don t'];
  for (final s in yes) {
    test('yes: $s', () => expect(ConfirmationManager.parseAnswer(s), true));
  }
  for (final s in no) {
    test('no: $s', () => expect(ConfirmationManager.parseAnswer(s), false));
  }
  test('unclear', () {
    expect(ConfirmationManager.parseAnswer('hmm'), isNull);
    expect(ConfirmationManager.parseAnswer(''), isNull);
  });
  test('stop words', () {
    expect(ConfirmationManager.isStop('Allen stop'), true);
    expect(ConfirmationManager.isStop('থামো'), true);
    expect(ConfirmationManager.isStop('open youtube'), false);
    expect(ConfirmationManager.isStop('গান থামাও'), false); // pause music is not the kill switch
  });
}
