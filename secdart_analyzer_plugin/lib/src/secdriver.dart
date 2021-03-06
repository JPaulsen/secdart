import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/file_state.dart';

import "package:secdart_analyzer/analyzer.dart";
import 'package:secdart_analyzer/src/options.dart';

abstract class NotificationManager {
  void recordAnalysisErrors(
      String path, LineInfo lineInfo, List<AnalysisError> analysisErrors);
}

class SecDriver implements AnalysisDriverGeneric {
  final NotificationManager notificationManager;
  final AnalysisDriverScheduler _scheduler;
  final AnalysisDriver dartDriver;
  SourceFactory _sourceFactory;
  final FileContentOverlay _contentOverlay;
  final SecDartOptions options;

  final _addedFiles = new LinkedHashSet<String>();
  final _dartFiles = new LinkedHashSet<String>();
  final _changedFiles = new LinkedHashSet<String>();
  final _filesToAnalyze = new HashSet<String>();
  final _requestedDartFiles = new Map<String, List<Completer>>();

  SecDriver(this.notificationManager, this.dartDriver, this._scheduler,
      SourceFactory sourceFactory, this._contentOverlay, this.options) {
    _sourceFactory = sourceFactory.clone();
    _scheduler.add(this);

    //_hasSecDefinitionsImported = _sourceFactory.resolveUri(null, "package:secdart/model.dart") !=null;
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }

  @override
  bool get hasFilesToAnalyze => _filesToAnalyze.isNotEmpty;

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
  @override
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
    notificationManager.recordAnalysisErrors(path, lineInfo, errors);
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
    if (result.errors != null) {
      var realErrors = result.errors
          .where((e) => e.errorCode.errorSeverity == ErrorSeverity.ERROR)
          .toList();
      if (realErrors.length != 0) {
        return new SecResult(realErrors);
      }
    }

    final unitAst = unit.element.computeNode();
    var errors = SecAnalyzer.computeErrors(
        unitAst,
        new SecAnalysisConfig(
            options.intervalMode, LatticeConfig.defaultLattice));
    return new SecResult(errors);
  }

  Future<LatticeConfig> _readLatticeFile(String latticePath)async {
    final file = new File(latticePath);
    final exists = await file.exists();
    if(exists){
      final content = await file.readAsString();
      final latticeFile = new LatticeFile.from(content);
      return LatticeConfig.from(latticeFile);
    }
    return null;
  }
}


class SecResult {
  List<AnalysisError> errors;

  SecResult(this.errors);
}
