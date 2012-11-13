// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library compiler;

import 'dart:collection' show SplayTreeMap;
import 'dart:coreimpl';

import 'file_system.dart';
import 'file_system/path.dart';
import 'files.dart';
import 'messages.dart';
import 'options.dart';
import 'package:csslib/parser.dart';
import 'utils.dart';

/**
 * Parses a CSS file [contents] and returns a Stylesheet tree.
 * Note that [contents] will be a [String] if coming from a browser-based
 * [FileSystem], or it will be a [List<int>] if running on the command line.
 */
Stylesheet parseCSS(sourceFile) => new Parser(sourceFile).parse();

/** Main entry point for tooling of CSS parser. */
class Compiler {
  final FileSystem filesystem;
  final PreprocessorOptions options;
  final List<SourceFile> files = <SourceFile>[];
  final List<OutputFile> output = <OutputFile>[];

  Path _mainPath;

  Compiler(this.filesystem, this.options, [String currentDir]) {
    _mainPath = new Path(options.inputFile);
    var mainDir = _mainPath.directoryPath;
    var basePath =
        options.baseDir != null ? new Path(options.baseDir) : mainDir;
    var outputPath =
        options.outputDir != null ? new Path(options.outputDir) : mainDir;

    // Normalize paths - all should be relative or absolute paths.
    bool anyAbsolute = _mainPath.isAbsolute || basePath.isAbsolute ||
        outputPath.isAbsolute;
    bool allAbsolute = _mainPath.isAbsolute && basePath.isAbsolute &&
        outputPath.isAbsolute;
    if (anyAbsolute && !allAbsolute) {
      if (currentDir == null)  {
        messages.error('internal error: could not normalize paths. Please make '
            'the input, base, and output paths all absolute or relative, or '
            'specify "currentDir" to the Compiler constructor', null);
        return;
      }
      var currentPath = new Path(currentDir);
      if (!_mainPath.isAbsolute) _mainPath = currentPath.join(_mainPath);
      if (!basePath.isAbsolute) basePath = currentPath.join(basePath);
      if (!outputPath.isAbsolute) outputPath = currentPath.join(outputPath);
    }
  }

  /** Compile the application starting from the given [mainFile]. */
  Future run() {
    if (!_mainPath.filename.endsWith('.css') && !_mainPath.filename.endsWith('.scss')) {
      messages.error("Please provide a CSS/Sass file as your entry point.",
          null);
      return new Future.immediate(null);
    }
    return _parseAndDiscover(_mainPath).transform((_) {
      _analyze();
      _emit();
      return null;
    });
  }

  /**
   * Asynchronously parse [inputFile] and transitively discover all stylesheets
   * to load and parse. Returns a future that completes when all files are
   * processed.
   */
  Future _parseAndDiscover(Path inputFile) {
    var tasks = new FutureGroup();
    bool isEntry = true;

    processCSSFile(SourceFile file) {
      files.add(file);
    }

    tasks.add(_parseCSSFile(inputFile).transform(processCSSFile));
    return tasks.future;
  }

  /** Asynchronously parse [path] as an .html file. */
  Future<SourceFile> _parseCSSFile(Path path) {
    return (filesystem.readTextOrBytes(path)
        ..handleException((e) => _readError(e, path)))
        .transform((source) {
          var file = new SourceFile(path);
          file.text = new String.fromCharCodes(source);
          file.tree = _time('Parsed', path, () => parseCSS(file));
          return file;
        });
  }

  bool _readError(error, Path path) {
    messages.error('exception while reading file $path, '
                   'original message:\n $error', null);
    return true;
  }

  /** Run the analyzer on every input html file. */
  void _analyze() {
    for (var file in files) {
      _time('Analyze', file.path, () {
        // TODO(terry): Hookup the analyzer.
        // _analyzeFile(file, info));
      });
    }
  }

  /** Emit the generated code corresponding to each input file. */
  void _emit() {
    for (var file in files) {
      _time('Codegen', file.path, () {
        file.path.directoryPath;
        var outName = "${file.path.directoryPath}/_${file.path.filename}";
        output.add(new OutputFile(new Path(outName), file.tree.toString()));
      });
    }
  }

  _time(String logMessage, Path path, callback(), {bool printTime: false}) {
    var message = new StringBuffer();
    message.add(logMessage);
    for (int i = (60 - logMessage.length - path.filename.length); i > 0 ; i--) {
      message.add(' ');
    }
    message.add(path.filename);
    return time(message.toString(), callback,
        printTime: options.verbose || printTime);
  }

}