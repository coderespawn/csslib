// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library error_test;

import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';
import 'testing.dart';
import 'package:csslib/parser.dart';

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
SEVERE <#SourceFile MEMORY> @ line 1 (column 23:29)
.foobar { font-weight: bolder; }
                       ^^^^^^ Unknown property value bolder
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

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
SEVERE <#SourceFile MEMORY> @ line 1 (column 23:30)
.foobar { font-weight: lighter; }
                       ^^^^^^^ Unknown property value lighter
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

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
SEVERE <#SourceFile MEMORY> @ line 1 (column 23:30)
.foobar { font-weight: inherit; }
                       ^^^^^^^ Unknown property value inherit
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

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
SEVERE <#SourceFile MEMORY> @ line 1 (column 23:26)
.foobar { line-height: 120%; }
                       ^^^ Unexpected value for line-height
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

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
SEVERE <#SourceFile MEMORY> @ line 1 (column 23:25)
.foobar { line-height: 20cm; }
                       ^^ Unexpected unit for line-height
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

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
SEVERE <#SourceFile MEMORY> @ line 1 (column 23:30)
.foobar { line-height: inherit; }
                       ^^^^^^^ Unknown property value inherit
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

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
SEVERE <#SourceFile MEMORY> @ line 1 (column 0:1)
# foo { color: #ff00ff; }
^ Not a valid ID selector expected #id
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

# foo {
  color: #ff00ff;
}''');

  // Invalid class selector.
  cssErrors = [];
  input = ". foo { color: #ff00ff; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
SEVERE <#SourceFile MEMORY> @ line 1 (column 0:1)
. foo { color: #ff00ff; }
^ Not a valid class selector expected .className
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

. foo {
  color: #ff00ff;
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
SEVERE <#SourceFile MEMORY> @ line 1 (column 17:23)
.foobar { color: #AH787; }
                 ^^^^^^ Bad hex number
''');
  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

.foobar {
  color: #AH787;
}''');

  // Bad color constant.
  cssErrors = [];
  input = ".foobar { color: redder; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
SEVERE <#SourceFile MEMORY> @ line 1 (column 17:23)
.foobar { color: redder; }
                 ^^^^^^ Unknown property value redder
''');

  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

.foobar {
  color: redder;
}''');

  // Bad hex color #<space>ffffff.
  cssErrors = [];
  input = ".foobar { color: # ffffff; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
SEVERE <#SourceFile MEMORY> @ line 1 (column 17:18)
.foobar { color: # ffffff; }
                 ^ Expected hex number
''');

  expect(stylesheet != null, true);
  expect(stylesheet.toString(), r'''

.foobar {
  color: # ffffff;
}''');

  // Bad hex color #<space>123fff.
  cssErrors = [];
  input = ".foobar { color: # 123fff; }";
  stylesheet = parseCss(input, errors: cssErrors);

  expect(cssErrors.isEmpty, false);
  expect(cssErrors[0].toString(), r'''
SEVERE <#SourceFile MEMORY> @ line 1 (column 17:18)
.foobar { color: # 123fff; }
                 ^ Expected hex number
''');

  expect(stylesheet != null, true);

  // Formating is off with an extra space.  However, the entire value is bad
  // and isn't processed anyway.
  expect(stylesheet.toString(), r'''

.foobar {
  color: # 123 fff;
}''');

}

main() {
  useVmConfiguration();
  useMockMessages();

  test('font-weight value errors', testUnsupportedFontWeights);
  test('line-height value errors', testUnsupportedLineHeights);
  test('bad selectors', testBadSelectors);
  test('bad Hex values', testBadHexValues);
}
