import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){test('SOS session serializes core rescue data',(){final s=SosSession(id:'ABC',ownerId:'u',latitude:1,longitude:2,updatedAt:DateTime.fromMillisecondsSinceEpoch(3),peopleCount:4,profile:const SosProfile(name:'A'));final json=s.toJson();expect(json['peopleCount'],4);expect((json['profile'] as Map)['name'],'A');});}
