// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library declaration_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';
import 'testing.dart';
import 'package:csslib/parser.dart';

void testSimpleTerms() {
  final String input = r'''

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
}
''';
  final String generated = r'''

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
}
''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errs: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(stylesheet.toString(), generated);
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
}
''';
  final String generated = r'''

.more {
  color: #ff0000;
  color: #aabbcc;
  color: #0ff;
  background-image: url(http://test.jpeg);
  background-image: url(http://double_quote.html);
  background-image: url(http://single_quote.html);
  color: rgba(10, 20, 255);
  color: #123aef;
}
''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errs: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(stylesheet.toString(), generated);
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
}
''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errs: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(stylesheet.toString(), generated);
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
}
''';
  final String generated = r'''

.xyzzy {
  border: 10px 80px 90px 100px;
  width: 99%;
}
@-webkit-keyframes pulsate {
  0% {
  -webkit-transform: translate3d(0, 0, 0) scale(1.0);
  }
}
''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errs: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(stylesheet.toString(), generated);
}

void testNewerCss() {
  final String input = r'''
@media screen,print {
  .foobar_screen {
    width: 10px;
  }
}
@page : test {
  width: 10px;
}
@page {
  height: 22px;
}
''';

  final String generated = r'''
@media screen,print {

.foobar_screen {
  width: 10px;
}

}
@page : test {
  width: 10px;

}
@page {
  height: 22px;

}
''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errs: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(stylesheet.toString(), generated);
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

  final String generated = r'''
@import url(simple.css)
@import url(test.css) print
@import url(test.css) screen,print

div[href ^= "test"] {
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
  grid-columns: 10px ("content" 1fr 10px) [4];
}
''';

  var cssErrors = [];
  var stylesheet = parseCss(input, errs: cssErrors);
  expect(cssErrors.isEmpty, true);

  expect(stylesheet != null, true);

  expect(stylesheet.toString(), generated);
}

main() {
  useVmConfiguration();
  useMockMessages();

  test('Simple Terms', testSimpleTerms);
  test('Declarations', testDeclarations);
  test('Identifiers', testIdentifiers);
  test('Composites', testComposites);
  test('Newer CSS', testNewerCss);
  test('CSS file', testCssFile);
}