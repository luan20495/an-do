import 'package:an_do/core/i18n/app_language_controller.dart';
import 'package:an_do/features/onboarding/presentation/language_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){testWidgets('language gate defaults to Vietnamese',(tester)async{await tester.pumpWidget(MaterialApp(home:LanguageGate(language:AppLanguageController())));expect(find.text('Tiếng Việt'),findsOneWidget);expect(find.text('Tiếp tục'),findsOneWidget);});}
