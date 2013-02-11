// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library declaration_test;

import 'package:unittest/unittest.dart';
import 'testing.dart';
import 'package:csslib/parser.dart';
import 'package:csslib/visitor.dart';

/** CSS emitter. */
var emitCss = new CssPrinter();

/** Pretty printer for CSS. */
String prettyPrint(StyleSheet ss) =>
    (emitCss..visitTree(ss, pretty: true)).toString();

/** Compact (no pretty printing) for suite testing. */
String compactOuptut(StyleSheet ss) =>
    (emitCss..visitTree(ss)).toString();

void testSimpleTerms() {
  final String input = r'''
@ import url("test.css");
.foo {
  background-color: #191919;
  width: 10PX;
  height: 22mM !important;
  border-width: 20cm;
  margin-width: 33%;
  border-height: 30EM;
  width: .6in;
  length: 1.2in;
  -web-stuff: -10Px;
}''';
  final String generated = r'''
@import "test.css";
.foo {
  background-color: #191919;
  width: 10px;
  height: 22mm !important;
  border-width: 20cm;
  margin-width: 33%;
  border-height: 30em;
  width: .6in;
  length: 1.2in;
  -web-stuff: -10px;
}''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  expect(cssErrors.isEmpty, true, reason: cssErrors.toString());

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

/**
 * Declarations with comments, references with single-quotes, double-quotes,
 * no quotes.  Hex values with # and letters, and functions (rgba, url, etc.)
 */
void testDeclarations() {
  final String input = r'''
.more {
  color: red;
  color: #aabbcc;  /* test -- 3 */
  color: blue;
  background-image: url(http://test.jpeg);
  background-image: url("http://double_quote.html");
  background-image: url('http://single_quote.html');
  color: rgba(10,20,255);  <!-- test CDO/CDC  -->
  color: #123aef;   /* hex # part integer and part identifier */
}''';
  final String generated = r'''
.more {
  color: #ff0000;
  color: #aabbcc;
  color: #0ff;
  background-image: url("http://test.jpeg");
  background-image: url("http://double_quote.html");
  background-image: url("http://single_quote.html");
  color: rgba(10, 20, 255);
  color: #123aef;
}''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

void testIdentifiers() {
  final String input = r'''
#da {
  height: 100px;
}
#foo {
  width: 10px;
  color: #ff00cc;
}
''';
  final String generated = r'''
#da {
  height: 100px;
}
#foo {
  width: 10px;
  color: #ff00cc;
}''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

void testComposites() {
  final String input = r'''
.xyzzy {
  border: 10px 80px 90px 100px;
  width: 99%;
}
@-webkit-keyframes pulsate {
  0% {
    -webkit-transform: translate3d(0, 0, 0) scale(1.0);
  }
}''';
  final String generated = r'''
.xyzzy {
  border: 10px 80px 90px 100px;
  width: 99%;
}
@-webkit-keyframes pulsate {
  0% {
  -webkit-transform: translate3d(0, 0, 0) scale(1.0);
  }
}''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  if (!cssErrors.isEmpty) {
    print(cssErrors.toString());
  }
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

void testUnits() {
  final String input = r'''
#id-1 {
  transition: color 0.4s;
  animation-duration: 500ms;
  top: 1em;
  left: 200ex;
  right: 300px;
  bottom: 400cm;
  border-width: 2.5mm;
  margin-top: .5in;
  margin-left: 5pc;
  margin-right: 5ex;
  margin-bottom: 5ch;
  font-size: 10pt;
  padding-top: 22rem;
  padding-left: 33vw;
  padding-right: 34vh;
  padding-bottom: 3vmin;
  transform: rotate(20deg);
  voice-pitch: 10hz;
}
#id-2 {
  left: 2fr;
  font-size: 10vmax;
  transform: rotatex(20rad);
  voice-pitch: 10khz;
  -web-kit-resolution: 2dpi;    /* Bogus property name testing dpi unit. */
}
#id-3 {
  -web-kit-resolution: 3dpcm;   /* Bogus property name testing dpi unit. */
  transform: rotatey(20grad);
}
#id-4 {
  -web-kit-resolution: 4dppx;   /* Bogus property name testing dpi unit. */
  transform: rotatez(20turn);
}
''';

  final String generated = r'''
#id-1 {
  transition: color 0.4s;
  animation-duration: 500ms;
  top: 1em;
  left: 200ex;
  right: 300px;
  bottom: 400cm;
  border-width: 2.5mm;
  margin-top: .5in;
  margin-left: 5pc;
  margin-right: 5ex;
  margin-bottom: 5ch;
  font-size: 10pt;
  padding-top: 22rem;
  padding-left: 33vw;
  padding-right: 34vh;
  padding-bottom: 3vmin;
  transform: rotate(20deg);
  voice-pitch: 10hz;
}
#id-2 {
  left: 2fr;
  font-size: 10vmax;
  transform: rotatex(20rad);
  voice-pitch: 10khz;
  -web-kit-resolution: 2dpi;
}
#id-3 {
  -web-kit-resolution: 3dpcm;
  transform: rotatey(20grad);
}
#id-4 {
  -web-kit-resolution: 4dppx;
  transform: rotatez(20turn);
}''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors,
      opts: ['--no-colors', 'memory']);
  if (!cssErrors.isEmpty) {
    print(cssErrors.toString());
  }
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

void testUnicode() {
  final String input = r'''
.toggle:after {
  content: '✔';
  line-height: 43px;
  font-size: 20px;
  color: #d9d9d9;
  text-shadow: 0 -1px 0 #bfbfbf;
}
''';

  final String generated = r'''
.toggle:after {
  content: "✔";
  line-height: 43px;
  font-size: 20px;
  color: #d9d9d9;
  text-shadow: 0 -1px 0 #bfbfbf;
}''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  if (!cssErrors.isEmpty) {
    print(cssErrors.toString());
  }
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

void testNewerCss() {
  final String input = r'''
@media screen,print {
  .foobar_screen {
    width: 10px;
  }
}
@page {
  height: 22px;
  size: 3in 3in;
}
@page : left {
  width: 10px;
}
@page bar : left { @top-left { margin: 8px; } }''';

  final String generated = r'''
@media screen,print {
.foobar_screen {
  width: 10px;
}
}
@page {
  height: 22px;
  size: 3in 3in;
}
@page:left {
  width: 10px;
}
@page bar:left {
@top-left {
  margin: 8px;
}
}''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  if (!cssErrors.isEmpty) {
    print(cssErrors.toString());
  }
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

void testCssFile() {
  final String input = r'''
@import 'simple.css'
@import "test.css" print
@import url(test.css) screen, print

div[href^='test'] {
  height: 10px;
}

@-webkit-keyframes pulsate {
  from {
    -webkit-transform: translate3d(0, 0, 0) scale(1.0);
  }
  10% {
    -webkit-transform: translate3d(0, 0, 0) scale(1.0);
  }
  30% {
    -webkit-transform: translate3d(0, 2, 0) scale(1.0);
  }
}

.foobar {
    grid-columns: 10px ("content" 1fr 10px)[4];
}
''';

  final String generated =
      '@import simple.css; '
      '@import test.css print; '
      '@import test.css screen,print;\n'
      'div[href^="test"] {\n'
      '  height: 10px;\n'
      '}\n'
      '@-webkit-keyframes pulsate {\n'
      '  from {\n'
      '  -webkit-transform: translate3d(0, 0, 0) scale(1.0);\n'
      '  }\n'
      '  10% {\n'
      '  -webkit-transform: translate3d(0, 0, 0) scale(1.0);\n'
      '  }\n'
      '  30% {\n'
      '  -webkit-transform: translate3d(0, 2, 0) scale(1.0);\n'
      '  }\n'
      '}\n'
      '.foobar {\n'
      '  grid-columns: 10px ("content" 1fr 10px) [4];\n'
      '}';
  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  if (!cssErrors.isEmpty) {
    print(cssErrors.toString());
  }
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(prettyPrint(stylesheet), generated);
}

void testCompactEmitter() {
  // Check !import compactly emitted.
  final String input = r'''
div {
  color: green !important;
}
''';
  final String generated = "div { color: green!important; }";
  var cssErrors = [];
  var stylesheet = parseCss(input, errors: cssErrors);
  if (!cssErrors.isEmpty) {
    print(cssErrors.toString());
  }
  expect(cssErrors.isEmpty, true);
  expect(stylesheet != null, true);
  expect(compactOuptut(stylesheet), generated);

  // Check namespace directive compactly emitted.
  final String input2 = "@namespace a url(http://www.example.org/a);";
  final String generated2 = "@namespace a url(http://www.example.org/a);";
  var cssErrors2 = [];
  var stylesheet2 = parseCss(input2, errors: cssErrors2);
  expect(cssErrors2.isEmpty, true);
  expect(stylesheet2 != null, true);
  expect(compactOuptut(stylesheet2), generated2);
}

main() {
  test('Simple Terms', testSimpleTerms);
  test('Declarations', testDeclarations);
  test('Identifiers', testIdentifiers);
  test('Composites', testComposites);
  test('Units', testUnits);
  test('Unicode', testUnicode);
  test('Newer CSS', testNewerCss);
  test('CSS file', testCssFile);
  test('Compact Emitter', testCompactEmitter);
}