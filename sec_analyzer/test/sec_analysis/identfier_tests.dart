import '../test_helpers.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:secdart_analyzer/src/errors.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(IdentifierTests);
  });
}

@reflectiveTest
class IdentifierTests extends AbstractSecDartTest {
  void test_forwardCall() {
    var program = '''
       import "package:secdart/secdart.dart";
       
        @latent("H","H")
        @high callFoo(){
          foo(5);
        }

       @latent("H","H")
       @high foo (@high int s) {
        return 1;
        }
        
      ''';
    var source = newSource("/test.dart", program);
    var result = typeCheckSecurityForSource(source);
    assert(!containsInvalidFlow(result));
  }

  void test_callToFunctionInAnotherFile() {
    var program1 = '''
          import "package:secdart/secdart.dart";
          void g(){
          }
      ''';
    var program2 = '''
          import "package:secdart/secdart.dart";
          import "/test1.dart";
          void f(){
            g();
          }
      ''';
    var source1 = newSource("/test1.dart", program1);
    addSource(source1);
    var source2 = newSource("/test2.dart", program2);
    //typeCheckSecurityForSource(source1);

    var result = typeCheckSecurityForSource(source2);

    assert(!containsInvalidFlow(result));
  }

  void test_callToFunctionInAnotherFileError() {
    var program1 = '''
          import "package:secdart/secdart.dart";          
          void g(@low int a){
          }
      ''';
    var program2 = '''
          import "package:secdart/secdart.dart";
          import "/test1.dart";
          void f(@high int b){
            g(b);
          }
      ''';
    var source1 = newSource("/test1.dart", program1);
    addSource(source1);
    var source2 = newSource("/test2.dart", program2);
    //typeCheckSecurityForSource(source1);

    var result = typeCheckSecurityForSource(source2);

    assert(result.any((e) => e.errorCode == SecurityErrorCode.EXPLICIT_FLOW));
  }

  void test_callToStandardLibraryFunction() {
    var program1 = '''
          import "package:secdart/secdart.dart";
          void g(@high int a){
            print(a);
          }
      ''';
    var source1 = newSource("/test2.dart", program1);
    var result = typeCheckSecurityForSource(source1);

    assert(result.any((e) => e.errorCode == SecurityErrorCode.EXPLICIT_FLOW));
  }
}
