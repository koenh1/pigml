define([],function() {
  "use strict";

  function peg$subclass(child, parent) {
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
  }

  function peg$SyntaxError(message, expected, found, location) {
    this.message  = message;
    this.expected = expected;
    this.found    = found;
    this.location = location;
    this.name     = "SyntaxError";

    if (typeof Error.captureStackTrace === "function") {
      Error.captureStackTrace(this, peg$SyntaxError);
    }
  }

  peg$subclass(peg$SyntaxError, Error);

  peg$SyntaxError.buildMessage = function(expected, found) {
    var DESCRIBE_EXPECTATION_FNS = {
          literal: function(expectation) {
            return "\"" + literalEscape(expectation.text) + "\"";
          },

          "class": function(expectation) {
            var escapedParts = "",
                i;

            for (i = 0; i < expectation.parts.length; i++) {
              escapedParts += expectation.parts[i] instanceof Array
                ? classEscape(expectation.parts[i][0]) + "-" + classEscape(expectation.parts[i][1])
                : classEscape(expectation.parts[i]);
            }

            return "[" + (expectation.inverted ? "^" : "") + escapedParts + "]";
          },

          any: function(expectation) {
            return "any character";
          },

          end: function(expectation) {
            return "end of input";
          },

          other: function(expectation) {
            return expectation.description;
          }
        };

    function hex(ch) {
      return ch.charCodeAt(0).toString(16).toUpperCase();
    }

    function literalEscape(s) {
      return s
        .replace(/\\/g, '\\\\')
        .replace(/"/g,  '\\"')
        .replace(/\0/g, '\\0')
        .replace(/\t/g, '\\t')
        .replace(/\n/g, '\\n')
        .replace(/\r/g, '\\r')
        .replace(/[\x00-\x0F]/g,          function(ch) { return '\\x0' + hex(ch); })
        .replace(/[\x10-\x1F\x7F-\x9F]/g, function(ch) { return '\\x'  + hex(ch); });
    }

    function classEscape(s) {
      return s
        .replace(/\\/g, '\\\\')
        .replace(/\]/g, '\\]')
        .replace(/\^/g, '\\^')
        .replace(/-/g,  '\\-')
        .replace(/\0/g, '\\0')
        .replace(/\t/g, '\\t')
        .replace(/\n/g, '\\n')
        .replace(/\r/g, '\\r')
        .replace(/[\x00-\x0F]/g,          function(ch) { return '\\x0' + hex(ch); })
        .replace(/[\x10-\x1F\x7F-\x9F]/g, function(ch) { return '\\x'  + hex(ch); });
    }

    function describeExpectation(expectation) {
      return DESCRIBE_EXPECTATION_FNS[expectation.type](expectation);
    }

    function describeExpected(expected) {
      var descriptions = new Array(expected.length),
          i, j;

      for (i = 0; i < expected.length; i++) {
        descriptions[i] = describeExpectation(expected[i]);
      }

      descriptions.sort();

      if (descriptions.length > 0) {
        for (i = 1, j = 1; i < descriptions.length; i++) {
          if (descriptions[i - 1] !== descriptions[i]) {
            descriptions[j] = descriptions[i];
            j++;
          }
        }
        descriptions.length = j;
      }

      switch (descriptions.length) {
        case 1:
          return descriptions[0];

        case 2:
          return descriptions[0] + " or " + descriptions[1];

        default:
          return descriptions.slice(0, -1).join(", ")
            + ", or "
            + descriptions[descriptions.length - 1];
      }
    }

    function describeFound(found) {
      return found ? "\"" + literalEscape(found) + "\"" : "end of input";
    }

    return "Expected " + describeExpected(expected) + " but " + describeFound(found) + " found.";
  };

  function peg$parse(input, options) {
    options = options !== void 0 ? options : {};

    var peg$FAILED = {},

        peg$startRuleIndices = { Start: 0 },
        peg$startRuleIndex   = 0,

        peg$consts = [
          function(prolog, c) { return true; },
          function(prolog, pi) { return true },
          function(prolog, pi, e) { return true },
          function(prolog, pi, e) { return true; },
          function(content, c) { return true },
          function(content, comments) {
          			return true;
          		},
          /^[\t\x0B\f \xA0\uFEFF]/,
          peg$classExpectation(["\t", "\x0B", "\f", " ", "\xA0", "\uFEFF"], false, false),
          /^[ \xA0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000]/,
          peg$classExpectation([" ", "\xA0", "\u1680", "\u180E", "\u2000", "\u2001", "\u2002", "\u2003", "\u2004", "\u2005", "\u2006", "\u2007", "\u2008", "\u2009", "\u200A", "\u202F", "\u205F", "\u3000"], false, false),
          peg$otherExpectation("white space character"),
          "\n",
          peg$literalExpectation("\n", false),
          "\r\n",
          peg$literalExpectation("\r\n", false),
          "\r",
          peg$literalExpectation("\r", false),
          "\u2028",
          peg$literalExpectation("\u2028", false),
          "\u2029",
          peg$literalExpectation("\u2029", false),
          peg$otherExpectation("string"),
          "\"",
          peg$literalExpectation("\"", false),
          /^[^"\n\r]/,
          peg$classExpectation(["\"", "\n", "\r"], true, false),
          function(string) { return string.join(""); },
          "'",
          peg$literalExpectation("'", false),
          /^[^'\n\r]/,
          peg$classExpectation(["'", "\n", "\r"], true, false),
          function(string) { return '"' + string.join("") + '"'; },
          function(string) { return "'" + string.join("") + "'"; },
          /^[A-Z]/,
          peg$classExpectation([["A", "Z"]], false, false),
          "_",
          peg$literalExpectation("_", false),
          /^[a-z]/,
          peg$classExpectation([["a", "z"]], false, false),
          /^[\xC0-\xD6]/,
          peg$classExpectation([["\xC0", "\xD6"]], false, false),
          /^[\xD8-\xF6]/,
          peg$classExpectation([["\xD8", "\xF6"]], false, false),
          /^[\xF8-\u02FF]/,
          peg$classExpectation([["\xF8", "\u02FF"]], false, false),
          /^[\u0370-\u037D]/,
          peg$classExpectation([["\u0370", "\u037D"]], false, false),
          /^[\u037F-\u1FFF]/,
          peg$classExpectation([["\u037F", "\u1FFF"]], false, false),
          /^[\u200C-\u200D]/,
          peg$classExpectation([["\u200C", "\u200D"]], false, false),
          /^[\u2070-\u218F]/,
          peg$classExpectation([["\u2070", "\u218F"]], false, false),
          /^[\u2C00-\u2FEF]/,
          peg$classExpectation([["\u2C00", "\u2FEF"]], false, false),
          /^[\u3001-\uD7FF]/,
          peg$classExpectation([["\u3001", "\uD7FF"]], false, false),
          /^[\uF900-\uFDCF]/,
          peg$classExpectation([["\uF900", "\uFDCF"]], false, false),
          /^[\uFDF0-\uFFFD]/,
          peg$classExpectation([["\uFDF0", "\uFFFD"]], false, false),
          "-",
          peg$literalExpectation("-", false),
          ".",
          peg$literalExpectation(".", false),
          /^[0-9]/,
          peg$classExpectation([["0", "9"]], false, false),
          /^[\xB7]/,
          peg$classExpectation(["\xB7"], false, false),
          /^[\u0300-\u036F]/,
          peg$classExpectation([["\u0300", "\u036F"]], false, false),
          /^[\u203F-\u2040]/,
          peg$classExpectation([["\u203F", "\u2040"]], false, false),
          function(first, last) { return first + last.join("") },
          peg$otherExpectation("qualified identifier1"),
          ":",
          peg$literalExpectation(":", false),
          function(prefix, id) { startElement(prefix + ":" + id);return prefix + ":" + id },
          function(id) { startElement(id);return id },
          peg$otherExpectation("qualified identifier2"),
          function(prefix, id) { return prefix + ":" + id },
          function(id) { return id },
          peg$otherExpectation("qualified identifier3"),
          function(prefix, id) { attribute(prefix + ":" + id);return prefix + ":" + id },
          function(id) { attribute(id);return id },
          "<",
          peg$literalExpectation("<", false),
          ">",
          peg$literalExpectation(">", false),
          function(qid, attributes) {
          			return true;
          		},
          "</",
          peg$literalExpectation("</", false),
          function(qid) {
          			endElement()
          			return true;
          		},
          "/>",
          peg$literalExpectation("/>", false),
          function(qid, attributes) {
          			endElement()
          			return true;
          		},
          function(startTag) {
          			return true
          		},
          function(startTag, content) { return true },
          function(startTag, contents) {
          			return true
          		},
          function(startTag, contents, endTag) {
          			return true;
          		},
          function(tag) {
          			return true;
          		},
          /^[^<\n\r]/,
          peg$classExpectation(["<", "\n", "\r"], true, false),
          function(chars) { startText();return true; },
          "=",
          peg$literalExpectation("=", false),
          function(qid, value) { return true },
          function(qid, value) {
          			return true;
          		},
          peg$otherExpectation("attribute value"),
          function() {
          		attribute(null)
          		return true
          	},
          "<?",
          peg$literalExpectation("<?", false),
          function(id, content) {
          			return true;
          		},
          "?>",
          peg$literalExpectation("?>", false),
          function(tail) { return true },
          peg$anyExpectation(),
          function(head, tail) { return true },
          "<?xml",
          peg$literalExpectation("<?xml", true),
          function(version, encoding) { return true },
          function(version, encoding, standalone) { return true },
          function(version, encoding, standalone) {
          			return true;
          		},
          "version",
          peg$literalExpectation("version", true),
          function(version) {
          			return true;
          		},
          "encoding",
          peg$literalExpectation("encoding", true),
          function(encoding) { return true; },
          "standalone",
          peg$literalExpectation("standalone", true),
          peg$otherExpectation("CDATA"),
          "<![CDATA[",
          peg$literalExpectation("<![CDATA[", false),
          function(content) { return true; },
          "]]>",
          peg$literalExpectation("]]>", false),
          peg$otherExpectation("comment"),
          "<!--",
          peg$literalExpectation("<!--", false),
          "-->",
          peg$literalExpectation("-->", false),
          function(head, tail) { return true; }
        ],

        peg$bytecode = [
          peg$decode("%%;8.\" &\"/\xD2#$%;$/2#;>/)$8\": \"\"$ )(\"'#&'#.< &%;$/2#;6/)$8\":!\"\"$ )(\"'#&'#0[*%;$/2#;>/)$8\": \"\"$ )(\"'#&'#.< &%;$/2#;6/)$8\":!\"\"$ )(\"'#&'#&/R$%;$/3#;1/*$8\":\"\"#$# )(\"'#&'#.\" &\"/*$8#:###\"! )(#'#(\"'#&'#.\" &\"/t#$%;$/2#;>/)$8\":$\"\"$ )(\"'#&'#0<*%;$/2#;>/)$8\":$\"\"$ )(\"'#&'#&/2$;$/)$8#:%#\"\"!)(#'#(\"'#&'#"),
          peg$decode(";\".# &;%"),
          peg$decode("4&\"\"5!7'.) &4(\"\"5!7)"),
          peg$decode("<$;!/&#0#*;!&&&#=.\" 7*"),
          peg$decode("<$;!0#*;!&=.\" 7*"),
          peg$decode("2+\"\"6+7,.M &2-\"\"6-7..A &2/\"\"6/70.5 &21\"\"6172.) &23\"\"6374"),
          peg$decode("<%26\"\"6677/S#$48\"\"5!790)*48\"\"5!79&/7$26\"\"6677/($8#::#!!)(#'#(\"'#&'#.c &%2;\"\"6;7</S#$4=\"\"5!7>0)*4=\"\"5!7>&/7$2;\"\"6;7</($8#::#!!)(#'#(\"'#&'#=.\" 75"),
          peg$decode("<%26\"\"6677/S#$48\"\"5!790)*48\"\"5!79&/7$26\"\"6677/($8#:?#!!)(#'#(\"'#&'#.c &%2;\"\"6;7</S#$4=\"\"5!7>0)*4=\"\"5!7>&/7$2;\"\"6;7</($8#:@#!!)(#'#(\"'#&'#=.\" 75"),
          peg$decode("4A\"\"5!7B.\xB9 &2C\"\"6C7D.\xAD &4E\"\"5!7F.\xA1 &4G\"\"5!7H.\x95 &4I\"\"5!7J.\x89 &4K\"\"5!7L.} &4M\"\"5!7N.q &4O\"\"5!7P.e &4Q\"\"5!7R.Y &4S\"\"5!7T.M &4U\"\"5!7V.A &4W\"\"5!7X.5 &4Y\"\"5!7Z.) &4[\"\"5!7\\"),
          peg$decode(";(.e &2]\"\"6]7^.Y &2_\"\"6_7`.M &4a\"\"5!7b.A &4c\"\"5!7d.5 &4e\"\"5!7f.) &4g\"\"5!7h"),
          peg$decode("%;(/9#$;)0#*;)&/)$8\":i\"\"! )(\"'#&'#"),
          peg$decode("<%;*/A#2k\"\"6k7l/2$;*/)$8#:m#\"\" )(#'#(\"'#&'#./ &%;*/' 8!:n!! )=.\" 7j"),
          peg$decode("<%;*/A#2k\"\"6k7l/2$;*/)$8#:p#\"\" )(#'#(\"'#&'#./ &%;*/' 8!:q!! )=.\" 7o"),
          peg$decode("<%;*/A#2k\"\"6k7l/2$;*/)$8#:s#\"\" )(#'#(\"'#&'#./ &%;*/' 8!:t!! )=.\" 7r"),
          peg$decode("%2u\"\"6u7v/Z#;+/Q$$;40#*;4&/A$;$/8$2w\"\"6w7x/)$8%:y%\"#\")(%'#($'#(#'#(\"'#&'#"),
          peg$decode("%2z\"\"6z7{/I#;,/@$;$/7$2w\"\"6w7x/($8$:|$!\")($'#(#'#(\"'#&'#"),
          peg$decode("%2u\"\"6u7v/Z#;,/Q$$;40#*;4&/A$;$/8$2}\"\"6}7~/)$8%:\x7F%\"#\")(%'#($'#(#'#(\"'#&'#"),
          peg$decode("%;$/\xB9#;./\xB0$9:\x80 ! -\"\"&!&#/\x9C$;$/\x93$$%;2/2#;$/)$8\":\x81\"\"&!)(\"'#&'#0<*%;2/2#;$/)$8\":\x81\"\"&!)(\"'#&'#&/Q$9:\x82 \"# -\"\"&!&#/<$;$/3$;//*$8(:\x83(#&# )(('#(''#(&'#(%'#($'#(#'#(\"'#&'#.; &%;$/1#;0/($8\":\x84\"! )(\"'#&'#"),
          peg$decode(";<./ &;>.) &;1.# &;3"),
          peg$decode("%$4\x85\"\"5!7\x86/,#0)*4\x85\"\"5!7\x86&&&#/' 8!:\x87!! )"),
          peg$decode("%;$/q#;-/h$%;$/J#2\x88\"\"6\x887\x89/;$;$/2$;5/)$8$:\x8A$\"% )($'#(#'#(\"'#&'#.\" &\"/)$8#:\x8B#\"! )(#'#(\"'#&'#"),
          peg$decode("<%;'/& 8!:\x8D! )=.\" 7\x8C"),
          peg$decode("%2\x8E\"\"6\x8E7\x8F/D#;*/;$;#/2$;7/)$8$:\x90$\"\" )($'#(#'#(\"'#&'#"),
          peg$decode("2\x91\"\"6\x917\x92._ &%;#/1#;7/($8\":\x93\"! )(\"'#&'#.A &%1\"\"5!7\x94/2#;7/)$8\":\x95\"\"! )(\"'#&'#"),
          peg$decode("%3\x96\"\"5%7\x97/\xA3#;$/\x9A$;9/\x91$;$/\x88$%;:/2#;$/)$8\":\x98\"\"$!)(\"'#&'#.\" &\"/a$%;;/3#;$/*$8\":\x99\"#%#!)(\"'#&'#.\" &\"/9$2\x91\"\"6\x917\x92/*$8':\x9A'#$\"!)(''#(&'#(%'#($'#(#'#(\"'#&'#"),
          peg$decode("%3\x9B\"\"5'7\x9C/R#;$/I$2\x88\"\"6\x887\x89/:$;$/1$;&/($8%:\x9D%! )(%'#($'#(#'#(\"'#&'#"),
          peg$decode("%3\x9E\"\"5(7\x9F/R#;$/I$2\x88\"\"6\x887\x89/:$;$/1$;&/($8%:\xA0%! )(%'#($'#(#'#(\"'#&'#"),
          peg$decode("%3\xA1\"\"5*7\xA2/M#;$/D$2\x88\"\"6\x887\x89/5$;$/,$;&/#$+%)(%'#($'#(#'#(\"'#&'#"),
          peg$decode("<%2\xA4\"\"6\xA47\xA5/1#;=/($8\":\xA6\"! )(\"'#&'#=.\" 7\xA3"),
          peg$decode("2\xA7\"\"6\xA77\xA8.A &%1\"\"5!7\x94/2#;=/)$8\":\x95\"\"! )(\"'#&'#"),
          peg$decode("<%2\xAA\"\"6\xAA7\xAB/1#;?/($8\":\xA6\"! )(\"'#&'#=.\" 7\xA9"),
          peg$decode("2\xAC\"\"6\xAC7\xAD.A &%1\"\"5!7\x94/2#;?/)$8\":\xAE\"\"! )(\"'#&'#")
        ],

        peg$currPos          = 0,
        peg$savedPos         = 0,
        peg$posDetailsCache  = [{ line: 1, column: 1 }],
        peg$maxFailPos       = 0,
        peg$maxFailExpected  = [],
        peg$silentFails      = 0,

        peg$result;

    if ("startRule" in options) {
      if (!(options.startRule in peg$startRuleIndices)) {
        throw new Error("Can't start parsing from rule \"" + options.startRule + "\".");
      }

      peg$startRuleIndex = peg$startRuleIndices[options.startRule];
    }

    function text() {
      return input.substring(peg$savedPos, peg$currPos);
    }

    function location() {
      return peg$computeLocation(peg$savedPos, peg$currPos);
    }

    function expected(description, location) {
      location = location !== void 0 ? location : peg$computeLocation(peg$savedPos, peg$currPos)

      throw peg$buildStructuredError(
        [peg$otherExpectation(description)],
        input.substring(peg$savedPos, peg$currPos),
        location
      );
    }

    function error(message, location) {
      location = location !== void 0 ? location : peg$computeLocation(peg$savedPos, peg$currPos)

      throw peg$buildSimpleError(message, location);
    }

    function peg$literalExpectation(text, ignoreCase) {
      return { type: "literal", text: text, ignoreCase: ignoreCase };
    }

    function peg$classExpectation(parts, inverted, ignoreCase) {
      return { type: "class", parts: parts, inverted: inverted, ignoreCase: ignoreCase };
    }

    function peg$anyExpectation() {
      return { type: "any" };
    }

    function peg$endExpectation() {
      return { type: "end" };
    }

    function peg$otherExpectation(description) {
      return { type: "other", description: description };
    }

    function peg$computePosDetails(pos) {
      var details = peg$posDetailsCache[pos], p;

      if (details) {
        return details;
      } else {
        p = pos - 1;
        while (!peg$posDetailsCache[p]) {
          p--;
        }

        details = peg$posDetailsCache[p];
        details = {
          line:   details.line,
          column: details.column
        };

        while (p < pos) {
          if (input.charCodeAt(p) === 10) {
            details.line++;
            details.column = 1;
          } else {
            details.column++;
          }

          p++;
        }

        peg$posDetailsCache[pos] = details;
        return details;
      }
    }

    function peg$computeLocation(startPos, endPos) {
      var startPosDetails = peg$computePosDetails(startPos),
          endPosDetails   = peg$computePosDetails(endPos);

      return {
        start: {
          offset: startPos,
          line:   startPosDetails.line,
          column: startPosDetails.column
        },
        end: {
          offset: endPos,
          line:   endPosDetails.line,
          column: endPosDetails.column
        }
      };
    }

    function peg$fail(expected) {
      if (peg$currPos < peg$maxFailPos) { return; }

      if (peg$currPos > peg$maxFailPos) {
        peg$maxFailPos = peg$currPos;
        peg$maxFailExpected = [];
      }

      peg$maxFailExpected.push(expected);
    }

    function peg$buildSimpleError(message, location) {
      return new peg$SyntaxError(message, null, null, location);
    }

    function peg$buildStructuredError(expected, found, location) {
      return new peg$SyntaxError(
        peg$SyntaxError.buildMessage(expected, found),
        expected,
        found,
        location
      );
    }

    function peg$decode(s) {
      var bc = new Array(s.length), i;

      for (i = 0; i < s.length; i++) {
        bc[i] = s.charCodeAt(i) - 32;
      }

      return bc;
    }

    function peg$parseRule(index) {
      var bc    = peg$bytecode[index],
          ip    = 0,
          ips   = [],
          end   = bc.length,
          ends  = [],
          stack = [],
          params, i;

      while (true) {
        while (ip < end) {
          switch (bc[ip]) {
            case 0:
              stack.push(peg$consts[bc[ip + 1]]);
              ip += 2;
              break;

            case 1:
              stack.push(void 0);
              ip++;
              break;

            case 2:
              stack.push(null);
              ip++;
              break;

            case 3:
              stack.push(peg$FAILED);
              ip++;
              break;

            case 4:
              stack.push([]);
              ip++;
              break;

            case 5:
              stack.push(peg$currPos);
              ip++;
              break;

            case 6:
              stack.pop();
              ip++;
              break;

            case 7:
              peg$currPos = stack.pop();
              ip++;
              break;

            case 8:
              stack.length -= bc[ip + 1];
              ip += 2;
              break;

            case 9:
              stack.splice(-2, 1);
              ip++;
              break;

            case 10:
              stack[stack.length - 2].push(stack.pop());
              ip++;
              break;

            case 11:
              stack.push(stack.splice(stack.length - bc[ip + 1], bc[ip + 1]));
              ip += 2;
              break;

            case 12:
              stack.push(input.substring(stack.pop(), peg$currPos));
              ip++;
              break;

            case 13:
              ends.push(end);
              ips.push(ip + 3 + bc[ip + 1] + bc[ip + 2]);

              if (stack[stack.length - 1]) {
                end = ip + 3 + bc[ip + 1];
                ip += 3;
              } else {
                end = ip + 3 + bc[ip + 1] + bc[ip + 2];
                ip += 3 + bc[ip + 1];
              }

              break;

            case 14:
              ends.push(end);
              ips.push(ip + 3 + bc[ip + 1] + bc[ip + 2]);

              if (stack[stack.length - 1] === peg$FAILED) {
                end = ip + 3 + bc[ip + 1];
                ip += 3;
              } else {
                end = ip + 3 + bc[ip + 1] + bc[ip + 2];
                ip += 3 + bc[ip + 1];
              }

              break;

            case 15:
              ends.push(end);
              ips.push(ip + 3 + bc[ip + 1] + bc[ip + 2]);

              if (stack[stack.length - 1] !== peg$FAILED) {
                end = ip + 3 + bc[ip + 1];
                ip += 3;
              } else {
                end = ip + 3 + bc[ip + 1] + bc[ip + 2];
                ip += 3 + bc[ip + 1];
              }

              break;

            case 16:
              if (stack[stack.length - 1] !== peg$FAILED) {
                ends.push(end);
                ips.push(ip);

                end = ip + 2 + bc[ip + 1];
                ip += 2;
              } else {
                ip += 2 + bc[ip + 1];
              }

              break;

            case 17:
              ends.push(end);
              ips.push(ip + 3 + bc[ip + 1] + bc[ip + 2]);

              if (input.length > peg$currPos) {
                end = ip + 3 + bc[ip + 1];
                ip += 3;
              } else {
                end = ip + 3 + bc[ip + 1] + bc[ip + 2];
                ip += 3 + bc[ip + 1];
              }

              break;

            case 18:
              ends.push(end);
              ips.push(ip + 4 + bc[ip + 2] + bc[ip + 3]);

              if (input.substr(peg$currPos, peg$consts[bc[ip + 1]].length) === peg$consts[bc[ip + 1]]) {
                end = ip + 4 + bc[ip + 2];
                ip += 4;
              } else {
                end = ip + 4 + bc[ip + 2] + bc[ip + 3];
                ip += 4 + bc[ip + 2];
              }

              break;

            case 19:
              ends.push(end);
              ips.push(ip + 4 + bc[ip + 2] + bc[ip + 3]);

              if (input.substr(peg$currPos, peg$consts[bc[ip + 1]].length).toLowerCase() === peg$consts[bc[ip + 1]]) {
                end = ip + 4 + bc[ip + 2];
                ip += 4;
              } else {
                end = ip + 4 + bc[ip + 2] + bc[ip + 3];
                ip += 4 + bc[ip + 2];
              }

              break;

            case 20:
              ends.push(end);
              ips.push(ip + 4 + bc[ip + 2] + bc[ip + 3]);

              if (peg$consts[bc[ip + 1]].test(input.charAt(peg$currPos))) {
                end = ip + 4 + bc[ip + 2];
                ip += 4;
              } else {
                end = ip + 4 + bc[ip + 2] + bc[ip + 3];
                ip += 4 + bc[ip + 2];
              }

              break;

            case 21:
              stack.push(input.substr(peg$currPos, bc[ip + 1]));
              peg$currPos += bc[ip + 1];
              ip += 2;
              break;

            case 22:
              stack.push(peg$consts[bc[ip + 1]]);
              peg$currPos += peg$consts[bc[ip + 1]].length;
              ip += 2;
              break;

            case 23:
              stack.push(peg$FAILED);
              if (peg$silentFails === 0) {
                peg$fail(peg$consts[bc[ip + 1]]);
              }
              ip += 2;
              break;

            case 24:
              peg$savedPos = stack[stack.length - 1 - bc[ip + 1]];
              ip += 2;
              break;

            case 25:
              peg$savedPos = peg$currPos;
              ip++;
              break;

            case 26:
              params = bc.slice(ip + 4, ip + 4 + bc[ip + 3]);
              for (i = 0; i < bc[ip + 3]; i++) {
                params[i] = stack[stack.length - 1 - params[i]];
              }

              stack.splice(
                stack.length - bc[ip + 2],
                bc[ip + 2],
                peg$consts[bc[ip + 1]].apply(null, params)
              );

              ip += 4 + bc[ip + 3];
              break;

            case 27:
              stack.push(peg$parseRule(bc[ip + 1]));
              ip += 2;
              break;

            case 28:
              peg$silentFails++;
              ip++;
              break;

            case 29:
              peg$silentFails--;
              ip++;
              break;

            default:
              throw new Error("Invalid opcode: " + bc[ip] + ".");
          }
        }

        if (ends.length > 0) {
          end = ends.pop();
          ip = ips.pop();
        } else {
          break;
        }
      }

      return stack[0];
    }


    	var elements = [];
    	var counts=[{}];
    	var attributen=null;
    	var textnodes=[];

    	var xpath=function() {
        	var x=elements.map(function(e,i){return e+(i?('['+counts[i][e]+']'):'')}).join('/')
            if (attributen!=null) x+='/@'+attributen
            else if (textnodes[textnodes.length-1]) x+='/text()['+textnodes[textnodes.length-1]+']'
            return '/'+x
        }
        var startText=function() {
    		attributen=null;
        	textnodes.push(textnodes.pop()+1)
        }
    	var startElement = function(e) {
    		var c=counts[counts.length-1];
    		if (c[e]) {c[e]++} else c[e]=1;
    		elements.push(e);
    		attributen=null;
    		textnodes.push(0);
    		counts.push({})
    	}
    	var attribute=function(n,v) {
    		attributen=n;
    	}

    	var endElement = function() {
    		attributen=null;
    		elements.pop();
    		counts.pop();
    		textnodes.pop();
    	}


   peg$result = peg$parseRule(peg$startRuleIndex);
    return xpath();

  }

  return {
    SyntaxError: peg$SyntaxError,
    parse:       peg$parse
  };
});
