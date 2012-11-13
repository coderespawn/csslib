// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library options;

import 'package:args/args.dart';

class PreprocessorOptions {
  /** Report warnings as errors. */
  final bool warningsAsErrors;

  /** Throw an exception on warnings (not used by command line tool). */
  final bool throwOnWarnings;

  /** Throw an exception on errors (not used by command line tool). */
  final bool throwOnErrors;

  /** True to show informational messages. The `--verbose` flag. */
  final bool verbose;

  /** Remove any generated files. */
  final bool clean;

  /** Whether to use colors to print messages on the terminal. */
  final bool useColors;

  /** File to process by the compiler. */
  String inputFile;

  /** Directory where all sources are found. */
  final String baseDir;

  /** Directory where all output will be generated. */
  final String outputDir;

  // We could make this faster, if it ever matters.
  factory PreprocessorOptions() => parse(['']);

  PreprocessorOptions.fromArgs(ArgResults args)
    : warningsAsErrors = args['warnings_as_errors'],
      throwOnWarnings = args['throw_on_warnings'],
      throwOnErrors = args['throw_on_errors'],
      verbose = args['verbose'],
      clean = args['clean'],
      useColors = args['colors'],
      baseDir = args['basedir'],
      outputDir = args['out'],
      inputFile = args.rest.length > 0 ? args.rest[0] : null;

  // tool.dart [options...] <css file>
  static PreprocessorOptions parse(List<String> arguments) {
    var parser = new ArgParser()
      ..addFlag('clean', help: 'Remove all generated files', defaultsTo: false,
          negatable: false)
      ..addOption('out', abbr: 'o', help: 'Directory location to generate files'
          ' (defaults to the same directory as the source file)')
      ..addOption('basedir', help: 'Base directory location to find all source '
          'files (defaults to the source file\'s directory)')
      ..addFlag('verbose',  abbr: 'v', defaultsTo: false, negatable: false,
          help: 'Display detail info')
      ..addFlag('suppress_warnings', defaultsTo: true, negatable: false,
          help: 'Warnings not displayed')
      ..addFlag('warnings_as_errors', defaultsTo: false,
          help: 'Warning handled as errors')
      ..addFlag('throw_on_errors', defaultsTo: false,
          help: 'Throw on errors encountered')
      ..addFlag('throw_on_warnings', defaultsTo: false,
          help: 'Throw on warnings encountered')
      ..addFlag('colors', defaultsTo: true,
          help: 'Display errors/warnings in colored text')
      ..addFlag('help', abbr: 'h', defaultsTo: false, negatable: false,
          help: 'Displays this help message');

    try {
      var results = parser.parse(arguments);
      if (results['help'] || results.rest.length == 0) {
        showUsage(parser);
        return null;
      }
      return new PreprocessorOptions.fromArgs(results);
    } on FormatException catch (e) {
      print(e.message);
      showUsage(parser);
      return null;
    }
  }

  static showUsage(parser) {
    print('Usage: css [options...] input.css');
    print(parser.getUsage());
  }

}
