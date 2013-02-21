// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library error_test;

import 'package:unittest/unittest.dart';
import 'testing.dart';
import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';

// Pretty printer for CSS.
var emitCss = new CssPrinter();
String prettyPrint(StyleSheet ss) =>
    (emitCss..visitTree(ss, pretty: true)).toString();

/**
 * Test for unsupported font-weights values of bolder, lighter and inherit.
 */
void testUnsupportedFontWeights() {
  var cssErrors = [];

  // TODO(terry): Need to support bolder.
  // font-weight value bolder.
  var input = ".foobar { font-weight: bolder; }";
  var stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:24: Unknown property value bolder
.foobar { font-weight: bolder; }
                       ^^^^^^''');
  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), r'''
.foobar {
  font-weight: bolder;
}''');

  // TODO(terry): Need to support lighter.
  // font-weight value lighter.
  cssErrors = [];
  input = ".foobar { font-weight: lighter; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:24: Unknown property value lighter
.foobar { font-weight: lighter; }
                       ^^^^^^^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  font-weight: lighter;
}''');

  // TODO(terry): Need to support inherit.
  // font-weight value inherit.
  cssErrors = [];
  input = ".foobar { font-weight: inherit; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:24: Unknown property value inherit
.foobar { font-weight: inherit; }
                       ^^^^^^^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  font-weight: inherit;
}''');
}

/**
 * Test for unsupported line-height values of units other than px, pt and
 * inherit.
 */
void testUnsupportedLineHeights() {
  var cssErrors = [];

  // line-height value in percentge unit.
  var input = ".foobar { line-height: 120%; }";
  var stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:24: Unexpected value for line-height
.foobar { line-height: 120%; }
                       ^^^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  line-height: 120%;
}''');

  // TODO(terry): Need to support all units.
  // line-height value in cm unit.
  cssErrors = [];
  input = ".foobar { line-height: 20cm; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:24: Unexpected unit for line-height
.foobar { line-height: 20cm; }
                       ^^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  line-height: 20cm;
}''');

  // TODO(terry): Need to support inherit.
  // line-height value inherit.
  cssErrors = [];
  input = ".foobar { line-height: inherit; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:24: Unknown property value inherit
.foobar { line-height: inherit; }
                       ^^^^^^^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  line-height: inherit;
}''');
}

/** Test for bad selectors. */
void testBadSelectors() {
  var cssErrors = [];

  // Invalid id selector.
  var input = "# foo { color: #ff00ff; }";
  var stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:1: Not a valid ID selector expected #id
# foo { color: #ff00ff; }
^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
# foo {
  color: #f0f;
}''');

  // Invalid class selector.
  cssErrors = [];
  input = ". foo { color: #ff00ff; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:1: Not a valid class selector expected .className
. foo { color: #ff00ff; }
^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
. foo {
  color: #f0f;
}''');
}

/** Test for bad hex values. */
void testBadHexValues() {
  var cssErrors = [];

  // Invalid hex value.
  var input = ".foobar { color: #AH787; }";
  var stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:18: Bad hex number
.foobar { color: #AH787; }
                 ^^^^^^''');
  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: #AH787;
}''');

  // Bad color constant.
  cssErrors = [];
  input = ".foobar { color: redder; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:18: Unknown property value redder
.foobar { color: redder; }
                 ^^^^^^''');

  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: redder;
}''');

  // Bad hex color #<space>ffffff.
  cssErrors = [];
  input = ".foobar { color: # ffffff; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:18: Expected hex number
.foobar { color: # ffffff; }
                 ^''');

  expect(stylesheet != null, true);
  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: # ffffff;
}''');

  // Bad hex color #<space>123fff.
  cssErrors = [];
  input = ".foobar { color: # 123fff; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
error :1:18: Expected hex number
.foobar { color: # 123fff; }
                 ^''');

  expect(stylesheet != null, true);

  // Formating is off with an extra space.  However, the entire value is bad
  // and isn't processed anyway.
  expect(prettyPrint(stylesheet), r'''
.foobar {
  color: # 123 fff;
}''');

}

main() {
  test('font-weight value errors', testUnsupportedFontWeights);
  test('line-height value errors', testUnsupportedLineHeights);
  test('bad selectors', testBadSelectors);
  test('bad Hex values', testBadHexValues);
}
