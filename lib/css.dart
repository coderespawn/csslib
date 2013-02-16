// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library css;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as Math;

import 'package:pathos/path.dart' as path;

import 'parser.dart';
import 'visitor.dart';
import 'src/files.dart';
import 'src/messages.dart';
import 'src/options.dart';

void main() {
  // TODO(jmesserly): fix this to return a proper exit code
  var options = PreprocessorOptions.parse(new Options().arguments);
  if (options == null) return;

  messages = new Messages(options: options);

  _time('Total time spent on ${options.inputFile}', () {
    _compile(options.inputFile, options.verbose);
  }, true);
}

void _compile(String inputPath, bool verbose) {
  var ext = path.extension(inputPath);
  if (ext != '.css' && ext != '.scss') {
    messages.error("Please provide a CSS/Sass entry point.", null);
    return;
  }
  try {
    // Read the file.
    var filename = path.basename(inputPath);
    var file = new SourceFile(inputPath,
        source: new File(inputPath).readAsStringSync());

    // Parse the CSS.
    file.tree = _time('Parse $filename',
        () => new Parser(file).parse(), verbose);

    // Emit the processed CSS.
    var emitter = new CssPrinter();
    _time('Codegen $filename',
        () => emitter.visitTree(file.tree, pretty: true), verbose);

    // Dump the contents to a file.
    var outPath = path.join(path.dirname(inputPath), '_$filename');
    new File(outPath).writeAsStringSync(emitter.toString());
  } catch (e) {
    messages.error('error processing $inputPath. Original message:\n $e', null);
  }
}

_time(String message, callback(), bool printTime) {
  final watch = new Stopwatch();
  watch.start();
  var result = callback();
  watch.stop();
  final duration = watch.elapsedMilliseconds;
  if (printTime) {
    _printMessage(message, duration);
  }
  return result;
}

void _printMessage(String message, int duration) {
  var buf = new StringBuffer();
  buf.add(message);
  for (int i = message.length; i < 60; i++) buf.add(' ');
  buf.add(' -- ');
  if (duration < 10) buf.add(' ');
  if (duration < 100) buf.add(' ');
  buf..add(duration)..add(' ms');
  print(buf.toString());
}
