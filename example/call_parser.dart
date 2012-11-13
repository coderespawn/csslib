// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a

import 'package:csslib/parser.dart' as Css;

main() {
  var cssErrors = [];

  // Parse a simple stylesheet.
  var stylesheet = Css.parse(
    '.foo { '
      'color: red; left: 20px; top: 20px; width: 100px; height:200px'
    '}'
    '#div {'
      'color : #00F578; border-color: #878787;'
    '}', errors: cssErrors);

  if (!cssErrors.isEmpty) {
    print("Got ${cssErrors.length} errors.\n");
    for (var error in cssErrors) {
      print(error);
    }
  } else {
    print(stylesheet.toString());
  }

  // Parse a stylesheet woth errors
  cssErrors = [];
  var stylesheetError = Css.parse(
    '.foo #%^&*asdf{ '
      'color: red; left: 20px; top: 20px; width: 100px; height:200px'
    '}', errors: cssErrors);

  if (!cssErrors.isEmpty) {
    print("Got ${cssErrors.length} errors.\n");
    for (var error in cssErrors) {
      print(error);
    }
  } else {
    print(stylesheetError.toString());
  }

  // Parse a CSS selector.
  cssErrors = [];
  var selectorAst = Css.selector('#div .foo', errors: cssErrors);
  if (!cssErrors.isEmpty) {
    print("Got ${cssErrors.length} errors.\n");
    for (var error in cssErrors) {
      print(error);
    }
  } else {
    print(selectorAst.toString());
  }

}
