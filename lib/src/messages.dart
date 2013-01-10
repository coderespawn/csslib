// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library messages;

import 'package:logging/logging.dart' show Level;

import 'package:csslib/parser.dart';

import 'package:web_ui/src/file_system/path.dart';
import 'options.dart';
import 'utils.dart';

// TODO(terry): Remove the global messages, use some object that tracks
//              compilation state.

/** The global [Messages] for tracking info/warnings/messages. */
Messages messages;

/** Map between error levels and their display color. */
final Map<Level, String> _ERROR_COLORS = (() {
  // TODO(jmesserly): the SourceSpan printer does not use our colors.
  var colorsMap = new Map<Level, String>();
  colorsMap[Level.SEVERE] = RED_COLOR;
  colorsMap[Level.WARNING] = MAGENTA_COLOR;
  colorsMap[Level.INFO] = GREEN_COLOR;
  return colorsMap;
})();

/** A single message from the compiler. */
class Message {
  final Level level;
  final String message;
  final SourceSpan span;
  final bool useColors;

  Message(this.level, this.message, {SourceSpan span: null,
      bool useColors: false}) : this.span = span, this.useColors = useColors;

  String toString() {
    var output = new StringBuffer();
    bool colors = useColors && _ERROR_COLORS.containsKey(level);
    if (colors) output.add(_ERROR_COLORS[level]);
    output.add(level.name).add(' ');
    if (colors) output.add(NO_COLOR);

    if (span == null) {
      if (span.file != null) output.add('${span.file}: ');
      output.add(message);
    } else {
      output.add(span.toMessageString(
          span.file.toString(), message, useColors: colors));
    }

    return output.toString();
  }
}

typedef void PrintHandler(Object obj);

/**
 * This class tracks and prints information, warnings, and errors emitted by the
 * compiler.
 */
class Messages {
  /** Called on every error. Set to blank function to supress printing. */
  final PrintHandler printHandler;

  final PreprocessorOptions options;

  final List<Message> messages = <Message>[];

  Messages({PreprocessorOptions options, this.printHandler: print})
      : options = options != null ? options : new PreprocessorOptions();

  /** [message] is considered a compile-time CSS error. */
  void error(String message, SourceSpan span) {
    var msg = new Message(Level.SEVERE, message, span: span,
        useColors: options.useColors);

    messages.add(msg);

    printHandler(msg);
  }

  /** [message] is considered a type compile-time CSS warning. */
  void warning(String message, SourceSpan span) {
    if (options.warningsAsErrors) {
      error(message, span);
    } else {
      var msg = new Message(Level.WARNING, message, span: span,
          useColors: options.useColors);

      messages.add(msg);
    }
  }

  /**
   * [message] at [file] will tell the user about what the compiler
   * is doing.
   */
  void info(String message, SourceSpan span, {Path file}) {
    var msg = new Message(Level.INFO, message, span: span,
        useColors: options.useColors);

    messages.add(msg);

    if (options.verbose) printHandler(msg);
  }
}
