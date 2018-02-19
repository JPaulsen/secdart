import '../test_helpers.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import "package:secdart_analyzer/src/errors.dart";

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DeclassifyTest);
  });
}

@reflectiveTest
class DeclassifyTest extends AbstractSecDartTest {
  void test_invalidDeclassifyCall() {
    var program = '''
                   
          import "package:secdart/secdart.dart";
          
          @bot int g(@high int a, @high int b,String s){
            return declassify(a+b,s);
          }
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);

    assert(result
        .any((x) => x.errorCode == SecurityErrorCode.INVAlID_DECLASSIFY_CALL));
  }

  void test_declassifyWorks() {
    var program = '''
                   
          import "package:secdart/secdart.dart";
          
          @low int g(@high int a, @high int b){
            return declassify(a+b,"L");
          }
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);

    assert(result.isEmpty);
  }

  void test_declassifyToIntermediateLabel() {
    var program = '''
                   
          import "package:secdart/secdart.dart";
          
          @bot int g(@high int a, @high int b){
            return declassify(a+b,"L");
          }
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);

    assert(
        result.any((x) => x.errorCode == SecurityErrorCode.RETURN_TYPE_ERROR));
  }
}
