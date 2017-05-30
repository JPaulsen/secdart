import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analysis_server/plugin/protocol/protocol_dart.dart' as protocol;
import 'package:analysis_server/src/protocol_server.dart' as protocol;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
//import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/dart/analysis/file_state.dart';

import 'package:secdart_analyzer/src/error-collector.dart';
import 'package:secdart_analyzer/src/errors.dart';
import 'package:secdart_analyzer/src/gs-typesystem.dart';
import 'package:secdart_analyzer/src/security_visitor.dart';


class SecDriver  implements AnalysisDriverGeneric{
  final AnalysisServer server;
  final AnalysisDriverScheduler _scheduler;
  final AnalysisDriver dartDriver;
  SourceFactory _sourceFactory;
  final FileContentOverlay _contentOverlay;

  final _addedFiles = new LinkedHashSet<String>();
  final _dartFiles = new LinkedHashSet<String>();
  final _changedFiles = new LinkedHashSet<String>();
  final _filesToAnalyze = new HashSet<String>();
  final _requestedDartFiles = new Map<String, List<Completer>>();

  bool _hasSecDefinitionsImported = false;

  SecDriver(this.server, this.dartDriver, this._scheduler,SourceFactory sourceFactory,this._contentOverlay) {
    _sourceFactory = sourceFactory.clone();
    _scheduler.add(this);

    //_hasSecDefinitionsImported = _sourceFactory.resolveUri(null, "package:secdart/model.dart") !=null;
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }

  // TODO: implement hasFilesToAnalyze
  @override
  bool get hasFilesToAnalyze =>  _filesToAnalyze.isNotEmpty;

  @override
  Future<Null> performWork() async {
    if (_requestedDartFiles.isNotEmpty) {
      final path = _requestedDartFiles.keys.first;
      final completers = _requestedDartFiles.remove(path);
      // Note: We can't use await here, or the dart analysis becomes a future in
      // a queue that won't be completed until the scheduler schedules the dart
      // driver, which doesn't happen because its waiting for us.
      //resolveDart(path).then((result) {
      _resolveSecDart(path).then((result) {
        completers
            .forEach((completer) => completer.complete(result?.errors ?? []));
      }, onError: (e) {
        completers.forEach((completer) => completer.completeError(e));
      });
      return;
    }
    if (_changedFiles.isNotEmpty) {
      _changedFiles.clear();
      _filesToAnalyze.addAll(_dartFiles);
      return;
    }
    if (_filesToAnalyze.isNotEmpty) {
      final path = _filesToAnalyze.first;
      pushDartErrors(path);
      _filesToAnalyze.remove(path);
      return;
    }
    return;
  }

  @override
  set priorityFiles(List<String> priorityPaths) {
    // TODO: implement priorityFiles
  }

  // TODO: implement workPriority
  @override
  AnalysisDriverPriority get workPriority => AnalysisDriverPriority.general;


  //Methods to manage file changes
  void addFile(String path) {
    if (_ownsFile(path)) {
      _addedFiles.add(path);
      _dartFiles.add(path);
      fileChanged(path);
    }
  }

  void fileChanged(String path) {
    if (_ownsFile(path)) {
        _changedFiles.add(path);
    }
    _scheduler.notify(this);
  }

  //private methods
  bool _ownsFile(String path) {
    return path.endsWith('.dart');
  }

  Future pushDartErrors(String path) async {
    final result = await _resolveSecDart(path);
    if (result == null) return;
    final errors = new List<AnalysisError>.from(result.errors);
    final lineInfo = new LineInfo.fromContent(getFileContent(path));
    final serverErrors = protocol.doAnalysisError_listFromEngine(
        dartDriver.analysisOptions, lineInfo, errors);
    server.notificationManager
        .recordAnalysisErrors("secPlugin", path, serverErrors);
  }

  String getFileContent(String path) {
    return _contentOverlay[path] ??
        ((source) =>
        source.exists() ? source.contents.data : "")(getSource(path));
  }
  Source getSource(String path) =>
      _sourceFactory.resolveUri(null, 'file:' + path);

 /* Future<SecResult> resolveDart(String path) async {
    final unitAst = await dartDriver.getUnitElement(path);
    final unit = unitAst.element;
    if (unit == null) return null;
    AnalysisError error = SecurityTypeError.getDummyError(unit);
    var list = new List<AnalysisError>();
    list.add(error);
    return new SecResult(list);
  }*/


  //public api
  Future<List<AnalysisError>> requestDartErrors(String path) {
    var completer = new Completer<List<AnalysisError>>();
    _requestedDartFiles
        .putIfAbsent(path, () => <Completer<List<AnalysisError>>>[])
        .add(completer);
    _scheduler.notify(this);
    return completer.future;
  }

  Future<SecResult> _resolveSecDart(String path) async {
    final unit = await dartDriver.getUnitElement(path);
    final result = await dartDriver.getResult(path);
    if (unit.element == null) return null;

    //TODO: Filter error in a better way...
    if(result.errors!=null) {
      var realErrors = result.errors.where((e)=>e.errorCode.errorSeverity == ErrorSeverity.ERROR).toList();
      if(realErrors.length!=0) {
        AnalysisError error = SecurityTypeError.getImplementationError(
            unit.element.computeNode(),
            "Proof-of-concept error. Standard Dart error:" +
                realErrors.first.message);
        var list = new List<AnalysisError>();
        list.add(error);
        return new SecResult(list);
      }
    }

    final unitAst = unit.element.computeNode();

    ErrorCollector errorListener = new ErrorCollector();
    GradualSecurityTypeSystem typeSystem = new GradualSecurityTypeSystem();
    var visitor = new SecurityVisitor(typeSystem,errorListener);
    unitAst.accept(visitor);

    var errors = new List<AnalysisError>();
    errors.addAll(errorListener.errors);
    return new SecResult(errors);
  }
}
class SecResult{
  List<AnalysisError> errors;
  SecResult(this.errors);
}

