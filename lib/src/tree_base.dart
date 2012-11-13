// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of parser;

/**
 * The base type for all nodes in a CSS abstract syntax tree.
 */
abstract class Node {
  /** The source code this [Node] represents. */
  SourceSpan span;

  Node(this.span) {}

  /** Classic double-dispatch visitor for implementing passes. */
  visit(TreeVisitor visitor);

  /** A multiline string showing the node and its children. */
  String toDebugString() {
    var to = new TreeOutput();
    var tp = new TreePrinter(to);
    this.visit(tp);
    return to.buf.toString();
  }
}

/** The base type for expressions. */
abstract class Expression extends Node {
  Expression(SourceSpan span): super(span);
}

/** The base type for a reference to a [Type]. */
abstract class TypeReference extends Node {
  TypeReference(SourceSpan span): super(span);
}

/** Simple class to provide a textual dump of trees for debugging. */
class TreeOutput {
  int depth;
  StringBuffer buf;

  var printer;

  static void dump(Node node) {
    var o = new TreeOutput();
    node.visit(new TreePrinter(o));
    print(o.buf);
  }

  TreeOutput(): this.depth = 0, this.buf = new StringBuffer() {
  }

  void write(String s) {
    for (int i=0; i < depth; i++) {
      buf.add(' ');
    }
    buf.add(s);
  }

  void writeln(String s) {
    write(s);
    buf.add('\n');
  }

  void heading(String name, span) {
    write(name);
    buf.add('  (${span.locationText})');
    buf.add('\n');
  }

  String toValue(value) {
    if (value == null) return 'null';
    else if (value is Identifier) return value.name;
    else return value.toString();
  }

  void writeNode(String label, Node node) {
    write('${label}: ');
    depth += 1;
    if (node != null) node.visit(printer);
    else writeln('null');
    depth -= 1;
  }

  void writeValue(String label, value) {
    var v = toValue(value);
    writeln('${label}: ${v}');
  }

  void writeList(String label, List list) {
    write('${label}: ');
    if (list == null) {
      buf.add('null');
      buf.add('\n');
    } else {
      for (var item in list) {
        buf.add(item.toString());
        buf.add(', ');
      }
      buf.add('\n');
    }
  }

  void writeNodeList(String label, List list) {
    writeln('${label} [');
    if (list != null) {
      depth += 1;
      for (var node in list) {
        if (node != null) {
          node.visit(printer);
        } else {
          writeln('null');
        }
      }
      depth -= 1;
      writeln(']');
    }
  }
}
