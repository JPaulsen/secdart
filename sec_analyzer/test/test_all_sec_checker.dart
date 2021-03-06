import 'sec_analysis/fun_call_test.dart' as fun_call;
import 'sec_analysis/fun_decl_test.dart' as function;
import 'sec_analysis/high_order_tests.dart' as high_order;
import 'sec_analysis/implicit_flow_tests.dart' as implicit;
import 'sec_analysis/identfier_tests.dart' as identifier;
import 'sec_analysis/ds_ecoop.dart' as ds_ecoop;
import 'sec_analysis/dart_standard_test.dart' as dart_errors;
import 'sec_analysis/class_declaration_test.dart' as class_decl;
import 'sec_analysis/using_class_test.dart' as using_classes;
import 'sec_analysis/declassify.dart' as declassify;
import 'sec_analysis/loops_test.dart' as loops;

import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    //security analysis tests
    function.main();
    fun_call.main();
    high_order.main();
    implicit.main();
    identifier.main();
    ds_ecoop.main();
    dart_errors.main();
    class_decl.main();
    using_classes.main();
    declassify.main();
    loops.main();
  });
}
