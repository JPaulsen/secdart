// This file contains classes and functions that help to build test

import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:front_end/src/base/source.dart';
import 'package:secdart_analyzer_plugin/src/borrow/context.dart';
import 'package:secdart_analyzer_plugin/src/error-collector.dart';
import 'package:secdart_analyzer_plugin/src/gs-typesystem.dart';
import 'package:secdart_analyzer_plugin/src/security_visitor.dart';
import 'package:secdart_analyzer_plugin/src/supported_subset.dart';



bool typeCheckSecurityForSource(Source source,{bool printerError:true}){
  var unit= resolveCompilationUnit2Helper(source);

  ErrorCollector errorListener = new ErrorCollector();
  GradualSecurityTypeSystem typeSystem = new GradualSecurityTypeSystem();

  //var visitor = new SecurityVisitorNoHelp(unit.element.library,null,null,errorListener);
  var visitor = new SecurityVisitor(typeSystem,errorListener);
  unit.accept(visitor);


  if(printerError){
    for(AnalysisError error in errorListener.errors){
      print(error);
    }
  }
  return errorListener.errors.length==0;
}

bool containsOnlySupportedFeatures(Source source,{bool printError:true}){
  var unit= resolveCompilationUnit2Helper(source);

  ErrorCollector errorListener = new ErrorCollector();

  //var visitor = new SecurityVisitorNoHelp(unit.element.library,null,null,errorListener);
  var visitor = new SupportedDartSubsetVisitor(errorListener);
  unit.accept(visitor);

  if(printError){
    for(AnalysisError error in errorListener.errors){
      print(error);
    }
  }
  return errorListener.errors.length==0;
}