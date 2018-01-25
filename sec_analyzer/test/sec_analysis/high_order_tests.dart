import '../test_helpers.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:secdart_analyzer/src/errors.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(HighOrderFunctionTest);
  });
}

@reflectiveTest
class HighOrderFunctionTest extends AbstractSecDartTest {
  void test_callingDynamicFunctionPassedAsParameter() {
    var program = '''
        import "package:secdart/secdart.dart";
        void foo (f) {
          f();
        }
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);

    assert(!containsInvalidFlow(result));
  }

  void test_3() {
    var program = '''
        import "package:secdart/secdart.dart";
        void callWithSecret(void f(@low bool)) {
          @high bool secret = true;
          f(secret);
        }
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);

    assert(result.any((e) => e.errorCode == SecurityErrorCode.EXPLICIT_FLOW));
  }
}
