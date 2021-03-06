import 'package:test/test.dart';

import '../test_helpers.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:secdart_analyzer/src/errors.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ImplicitFlowsTest);
  });
}

@reflectiveTest
class ImplicitFlowsTest extends AbstractSecDartTest {
  void test_implicitFlow1() {
    var program = '''
        import "package:secdart/secdart.dart";
        @latent("L","L")
        @low foo (@high bool s) {
          @low bool a = false;
          if(s){
            a = true; //Must be rejected (pc here must be H)
          }
          else{
            a = false;
          }
          return 1;
        }
      ''';
    var source = newSource("/test.dart", program);
    var resultWithIntervals = typeCheckSecurityForSource(source,
        config: intervalModeWithDefaultLatticeConfig);

    var resultWithoutNoIntervals = typeCheckSecurityForSource(source);

    expect(
        resultWithIntervals
            .where((e) => e.errorCode == SecurityErrorCode.EXPLICIT_FLOW),
        isNotEmpty);

    expect(resultWithoutNoIntervals, isEmpty);
  }

  void test_noImplicitFlow() {
    var program = '''
        import "package:secdart/secdart.dart";
        @latent("L","L")
        @low foo (@low bool s) {
          @low bool a = false;
          if(s){
            a = true;
          }
          else{
            a = false;
          }
          return 1;
        }
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);

    expect(containsInvalidFlow(result), isFalse);
  }

  void test_implicitFlow2() {
    var program = '''
        import "package:secdart/secdart.dart";
        @latent("L","L")
        @low foo (@high bool s) {
          @low bool a = true;
          @low bool b = false;
          @low bool r = false;
          if(s){
            r = a; //Must be rejected (pc here must be H)
          }
          else{
            r = b;
          }
          return 1;
        }
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);
    var resultWithIntervals = typeCheckSecurityForSource(source,
        config: intervalModeWithDefaultLatticeConfig);

    expect(result, isEmpty);
    expect(
        resultWithIntervals
            .where((e) => e.errorCode == SecurityErrorCode.IMPLICIT_FLOW),
        isNotEmpty);
  }
}
