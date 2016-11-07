//* return an xpath for a prefix of an xml file */

{
       var elements = [];
          var counts=[[],[]];
          var attributen=null;
          var textnodes=[];
          var ns=[];
          var pos=0
          var inatts=false;
          var elementContent=function() {
            inatts=false;
          }
          function count(i,e) {
            return counts[i].reduce(function(a,b){return b==e?a+1:a},0)
          }
          function xpath() {
              var x=elements.map(function(e,i){return e+(i?('['+count(i+1,e)+']'):'')}).join('/')
                if (attributen!=null) x+='/@'+attributen
                else if (textnodes[textnodes.length-1]) x+='/text()['+textnodes[textnodes.length-1]+']'
                else if (inatts) x+='/@'
                return '/'+x
           }
           function namespaces() {
            return ns.reduce(function(a,b){Object.keys(b).reduce(function(aa,bb){aa[bb]=b[bb];return aa;},a);return a;},{})
           }
           function getcounts(l) {
            var r=[];
            if (l.length==0) return r;
            var last=l[0];
            var c=1;
            for (var i=1;i<l.length;i++) {
              if (last!=l[i]) {var cc={};cc[last]=c;r.push(cc);c=1;} else c++;
              last=l[i];
            }
            var cc={};cc[last]=c;r.push(cc);
            return r;
          }
           function info() {
            return {xpath:xpath(),ns:namespaces(),context:getcounts(counts.reduce(function(a,b){return b.length?b:a},[]))}
           }
           function startText() {
            attributen=null;
            inatts=false;
              textnodes.push(textnodes.pop()+1)
            }
          function startElement(e) {
            inatts=true;
            counts[counts.length-1].push(e);
            elements.push(e);
            attributen=null;
            textnodes.push(0);
            counts.push([])
            ns.push({})
          }
          function attributeValue(v) {
            if (pos<=peg$currPos&&attributen!=null) {
              var nst=ns[ns.length-1];
              if (attributen.startsWith('xmlns:')) nst[attributen.substring(6)]=v;
              else if (attributen=='xmlns') nst['']=v;
            attributen=null;
              pos=peg$currPos
            }
            }
          function attribute(n) {
            if (pos<=peg$currPos) {
              attributen=n;
              pos=peg$currPos
            }
          }

          function endElement() {
            if (pos<=peg$currPos) {
              attributen=null;
              inatts=false;
              elements.pop();
              counts.pop();
              textnodes.pop();
              ns.pop();
              pos=peg$currPos
            }
          }

}

////////////////////////////////////////////////////
//

Start
	= content:(prolog:Prolog? pi:( _ c:Comment { return true; } / _ pi:PI { return true } )* e:( _ e:Element { return true } )? { return true; })? comments:( _ c:Comment  { return true })* _
		{
			return true;
		}

////////////////////////////////////////////////////
//
// ## This section defines white spaces
//

// The white spaces must be parsed explicite. The White spaces include
// the space and tab character as well as new line CR and LF characters.
// The white spaces mainly separate keywords, identifiers and numbers.
// The white spaces subsumes also new line character and followup empty
// lines.
//
WSEOL
	= WS
	/ EOL

WS
	= [\t\v\f \u00A0\uFEFF]
  / [\u0020\u00A0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000]

__ "white space character"
	= WSEOL+

_ "white space character"
	= WSEOL*

EOL
	= "\n"
  / "\r\n"
  / "\r"
  / "\u2028" // line separator
  / "\u2029" // paragraph separator

