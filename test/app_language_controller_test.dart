import 'package:an_do/core/i18n/app_language_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Vietnamese is default and explicit choice is persisted',()async{
    SharedPreferences.setMockInitialValues({});
    final c=AppLanguageController(); await c.load();
    expect(c.locale.languageCode,'vi'); expect(c.hasChosenLanguage,false);
    await c.choose('en'); expect(c.locale.languageCode,'en'); expect(c.hasChosenLanguage,true);
    final next=AppLanguageController(); await next.load(); expect(next.locale.languageCode,'en');
  });
}
