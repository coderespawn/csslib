// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library css;

import 'dart:coreimpl';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as Math;

import 'src/compiler.dart';
import 'src/file_system.dart';
import 'src/file_system/console.dart';
import 'src/file_system/path.dart' as fs;
import 'src/generate.dart';
import 'src/messages.dart';
import 'src/options.dart';
import 'src/styleimpl/styleimpl.dart';
import 'src/utils.dart';
import 'src/validate.dart';

FileSystem fileSystem;

void main() {
  run(new Options().arguments);
}

// TODO(jmesserly): fix this to return a proper exit code
Future run(List<String> args) {
  var options = PreprocessorOptions.parse(args);
  if (options == null) return new Future.immediate(null);

  fileSystem = new ConsoleFileSystem();
  messages = new Messages(options: options);

  return asyncTime('Total time spent on ${options.inputFile}', () {
    var currentDir = new Directory.current().path;
    var compiler = new Compiler(fileSystem, options, currentDir);
    return compiler.run().chain((_) {
      // Write out the code associated with each source file.
      for (var file in compiler.output) {
        writeFile(file.path, file.contents, options.clean);
      }
      return fileSystem.flush();
    });
  }, printTime: true);
}

void writeFile(fs.Path path, String contents, bool clean) {
  if (clean) {
    File fileOut = new File.fromPath(_convert(path));
    if (fileOut.existsSync()) {
      fileOut.deleteSync();
    }
  } else {
    _createIfNeeded(_convert(path.directoryPath));
    fileSystem.writeString(path, contents);
  }
}

void _createIfNeeded(Path outdir) {
  if (outdir.isEmpty) return;
  var outDirectory = new Directory.fromPath(outdir);
  if (!outDirectory.existsSync()) {
    _createIfNeeded(outdir.directoryPath);
    outDirectory.createSync();
  }
}

// TODO(sigmund): this conversion from dart:io paths to internal paths should
// go away when dartbug.com/5818 is fixed.
Path _convert(fs.Path path) => new Path(path.toString());