// A string must be pairwise surrounded by quote characters. A string
// could contain any characters except the surrounding character. A string
// must be written within a line.
//
STRING "string"
	= '"' string:[^"\n\r]* '"' { return string.join(""); }
	/ "'" string:[^'\n\r]* "'" { return string.join(""); }

QUOTEDSTRING "string"
	= '"' string:[^"\n\r]* '"' { return '"' + string.join("") + '"'; }
	/ "'" string:[^'\n\r]* "'" { return "'" + string.join("") + "'"; }

////////////////////////////////////////////////////
//
// ## This section defines the valid identifier names
//
NameStartChar
	= [A-Z] / "_" / [a-z] / [\u00C0-\u00D6] / [\u00D8-\u00F6]
	/ [\u00F8-\u02FF] / [\u0370-\u037D] / [\u037F-\u1FFF] / [\u200C-\u200D]
	/ [\u2070-\u218F] / [\u2C00-\u2FEF] / [\u3001-\uD7FF] / [\uF900-\uFDCF] / [\uFDF0-\uFFFD]

NameChar
	= NameStartChar / "-" / "." / [0-9] / [\u00B7] / [\u0300-\u036F] / [\u203F-\u2040]

Identifier
	= first:NameStartChar last:NameChar*
		{ return first + last.join("") }

QualifiedIdentifier1 "qualified identifier1"
	= prefix:Identifier ':' id:Identifier { startElement(prefix + ":" + id);return prefix + ":" + id }
	/ id:Identifier { startElement(id);return id }

QualifiedIdentifier2 "qualified identifier2"
	= prefix:Identifier ':' id:Identifier { return prefix + ":" + id }
	/ id:Identifier { return id }

QualifiedIdentifier3 "qualified identifier3"
	= prefix:Identifier ':' id:Identifier { attribute(prefix + ":" + id);return prefix + ":" + id }
	/ id:Identifier { attribute(id);return id }

////////////////////////////////////////////////////
//
// ## This section defines the valid tags
//
StartTag
	= '<' qid:QualifiedIdentifier1 attributes:Attribute* _ '>'
		{
			elementContent()
			return true;
		}

EndTag
	= '</' qid:QualifiedIdentifier2 _ '>'
		{
			endElement()
			return true;
		}

ClosedTag
	= '<' qid:QualifiedIdentifier2 attributes:Attribute* _ '/>'
		{
			elementContent()
			endElement()
			return true;
		}

////////////////////////////////////////////////////
//
// ## This section defines an element
//
Element
	= _ startTag:StartTag
		& {
			return true
		}
		_ contents:( content:ElementContent _ { return true })*
		& {
			return true
		}
		_ endTag:EndTag
		{
			return true;
		}
	/ _ tag:ClosedTag
		{
			return true;
		}

ElementContent
	= Cdata
	/ Comment
	/ Element
	/ ElementValue

ElementValue
	= chars:([^<\n\r]+) { startText();return true; }

////////////////////////////////////////////////////
//
// ## This section defines an attribute
//
Attribute
	= _ qid:QualifiedIdentifier3 value:( _ '=' _ value:AttributeValue { return true } )?
		{
			return true;
		}

AttributeValue "attribute value"
	= s:STRING {
		attributeValue(s)
		return s
	}

////////////////////////////////////////////////////
//
// ## This section defines special tags
//

//
// Processing Instruction
//
PI
	= '<?' id:Identifier __ content:PIContent
		{
			return true;
		}

PIContent
	= '?>'
	/ __ tail:PIContent { return true }
	/ head:. tail:PIContent { return true }

//
// The prolog of the xml file
//
Prolog
	= '<?xml'i
		_ version:XmlVersion _
		encoding:( encoding:Encoding _ { return true } )?
		standalone:( standalone:Standalone _ { return true } )?
		'?>'
		{
			return true;
		}

XmlVersion
	= 'version'i _ '=' _ version:STRING
		{
			return true;
		}

Encoding
	= 'encoding'i _ '=' _ encoding:STRING
		{ return true; }

Standalone
	= 'standalone'i _ '=' _ value:STRING

//
// CDATA section
//
Cdata "CDATA"
	= '<![CDATA[' content:CdataContent { return true; }

CdataContent
	= ']]>'
	/ head:. tail:CdataContent { return true }

//
// XML comments
//
Comment "comment"
	= '<!--' content:CommentContent { return true; }

CommentContent
	= '-->'
	/ head:. tail:CommentContent { return true; }

