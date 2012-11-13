// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library utils;

import 'dart:coreimpl';
import 'messages.dart';

/**
 * Converts a string name with hyphens into an identifier, by removing hyphens
 * and capitalizing the following letter.
 */
String toCamelCase(String hyphenedName) {
  var segments = hyphenedName.split('-');
  for (int i = 1; i < segments.length; i++) {
    var segment = segments[i];
    if (segment.length > 0) {
      // Character between 'a'..'z' mapped to 'A'..'Z'
      segments[i] = '${segment[0].toUpperCase()}${segment.substring(1)}';
    }
  }
  return Strings.join(segments, '');
}

/**
 * Invokes [callback], logs how long it took to execute in ms, and returns
 * whatever [callback] returns. The log message will be printed if [printTime]
 * is true.
 */
time(String logMessage, callback(), {bool printTime: false}) {
  final watch = new Stopwatch();
  watch.start();
  var result = callback();
  watch.stop();
  final duration = watch.elapsedMilliseconds;
  if (printTime) {
    _printMessage(logMessage, duration);
  }
  return result;
}

/**
 * Invokes [callback], logs how long it takes from the moment [callback] is
 * executed until the future it returns is completed. Returns the future
 * returned by [callback]. The log message will be printed if [printTime]
 * is true.
 */
Future asyncTime(String logMessage, Future callback(),
                 {bool printTime: false}) {
  final watch = new Stopwatch();
  watch.start();
  return callback()..then((_) {
    watch.stop();
    final duration = watch.elapsedMilliseconds;
    if (printTime) {
      _printMessage(logMessage, duration);
    }
  });
}

void _printMessage(String logMessage, int duration) {
  var buf = new StringBuffer();
  buf.add(logMessage);
  for (int i = logMessage.length; i < 60; i++) buf.add(' ');
  buf.add(' -- ').add(GREEN_COLOR);
  if (duration < 10) buf.add(' ');
  if (duration < 100) buf.add(' ');
  buf.add(duration).add(' ms').add(NO_COLOR);
  print(buf.toString());
}

// Color constants used for generating messages.
final String GREEN_COLOR = '\u001b[32m';
final String RED_COLOR = '\u001b[31m';
final String MAGENTA_COLOR = '\u001b[35m';
final String NO_COLOR = '\u001b[0m';

/** Find and return the first element in [list] that satisfies [matcher]. */
find(List list, bool matcher(elem)) {
  for (var elem in list) {
    if (matcher(elem)) return elem;
  }
  return null;
}


/** A completer that waits until all added [Future]s complete. */
// TODO(sigmund): this should be part of the futures/core libraries.
class FutureGroup {
  const _FINISHED = -1;
  int _pending = 0;
  Completer<List> _completer = new Completer<List>();
  final List<Future> futures = <Future>[];

  /**
   * Wait for [task] to complete (assuming this barrier has not already been
   * marked as completed, otherwise you'll get an exception indicating that a
   * future has already been completed).
   */
  void add(Future task) {
    if (_pending == _FINISHED) {
      throw new FutureAlreadyCompleteException();
    }
    _pending++;
    futures.add(task);
    task.handleException(
        (e) => _completer.completeException(e, task.stackTrace));
    task.then((_) {
      _pending--;
      if (_pending == 0) {
        _pending = _FINISHED;
        _completer.complete(futures);
      }
    });
  }

  Future<List> get future => _completer.future;
}
