// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a

import 'package:csslib/parser.dart' as css;

/**
 * Spin-up CSS parser in checked mode to detect any problematic CSS.  Normally,
 * CSS will allow any property/value pairs regardless of validity; all of our
 * tests (by default) will ensure that the CSS is really valid.
 */
css.Stylesheet parseCss(String cssInput, {List errors, List opts}) =>
    css.parse(cssInput, errors: errors, options: opts == null ?
        ['--no-colors', '--checked', '--warnings_as_errors', 'memory'] : opts);

main() {
  var cssErrors = [];

  // Parse a simple stylesheet.
  print('1. Good CSS, parsed CSS emitted:');
  print('   =============================');
  var stylesheet = parseCss(
    '@import "support/at-charset-019.css"; div { color: red; }'
    'button[type] { background-color: red; }'
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
    print('${stylesheet.toString()}\n');
  }

  // Parse a stylesheet with errors
  print('2. Catch severe syntax errors:');
  print('   ===========================');
  cssErrors = [];
  var stylesheetError = parseCss(
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

  // Parse a stylesheet that warns (checks) problematic CSS.
  print('3. Detect CSS problem with checking on:');
  print('   ===================================');
  cssErrors = [];
  stylesheetError = parseCss( '# div1 { color: red; }' , errors: cssErrors);

  if (!cssErrors.isEmpty) {
    print("Detected ${cssErrors.length} problem in checked mode.\n");
    for (var error in cssErrors) {
      print(error);
    }
  } else {
    print(stylesheetError.toString());
  }

  // Parse a CSS selector.
  print('4. Parse a selector only:');
  print('   ======================');
  cssErrors = [];
  var selectorAst = css.selector('#div .foo', errors: cssErrors);
  if (!cssErrors.isEmpty) {
    print("Got ${cssErrors.length} errors.\n");
    for (var error in cssErrors) {
      print(error);
    }
  } else {
    print(selectorAst.toString());
  }

}
