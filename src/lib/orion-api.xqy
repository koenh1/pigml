xquery version "1.0-ml";
module namespace orion-api="http://marklogic.com/lib/xquery/orion-api";
declare namespace prop="http://marklogic.com/xdmp/property";
declare namespace error="http://marklogic.com/xdmp/error";
declare namespace s="http://www.w3.org/2005/xpath-functions";
declare namespace tidy="xdmp:tidy";
declare namespace orion="http://marklogic.com/ns/orion";
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare option xdmp:mapping "false";

declare function orion-api:main()
{
  let $api := xdmp:get-request-field("api")
  let $path1 := xdmp:get-request-field("path")
  let $path:=if (contains($path1,'/xpath=')) then substring-before($path1,'/xpath=') else $path1
  let $frag as xs:string?:= if (contains($path1,'/xpath=')) then substring-after($path1,'/frag=') else ()
  let $xpath as xs:string?:= if (contains($path1,'/xpath=')) then substring-before(substring-after($path1,'/xpath='),'/frag=') else ()
  let $parts := fn:tokenize($path, "/")
  let $roles as xs:unsignedLong*:=orion-api:roles()
  let $workspace as object-node()? :=
    if (count($parts) ge 2)
    then
      doc(concat("/orion/workspace/", $parts[2]))/
      object-node()
    else
      ()
  let $project as element(orion:project)? :=
    if (count($parts) ge 3)
    then
      doc(
        concat(
          "/orion/workspace/",
          $parts[2],
          "/project/",
          $parts[3]))/
      *
    else
      ()
  let $method := xdmp:get-request-method()
  let $database :=
    if ($project/orion:database)
    then xdmp:database($project/orion:database/data())
    else xdmp:database()
  return
    if ($database = xdmp:database())
    then
      orion-api:main(
        $api, $method, $path,$xpath,$frag, $workspace, $project,$roles)
    else
      xdmp:invoke-function(
        function() {
          orion-api:main(
            $api, $method, $path,$xpath,$frag, $workspace, $project,$roles)
        },
        <options xmlns="xdmp:eval"><database>{ $database }</database></options>)
};

declare function orion-api:main(
  $api as xs:string,
  $method as xs:string,
  $path as xs:string,
  $xpath as xs:string?,
  $frag as xs:string?,
  $workspace as object-node()?,
  $project as element(orion:project)?,
  $roles as xs:unsignedLong*)
{
  switch ($method)
  case "GET" return
    switch ($api)
    case "file" return orion-api:file-get-request($path,$xpath,$frag,$project,$roles)
    case "validate" return orion-api:validate-get-request($path,$xpath,$frag, $project)
    case "workspace" return orion-api:workspace-get-request($path)
    case "filesearch" return
      orion-api:filesearch-get-request(
        $path, $workspace, $project,$roles)
    case "compile" return orion-api:compile-get-request($path, $project)
    case "update" return orion-api:update-get-request($path, $project)
    default return
      fn:error(
        xs:QName("orion-api:error"),
        "unsupported api " || $api)
  case "PUT" return
    switch ($api)
    case "file" return orion-api:file-put-request($path,$xpath,$frag, $project,$roles)
    case "workspace" return orion-api:workspace-put-request($path)
    default return
      fn:error(
        xs:QName("orion-api:error"),
        "unsupported api " || $api)
  case "POST" return
    switch ($api)
    case "file" return orion-api:file-post-request($path, $project,$roles)
    case "assist" return orion-api:assist-post-request($path, $project)
    case "workspace" return orion-api:workspace-post-request($path)
    case "pretty-print" return orion-api:pretty-print-post-request($path, $project)
    default return
      fn:error(
        xs:QName("orion-api:error"),
        "unsupported api " || $api)
  case "DELETE" return
    switch ($api)
    case "file" return orion-api:file-delete-request($path, $project)
    case "workspace" return orion-api:workspace-delete-request($path, $project)
    default return
      fn:error(
        xs:QName("orion-api:error"),
        "unsupported api " || $api)
  default return
    fn:error(
      xs:QName("orion-api:error"),
      "unsupported method " || $method)
};

declare private  
function ml-uri(
  $path as xs:string,
  $project as element(orion:project))
as xs:string
{
  if (ends-with($path, "/.project.xml") and
      count(tokenize($path, "/")) = 4)
  then base-uri($project)
  else
    concat(
      $project/orion:content-location,
      xdmp:url-decode(
        string-join(tokenize($path, "/")[4 to last()], "/")))
};

declare private  
function orion-uri($path as xs:string)
as xs:string
{
  concat("/orion/file", xdmp:url-decode($path))
};

declare private  
function ml-path(
  $uri as xs:string,
  $project as element(orion:project))
as xs:string
{
  if (starts-with($uri, "/orion/workspace/"))
  then
    let $parents :=
      fn:tokenize(
        substring-after($uri, "/orion/workspace/"), "/")
    return
      concat(
        "/", $parents[1], "/", $parents[3], "/.project.xml")
  else
    concat(
      "/",
      $project/orion:workspace/data(),
      "/",
      $project/@id,
      substring-after(
        $uri,
        ($project/orion:content-location) !
        substring(., 1, string-length(.) - 1)))
};

declare private  
function uri-content-type($uri as xs:string)
as xs:string
{
  let $r := xdmp:uri-content-type($uri)
  return
    (: if ($r = "application/vnd.marklogic-xdmp")
    then "application/xquery"
    else :) 
    if (ends-with($uri, ".project.xml"))
    then "application/x-project"
    else $r
};

declare private  
function orion-path($uri as xs:string)
as xs:string
{
  substring-after($uri, "/orion/file")
};

declare private  
function is-file($uri as xs:string?)
as xs:boolean
{
  contains($uri, "/orion/file")
};

declare private  
function ensure-type($uri as xs:string, $node as node()?)
as node()?
{
  if (fn:empty($node))
  then ()
  else if (($node/binary() or $node/text()) and
      (contains(uri-content-type($uri), "xml") or
       contains(uri-content-type($uri), "json")))
  then
    try {
      document {
        xdmp:unquote(xdmp:quote($node))
      }
    } catch ($ex) {
      $node
    }
  else if ($node/binary() and
      contains(uri-content-type($uri), "text"))
  then
    try {
      document {
        text { xdmp:quote($node) }
      }
    } catch ($ex) {
      $node
    }
  else if (starts-with($uri, "/orion/workspace/"))
  then
    try {
      document {
        xdmp:unquote(xdmp:quote($node))
      }
    } catch ($ex) {
      $node
    }
  else
    $node
};

declare function orion-api:pretty-print-post-request(
  $path as xs:string,
  $project as element(orion:project)?)
as xs:string?
{
  let $content-type := xdmp:get-request-header("Content-Type")
  let $text := xdmp:get-request-body("text")
  let $_ := xdmp:set-response-content-type($content-type)
  return
    switch ($content-type)
    case "application/vnd.marklogic-xdmp" 
    case "application/xquery" return
      try {
        fn:replace(
          xdmp:pretty-print($text),
          "[%]Q[{]http://www.w3.org/2012/xquery[}]private(&#10;)?",
          "private ")
      } catch ($ex) {
        $text
      }
    default return $text
};

declare private  
function get-qname(
  $name as xs:QName,
  $prefixes as map:map)
as xs:string
{
  if (namespace-uri-from-QName($name) = "")
  then string($name)
  else
    concat(
      map:get($prefixes, namespace-uri-from-QName($name)),
      ":",
      local-name-from-QName($name))
};

declare private function type-get-values-enum($type as schema-type()) as xs:string* {
	let $enums:=sc:facets($type)[sc:name(.) = xs:QName("xs:enumeration")]
	return if (fn:empty($enums)) then sc:annotations($type)/xs:appinfo[@source='suggest']!xdmp:eval(.)
	else $enums!sc:component-property("value", .)
};

declare private function type-get-values($type as schema-type()) as xs:string* {
	let $tp:=sc:component-property('item-type',$type)
	return type-get-values-enum(($tp,$type)[1])
};


declare private function join-regex($s as xs:string*) as xs:string {
  if (fn:count($s)=1) then if (starts-with($s,',') or starts-with($s,'(')) then $s else concat(',',$s) 
  else concat(head($s),'(',join-regex(tail($s)),')?')
};
declare private function reqex-freq($s as xs:string*,$min as attribute()?,$max as attribute()?) as xs:string {
  if (fn:empty($max) and fn:empty($min)) then join-regex($s)
  else if (string($max)='1' or fn:empty($max)) then if ($min=0) then concat('(',join-regex($s),')?') else $s
  else concat('(',join-regex($s),'){',if ($min castable as xs:int) then $min else '1',',',if ($max castable as xs:int) then $max else (),'}')
};

declare private function regex($schema as element(xs:schema),$node as element(),$min as attribute()?,$max as attribute()?) as xs:string? {
  typeswitch($node)
  case element(xs:sequence) return reqex-freq($node/node()!regex($schema,.,(),()),($node/@minOccurs,$min)[1],($node/@maxOccurs,$max)[1])
  case element(xs:choice) return reqex-freq(concat('(',string-join($node/node()!regex($schema,.,$min,$max),'|'),')'),($node/@minOccurs,$min)[1],($node/@maxOccurs,$max)[1])
  case element(xs:element) return 
    if ($node/@name) then reqex-freq($node/@name,($node/@minOccurs,$min)[1],($node/@maxOccurs,$max)[1])
    else $schema/xs:element[fn:QName($schema/@targetNamespace,@name)=$node/@ref]!regex($schema,.,($node/@minOccurs,$min)[1],($node/@maxOccurs,$max)[1])
  case element(xs:attribute) return ()
  default return $node/node()!regex($schema,.,$min,$max)
};

declare private function find-elements($schema as element(xs:schema),$node as element()) as xs:string* {
  typeswitch($node)
  case element(xs:sequence) return $node/node()!find-elements($schema,.)
  case element(xs:choice) return $node/node()!find-elements($schema,.)
  case element(xs:element) return 
    if ($node/@name) then $node/@name/string(.)
    else $schema/xs:element[fn:QName($schema/@targetNamespace,@name)=$node/@ref]!find-elements($schema,.)
  case element(xs:attribute) return ()
  default return $node/node()!find-elements($schema,.)
};


declare function orion-api:assist-post-request(
  $path as xs:string,
  $project as element(orion:project))
as object-node()?
{
  let $uri := ml-uri($path, $project)
  let $doc := doc($uri)
  let $_ := xdmp:set-response-content-type("application/json")
  let $data as object-node() := xdmp:unquote(xdmp:get-request-body("text"))/object-node()
  let $xpath as xs:string := $data/info/xpath/data()
  let $prefix as xs:string := $data/prefix/data()
  let $nsprefixes :=
    distinct-values(
      (tokenize($xpath, "/")[contains(., ":")]) !
      substring-before(., ":"))
  let $annotations as xs:boolean := $data/annotations/data()
  let $ns as map:map := $data/info/ns
  let $node0 as node()? := $doc/xdmp:value(
	      if (ends-with($xpath, "/@"))
	      then
	        substring(
	          $xpath, 1, string-length($xpath) - 2)
	      else if (ends-with($xpath, "/text()[1]"))
	      then
	        substring(
	          $xpath, 1, string-length($xpath) - 10)
	      else
	        $xpath,
	    $ns)
  let $node as node()?:=if ((fn:empty($node0)) and contains($xpath,'/@')) then $doc/xdmp:value(substring-before($xpath,'/@'),$ns) else $node0
  return if (fn:empty($node)) then ()
  else
  let $type := sc:type($node)
  return if (fn:empty($type)) then ()
  else
  let $values :=
      try {
          typeswitch ($node)
           case attribute() return
               if ($annotations)
               then
                 let $values :=type-get-values($type)
                 let $annot := sc:facets($type) ! sc:annotations(.)
                 return
                   for $value at $pos in $values
                   where starts-with($value, $prefix)
                   return
                     object-node {
                       "proposal": substring-after($value,$prefix),
                       "description":$value,
                       "hover": ($annot/
                        xs:documentation[
                          contains(
                            lower-case(.), lower-case($value))][
                          1]/
                        text(),
                        null-node {})[1]
                     }
               else type-get-values($type)[starts-with(., $prefix)]!substring-after(., $prefix)
           case element() return
             let $simpletype := sc:simple-type($node)
             let $revns :=
               map:new(
                 map:keys($ns) !
                 map:entry(string(map:get($ns, .)), .))
             return
               if (contains($xpath, "/@")) (: list attributes :)
               then
                 let $atts :=
                   for $att in sc:attributes($type)
                   let $name := sc:name($att)
                   where fn:empty($node/@*[node-name(.) = $name])
                   return $att
                 let $qnames := $atts ! sc:name(.)
                 return
                   if ($annotations)
                   then
                     for $att in $atts 
                     	let $name:=get-qname(sc:name($att), $revns)
                     	where starts-with($name,$prefix)
                     return
                       object-node {
                         "proposal": concat(if ($prefix) then substring-after($name,$prefix) else concat(" ", $name), "=&quot;&quot;"),
                         "description": $name,
                         "hover": (sc:annotations($att)/
                          xs:documentation[1]/
                          text(),
                          null-node {})[1]
                       }
                   else
                     fn:distinct-values(
                       ($qnames ! get-qname(., $revns)) !
                       concat(" ", ., "=&quot;&quot;"))
               else if (not(fn:empty($simpletype)))
               then
                 if ($annotations)
                 then
                   let $values := type-get-values($type)
                   let $annot := sc:facets($type) ! sc:annotations(.)
                   return
                     for $value at $pos in $values
                     where starts-with($value, $prefix)
                     return
                       object-node {
                         "proposal": substring-after($value, $prefix),
                         "description":$value,
                         "hover": ($annot/
                          xs:documentation[
                            contains(
                              lower-case(.),
                              lower-case($value))][
                            1]/
                          text(),
                          null-node {})[1]
                       }
                 else
                   type-get-values($type)[starts-with(., $prefix)] ! (if ($prefix='') then . else object-node{
                   		"proposal":substring-after(., $prefix),
                   		"description": .
                   	})
               else
               	let $schema:=<x>{sc:schema($node)}</x>/*
                 let $tns as xs:string := $schema/@targetNamespace
                 let $nsprefix := map:get($revns, $tns)[. != ""]
                 let $elementtype as element():=<x>{$type}</x>/*
                 let $elements := find-elements($schema,$elementtype)
                 let $regex := concat('^',regex($schema,$elementtype,(),()),'$')
                 let $elprefix:= string-join(for $e in $data/info/context/node() 
                 	let $t:=data($e)
					let $n:=tokenize(name($e),':')[last()]
					where $elements=$n
  					return for $i in 1 to $t return concat(',',$n),'')
                let $_:=xdmp:add-response-header('prefix',xdmp:describe($elprefix))
                let $_:=xdmp:add-response-header('regex',$regex)
                let $_:=xdmp:add-response-header('elements',string-join($elements))
                 let $validelements:=for $element in fn:distinct-values($elements)
                 	let $s:=concat($elprefix,',',$element)
                 	where fn:matches($s,$regex)
                 	return $element
                 return
                   if ($annotations)
                   then
                     for $element in $validelements
                     let $n :=
                       concat(
                         "<",
                         $nsprefix ! concat(., ":"),
                         $element,
                         "></",
                         $nsprefix ! concat(., ":"),
                         $element,
                         ">")
                     let $annot :=
                       ($schema//
                        xs:element[string(@name) = $element]/
                        xs:annotation/
                        xs:documentation)[1]
                     where starts-with($n, $prefix)
                     return
                       object-node {
                         "proposal": substring-after($n, $prefix),
                         "description":$n,
                         "hover": ($annot/text(), null-node {})[1]
                       }
                   else
                     ($validelements !
                      concat(
                        "<",
                        $nsprefix ! concat(., ":"),
                        .,
                        "></",
                        $nsprefix ! concat(., ":"),
                        .,
                        ">")[starts-with(., $prefix)]) !
                     substring-after(., $prefix)
           default return ()
      } catch ($ex) {
      	let $_:=xdmp:add-response-header('x-error',xdmp:describe($ex,5000,5000))
      	let $_:=xdmp:log(xdmp:describe($ex, (), ()))
      	return ()
      }
  return
    object-node {
      "values": array-node {
        $values
      }
    }
};

declare function orion-api:compile-get-request(
  $path as xs:string,
  $project as element(orion:project))
as object-node()?
{
  let $uri := ml-uri($path, $project)
  let $type := uri-content-type($uri)
  let $text := xdmp:quote(doc($uri))
  return
    switch ($type)
    case "application/xquery"
    case "application/vnd.marklogic-xdmp" return
      let $namespace :=
        fn:analyze-string(
          $text,
          "^\s*module\s+namespace\s*([^=]+)\s*=\s*('([^']+)'|&quot;([^&quot;]+)&quot;)",
          "m")//
        s:group[@nr = (3, 4)]/
        data()
      let $result :=
        if (fn:empty($namespace))
        then
          try {
            xdmp:eval(
              $text,
              (),
              <options xmlns="xdmp:eval"><static-check>true</static-check></options>)
          } catch ($ex) {
            $ex
          }
        else
          let $tempfile := "/temp" || xdmp:random(1000000) || ".xqy"
          let $_ :=
            xdmp:eval(
              "declare variable $uri external;declare variable $text external;xdmp:document-insert($uri, text{$text})",
              (xs:QName("uri"),
               $tempfile,
               xs:QName("text"),
               $text),
              <options xmlns="xdmp:eval"><database>{ xdmp:modules-database() }</database><isolation>different-transaction</isolation></options>)
          let $r :=
            try {
              xdmp:eval(
                concat(
                  "import module namespace x='",
                  $namespace,
                  "' at '",
                  $tempfile,
                  "';&#10;0"),
                (),
                <options xmlns="xdmp:eval"><static-check>true</static-check></options>)
            } catch ($ex) {
              $ex
            }
          let $_ :=
            xdmp:eval(
              "declare variable $uri external;xdmp:document-delete($uri)",
              (xs:QName("uri"), $tempfile),
              <options xmlns="xdmp:eval"><database>{ xdmp:modules-database() }</database><isolation>different-transaction</isolation></options>)
          return $r
      return
        if (fn:empty($result))
        then
          object-node {
            "message": "success"
          }
        else
          (document {
             $result
           }/
           error:error) !
          (let $line as xs:int := ./error:stack/error:frame[1]/error:line/xs:int(.)
           let $column as xs:int :=
             ./
             error:stack/
             error:frame[1]/
             error:column/
             xs:int(.)
           let $start :=
             sum(
               (fn:tokenize($text, "&#10;")[1 to $line - 1]) !
               (string-length(.) + 1)) +
             $column
           let $end :=
             $start +
             string-length(fn:tokenize($text, "&#10;")[$line]) -
             $column
           return
             object-node {
               "message": ./error:format-string/data(),
               "line": $line,
               "column": $column,
               "start": $start,
               "end": $end
             })
    default return object-node {
    	"message": ("unexpected type" || $type)
    }
};

declare function orion-api:validate-get-request(
  $path as xs:string,
  $xpath as xs:string?,
  $frag as xs:string?,
  $project as element(orion:project))
as object-node()
{
  let $uri := ml-uri($path, $project)
  let $type := uri-content-type($uri)
  let $doc := if ($uri=base-uri($project)) then document{$project} else if (fn:empty($xpath)) then doc($uri) else doc($uri)/xdmp:unpath($xpath)
  let $hash := document-hash($doc)
  let $_ := xdmp:add-response-header("ETag", $hash)
  return
    switch ($type)
    case "application/xslt+xml" return
      object-node {
        "uri": $uri,
        "problems": array-node {
          try {
            let $_ := xdmp:xslt-eval($doc,<dummy/>,(),<options xmlns="xdmp:eval"><static-check>true</static-check></options>)
            return ()
          } catch ($ex) {
            $ex !
            object-node {
              "description": concat(
                ./error:message/data(),
                " ,",
                ./error:data/error:datum[1]/data()),
              "line": ./error:stack/error:frame[1]/error:line/xs:int(.),
              "severity": "warning",
              "start": ./
              error:stack/
              error:frame[1]/
              error:column/
              xs:int(.),
              "end": ./
              error:stack/
              error:frame[1]/
              error:column/
              xs:int(.) +
              1
            }
          }
        }
      }    
    case "text/html" return
      object-node {
        "uri": $uri,
        "problems": array-node {
          (xdmp:tidy(
             xdmp:quote($doc),
             <options xmlns="xdmp:tidy">
		<doctype>transitional</doctype></options>)[1]/
           (tidy:warning | tidy:error)) !
          object-node {
            "description": ./data(),
            "severity": local-name(.),
            "line": ./@tidy:line/xs:int(.),
            "start": ./@tidy:column/xs:int(.),
            "end": ./@tidy:column/xs:int(.) + 1
          }
        }
      }
    case "application/vnd.marklogic-xdmp" 
    case "application/xquery" return
      object-node {
        "uri": $uri,
        "problems": array-node {
          try {
            let $_ := xdmp:pretty-print(xdmp:quote($doc))
            return ()
          } catch ($ex) {
            $ex !
            object-node {
              "description": concat(
                ./error:message/data(),
                " ,",
                ./error:data/error:datum[1]/data()),
              "line": ./error:stack/error:frame[1]/error:line/xs:int(.),
              "severity": "warning",
              "start": ./
              error:stack/
              error:frame[1]/
              error:column/
              xs:int(.),
              "end": ./
              error:stack/
              error:frame[1]/
              error:column/
              xs:int(.) +
              1
            }
          }
        }
      }
    default return
      object-node {
        "uri": $uri,
        "problems": array-node {
          try {
            let $d :=
              if ($doc/element())
              then $doc
              else xdmp:unquote(xdmp:quote($doc))
            return
              if (xdmp:describe(sc:type($d)) !=
                  "(any(lax,!())*)|#PCDATA")
              then
                let $error := xdmp:validate($d)/error:error
                return
                  if (fn:empty($error))
                  then ()
                  else
                    let $xpath :=
                      $error/
                      error:data/
                      error:datum[last() - 1]/
                      data()
                    let $offsets := $xpath ! node-offset-xpath($d, .,$project)
                    return
                      object-node {
                        "ex": if (fn:empty($offsets))
                        then xdmp:describe($error, (), ())
                        else "",
                        "description": if ($error/error:message/data())
                        then
                          string-join(
                            ($error/error:message/data(),
                             $error/
                             error:data/
                             error:datum[1]/
                             data()),
                            "&#10;")
                        else
                          xdmp:describe($error),
                        "line": if ($offsets) then $offsets[1] else 0,
                        "severity": "error",
                        "start": if ($offsets[2]) then $offsets[2] else 0,
                        "end": if ($offsets[3]) then $offsets[3] else 0
                      }
              else
                ()
          } catch ($ex) {
            if ($ex/error:data/error:datum[3] castable as xs:int)
            then
              object-node {
                "description": concat(
                  $ex/error:message/data(),
                  " ,",
                  $ex/error:data/error:datum[1]/data()),
                "line": $ex/error:data/error:datum[3]/xs:int(.),
                "severity": "warning",
                "start": 0,
                "end": 1
              }
            else
              xdmp:rethrow()
          }
        }
      }
};

declare function orion-api:filesearch-get-request(
  $path as xs:string,
  $workspace as object-node()?,
  $project as element(orion:project)?,
  $roles as xs:unsignedLong*)
as object-node()
{
  let $sort as xs:string := xdmp:get-request-field("sort")
  let $rows as xs:integer := xs:integer(xdmp:get-request-field("rows"))
  let $start as xs:integer := xs:integer(xdmp:get-request-field("start"))
  let $q as xs:string := xdmp:get-request-field("q")
  let $words :=
    if (fn:matches($q, "^[A-Z][A-Za-z]*:"))
    then ()
    else
      fn:replace(
        $q,
        "^((&quot;([^&quot;]+)&quot;)|([^ ]+))[ ].*$",
        "$3$4")
  let $names :=
    ((fn:tokenize(
        fn:replace(
          $q, "(^Name|.+ Name)(Lower)?:([^ ]+).*", "$3"),
        "/") !
      fn:replace(., "[.]", "[.]")) !
     fn:replace(., "[*]", ".*")) !
    fn:replace(., "[?]", ".")
  let $namelower := contains($q, "NameLower:")
  let $location := fn:replace($q, ".+ Location:([^ ]+).*", "$1")
  let $case-sensitive as xs:boolean := fn:replace($q, ".+ CaseSensitive:([^ ]+).*", "$1") = "true"
  let $whole-word as xs:boolean := fn:replace($q, ".+ WholeWord:([^ ]+).*", "$1") = "true"
  let $regex as xs:boolean := fn:replace($q, ".+ RegEx:([^ ]+).*", "$1") = "true"
  let $workspaces as object-node()+ :=
    if (fn:empty($workspace))
    then xdmp:directory("/orion/workspace/", "1")/object-node()
    else $workspace
  let $projects as element(orion:project)+ :=
    if (fn:empty($project))
    then
      $workspaces !
      xdmp:directory(
        concat("/orion/workspace/", ./Id/data(), "/project/"),
        "1")/
      *
    else
      $project
  let $result :=
    for $oproject in $projects
    let $uris0 := cts:uri-match(ml-uri(orion-path($location), $oproject))
    let $uris :=
      if ($names)
      then
        for $uri in $uris0
        let $n := fn:tokenize($uri, "/")[. != ""][last()]
        let $m :=
          for $p in $names
          return
            fn:matches(
              $n,
              concat("^", $p, "$"),
              if ($namelower) then "i" else "")
        return if ($m) then $uri else ()
      else
        $uris0
    let $location-query := cts:document-query($uris)
    let $word-queries :=
      for $word in fn:tokenize($words, "[^\w]+")
      let $pat := if ($whole-word) then $word else concat($word, "*")
      return
        cts:word-query(
          $pat,
          if ($case-sensitive)
          then "case-sensitive"
          else "case-insensitive")
    return
      for $r in
        (cts:search(
           doc(),
           cts:and-query(($word-queries, $location-query)))[$start + 1 to $start + $rows]) !
        base-uri(.)
      return orion-api:file($oproject,$roles, $r, 0, false(),0)
  return
    object-node {
      "response": object-node {
        "docs": array-node {
          $result
        },
        "numFound": number-node {
          count($result)
        },
        "start": $start
      },
      "responseHeader": object-node {
        "params": object-node {
          "fl": "Name,NameLower,Length,Directory,LastModified,Location,Path,RegEx,CaseSensitive,WholeWord",
          "fq": array-node {
            concat("Location:", $location),
            concat("UserName:", xdmp:get-current-user())
          },
          "rows": $rows,
          "sort": $sort,
          "start": $start,
          "wt": "json"
        },
        "status": 0
      }
    }
};

declare function orion-api:workspace-get-request($path as xs:string)
as object-node()?
{
  if ($path = "")
  then
    let $uris :=
      cts:uris(
        (), (), cts:directory-query("/orion/workspace/", "1"))
    let $ts := fn:max($uris ! xdmp:document-timestamp(.))
    let $etag := xdmp:get-request-header("If-None-Match")
    return
      if ($etag and xdmp:hex-to-integer($etag) = $ts)
      then xdmp:set-response-code(304, "not modified")
      else
        let $_ := xdmp:set-response-content-type("application/json")
        let $r :=
          object-node {
            "UserName": xdmp:get-current-user(),
            "Id": string(xdmp:get-current-userid()),
            "Workspaces": array-node {
              for $x in $uris
              let $d := document($x)
              return
                object-node {
                  "Id": xdmp:integer-to-hex(xdmp:hash64($x)),
                  "Location": $x,
                  "LastModified": number-node {
                    xdmp:document-timestamp($x) idiv 10000
                  },
                  "Name": $d/Name,
                  "Owner": $d/Owner
                }
            }
          }
        let $_ :=
          xdmp:add-response-header(
            "ETag", xdmp:integer-to-hex($ts))
        return $r
  else
    let $w := document(concat("/orion/workspace", $path))
    return
      if (fn:empty($w))
      then xdmp:set-response-code(404, "not found")
      else
        let $_ := xdmp:set-response-content-type("application/json")
        let $ts :=
          xdmp:document-timestamp(
            concat("/orion/workspace", $path))
        let $_ :=
          xdmp:add-response-header(
            "ETag", xdmp:integer-to-hex($ts))
        let $ws := tokenize($path, "/")[1]
        let $projects :=
          xdmp:directory(
            concat("/orion/workspace", $path, "/project/"),
            "1")
        return
          object-node {
            "Id": substring($path, 2),
            "Directory": true(),
            "ChildrenLocation": concat("/orion/workspace", $path),
            "Location": concat("/orion/workspace", $path),
            "Name": $w/Name,
            "Projects": array-node {
              for $project in $projects/orion:project
              return
                object-node {
                  "Id": $project/@id/data(),
                  "Workspace": $ws,
                  "Location": base-uri($project),
                  "Name": $project/orion:name/data(),
                  "ContentLocation": $project/orion:content-location/data()
                }
            },
            "Children": array-node {
              for $project in $projects/orion:project
              return
                object-node {
                  "Directory": true(),
                  "Id": $project/@id/data(),
                  "Name": $project/orion:name/data(),
                  "Location": concat(
                    orion-uri($path), "/", $project/@id, "/"),
                  "ChildrenLocation": concat(
                    orion-uri($path),
                    "/",
                    $project/@id,
                    "/?depth=1"),
                  "ExportLocation": export-location(
                    concat(
                      orion-uri($path), "/", $project/@id)),
                  "ImportLocation": import-location(
                    concat(
                      orion-uri($path), "/", $project/@id)),
                  "LocalTimeStamp": xdmp:document-timestamp(base-uri($project)) idiv
                  10000
                }
            }
          }
};

declare function orion-api:workspace-put-request($path as xs:string)
{
  ()
};

declare function orion-api:capabilities($uri as xs:string,$roles as xs:unsignedLong*) as object-node() {
	let $admin:=xdmp:role('admin')
	let $capability:=if ($admin=$roles) then () else xdmp:document-get-permissions($uri)[sec:role-id=$roles]//sec:capability/string()
	let $readonly:=($admin=$roles)
	return object-node {
        "Executable": ($admin=$roles) or $capability=('execute') or (ends-with($uri,'/') and $capability=('read')),
        "Immutable": not($admin=$roles or $capability=('update','delete')),
        "ReadOnly": not($admin=$roles or $capability=('update')),
        "SymLink": false()
      }
};

declare function orion-api:roles() as xs:unsignedLong* {
	let $user:=xdmp:get-request-field('user')
	let $me:=if (fn:empty($user)) then xdmp:get-current-user() else $user
	return xdmp:user-roles($me)
};


declare function orion-api:amped-uri-exists($uri as xs:string, $dir as xs:boolean)
as xs:boolean
{
  let $uris :=
    if ($dir)
    then
      ($uri,
       concat(
         $uri, if (ends-with($uri, "/")) then () else "/", "*"))
    else
      $uri
  return not(empty($uris ! cts:uri-match(.)))
};

declare private  
function project-xml(
  $id as xs:string,
  $name as xs:string,
  $ws as xs:string,
  $content-location as xs:string)
as element(orion:project)
{
  <orion:project id="{ $id }">
		<orion:name>{ $name }</orion:name>
		<orion:workspace>{ $ws }</orion:workspace>
		<orion:database>{ xdmp:database-name(xdmp:database()) }</orion:database>
		<orion:content-location>{ $content-location }</orion:content-location>
		<orion:permissions user-defaults="yes"/>
		<orion:collections user-defaults="yes"/>
		<orion:creator>{ xdmp:get-current-user() }</orion:creator>
		<orion:created>{ fn:current-dateTime() }</orion:created>
	</orion:project>
};

declare function orion-api:workspace-post-request($path as xs:string)
as object-node()
{
  let $slug as xs:string? := xdmp:get-request-header("Slug")
  let $create-options :=
    xdmp:get-request-header("X-Create-Options") !
    fn:tokenize(., "[ ,]+")
  let $body :=
    if (fn:empty(xdmp:get-request-body("text")))
    then ()
    else xdmp:unquote(xdmp:get-request-body("text"))
  let $name as xs:string := if (fn:empty($slug)) then $body/Name/data() else $slug
  let $ts :=
    xdmp:eval(
      "xdmp:request-timestamp()",
      (),
      <options xmlns="xdmp:eval"><transaction-mode>query</transaction-mode></options>)
  let $_ := xdmp:add-response-header("ETag", xdmp:integer-to-hex($ts))
  return
    if ($path = "")
    then
      let $id :=
        (for $i in 1 to 1000000
         where
           orion-api:amped-uri-exists(
             "/orion/workspace/E" || $i, false()) =
           false()
         return concat("E", $i))[1]
      let $_ :=
        xdmp:document-insert(
          "/orion/workspace/" || $id,
          object-node {
            "Id": $id,
            "Name": $name,
            "Owner": xdmp:get-current-user()
          },
          xdmp:default-permissions("/orion/workspace/" || $id),
          "/orion/workspaces/")
      return
        object-node {
          "Id": $id,
          "Name": $slug,
          "Location": concat("/orion/workspace/" || $id),
          "Projects": array-node {},
          "Children": array-node {}
        }
    else
      let $create := $body/CreateIfDoesntExist/data()
      let $id as xs:string :=
        if ($create-options = "move" and $body/Location)
        then tokenize($body/Location/data(), "/")[last()]
        else
          (for $i in 1 to 1000000
           where
             orion-api:amped-uri-exists(
               concat(
                 "/orion/workspace", $path, "/project/A", $i),
               false()) =
             false()
           return concat("A", $i))[1]
      let $location as xs:string :=
        if (fn:empty($body/ContentLocation/data()))
        then concat(orion-uri($path), "/", $id, "/")
        else $body/ContentLocation/data()
      let $ws := substring-after($path, "/")
      let $d :=
        object-node {
          "Id": $id,
          "Workspace": $ws,
          "Location": concat("/orion/workspace", $path, "/project/", $id),
          "Name": $name,
          "Owner": xdmp:get-current-user(),
          "ContentLocation": $location
        }
      let $project := project-xml($id, $name, $ws, $location)
      let $uri:=concat("/orion/workspace", $path, "/project/", $id)
      let $_ :=
        xdmp:document-insert(
          $uri,
          $project,
          xdmp:default-permissions($uri),xdmp:default-collections($uri))
      let $_ :=
        try {
          xdmp:directory-create(
            ml-uri(orion-path($location), $project),
            xdmp:default-permissions($uri),xdmp:default-collections($uri))
        } catch ($ex) {
          xdmp:log($ex)
        }
      return $d
};

declare function orion-api:workspace-delete-request(
  $path as xs:string,
  $project as element(orion:project)?)
{
  let $dir := if ($project) then ml-uri("/orion/file/", $project) else ()
  let $_ :=
    if (orion-api:amped-uri-exists(
          concat("/orion/workspace", $path), false()))
    then xdmp:document-delete(concat("/orion/workspace", $path))
    else ()
  let $_ :=
    if ($dir and orion-api:amped-uri-exists($dir, false()))
    then xdmp:document-delete($dir)
    else ()
  return ""
};

declare private  
function orion-api:children(
  $project as element(orion:project),
  $roles as xs:unsignedLong*,
  $uri as xs:string,
  $depth as xs:int)
as json:object*
{
  let $uris :=
    cts:uris(
      (),
      "any",
      cts:directory-query(
        $uri, if ($depth = 1) then "1" else "infinity"))[count(tokenize(substring-after(., $uri), "/")[. != ""]) le
      $depth]
  return $uris ! orion-api:file($project,$roles, ., $depth - 1, false(),0)
};

declare private  
function import-location($uri as xs:string)
as xs:string
{
  concat("/xfer/import", substring-after($uri, "/file"))
};

declare private  
function export-location($uri as xs:string)
as xs:string
{
  concat(
    "/xfer/export",
    substring-after(
      if (ends-with($uri, "/"))
      then substring($uri, 1, string-length($uri) - 1)
      else $uri,
      "/file"))
};

declare function ser(
  $key as xs:string?,
  $node as item(),
  $indent as xs:string)
as xs:string*
{
  concat(
    if ($key)
    then concat($indent, "&quot;", $key, "&quot;:")
    else $indent,
    typeswitch ($node)
     case object-node() return
       concat(
         "{&#10;",
         string-join(
           ($node/node()) ! ser(name(.), ., $indent || " "),
           ",&#10;"),
         "&#10;",
         $indent,
         "}")
     case array-node() return
       concat(
         "[",
         $indent,
         "&#10;",
         string-join(
           ($node/node()) ! ser((), ., $indent || "  "),
           ",&#10;"),
         "&#10; ",
         $indent,
         "]")
     case text() return
       concat(
         "&quot;",
         replace($node/data(), "&quot;", "\\&quot;"),
         "&quot;")
     case null-node() return "null"
     case number-node() return $node/data()
     case boolean-node() return $node/data()
     default return
       if ($node instance of xs:string)
       then
         concat(
           "&quot;",
           replace($node/data(), "&quot;", "\\&quot;"),
           "&quot;")
       else
         string($node))
};

declare private  
function format-document($node as node(),$project as element(orion:project))
as item()
{
  if ($node/element())
  then
  let $options:=if ($project/orion:output-options) then <options xmlns="xdmp:quote">
  	{for $a in $project/orion:output-options/@* return element{fn:QName('xdmp:quote',name($a))}{$a/data()}}
  	</options> else 
  	<options xmlns="xdmp:quote"><indent-tabs>yes</indent-tabs><default-attributes>yes</default-attributes><omit-xml-declaration>yes</omit-xml-declaration><indent>yes</indent><indent-untyped>yes</indent-untyped></options>
    return xdmp:quote($node,$options)
  else if ($node/object-node())
  then ser((), $node/object-node(), "")
  else $node
};

declare function fragments($context as node(),$fragments as element(orion:fragment)+,$ns as map:map,$depth as xs:int,$attributes as object-node(),$location as xs:string) {
    let $matches:=(for $p in $fragments
      where some $node in $context/../xdmp:value($p/@match,$ns) satisfies $node is $context
      return $p)[1]
    let $name:=$context/xdmp:value($matches/@select-name,$ns)/string()
    return if ($depth gt 0 and $matches/@select-children) then
    object-node{
    		"Directory":true(),
    		"Attributes":$attributes,
    		"Location":concat($location,'/xpath=',fn:encode-for-uri(xdmp:path($context,false())),'/frag=',fn:encode-for-uri(xdmp:path($matches,false()))),
    		"Name":string($name),
    		"Children":array-node{$context/xdmp:value($matches/@select-children,$ns)!fragments(.,$fragments,$ns,$depth -1,$attributes,$location)}
    	}
    else if ($matches/@select-children) then object-node{
    	"Length":string-length(xdmp:quote($context)),
    	"Attributes":$attributes,
    	"Directory":exists($matches/@select-children),
    	"Location":concat($location,'/xpath=',fn:encode-for-uri(xdmp:path($context,false())),'/frag=',fn:encode-for-uri(xdmp:path($matches,false()))),
    	"ChildrenLocation":concat($location,'/xpath=',fn:encode-for-uri(xdmp:path($context,false())),'/frag=',fn:encode-for-uri(xdmp:path($matches[1],false())),'?depth=1'),
    	"Name":string($name)
    } else object-node{
    	"Length":string-length(xdmp:quote($context)),
    	"Attributes":$attributes,
    	"ETag": document-hash($context),
    	"Directory":exists($matches/@select-children),
    	"Location":concat($location,'/xpath=',fn:encode-for-uri(xdmp:path($context,false())),'/frag=',fn:encode-for-uri(xdmp:path($matches,false()))),
    	"Name":string($name)||'.xml'
    }
};

declare function simple-file($project as element(orion:project),$uri as xs:string,$doc as document-node(),$ts as xs:integer,$hash as xs:string?,$roles as xs:unsignedLong*,$path as xs:string,$name as xs:string,$include-parents as xs:boolean,$parents as xs:string*,$depth as xs:integer) as json:object {
  let $attributes as object-node():=orion-api:capabilities($uri,$roles)
  let $ns as map:map:=map:new($project/orion:namespaces/orion:namespace!map:entry(./@prefix,./@uri/data()))
  let $root:=(for $frag in $project/orion:fragments/orion:fragment-root
  	return ($frag,$doc/xdmp:value(substring-after($frag/@select,'/'),$ns)))[1 to 2]
  return if (count($root)=2) then
  	fragments($root[2],$root[1]/orion:fragment,$ns,$depth,$attributes,orion-uri($path))
  else
  json:object() 
  !map-with(.,"Attributes",$attributes) 
  !map-with(., "Directory", false())
  !map-with(., "Length", document-length($doc)) 
  !(if ($ts!=0)
      then
        map-with(.,"LocalTimeStamp",$ts)
      else
        .) 
  !map-with(., "Location", orion-uri($path)) 
  !map-with(., "Name", $name) 
  !map-with(., "ETag", if (empty($hash)) then document-hash($doc) else $hash) 
  !(if ($include-parents)
    then
      map-with(
        .,
        "Parents",
        array-node {
          for $parent at $pos in $parents
          where $pos gt 1
          order by $pos descending
          return
            object-node {
              "ChildrenLocation": concat(
                orion-uri(
                  concat(
                    "/",
                    string-join($parents[1 to $pos], "/"))),
                "/?depth=1"),
              "Location": concat(
                orion-uri(
                  concat(
                    "/",
                    string-join($parents[1 to $pos], "/"))),
                "/"),
              "Name": $parent
            }
        })
    else
      .) 
  !map-with(.,"FileEncoding",array-node {"UTF-8"})
};

declare 
function orion-api:file(
  $project as element(orion:project),
  $roles as xs:unsignedLong*,
  $uri as xs:string,
  $depth as xs:int,
  $include-parents as xs:boolean,
  $ts0 as xs:integer)
as json:object
{
  let $path as xs:string := ml-path($uri, $project)
  let $ts as xs:integer?:=if ($ts0=0) then
    if (xdmp:document-properties($uri)//prop:last-modified)
    then
      ((xdmp:document-properties($uri)//prop:last-modified) !
       xs:dateTime(.) -
       xs:dateTime("1970-01-01T00:00:00-00:00")) div
      xs:dayTimeDuration("PT0.001S")
    else
      xdmp:document-timestamp($uri) idiv 10000
  else $ts0
  let $directory as xs:boolean :=
    ends-with($uri, "/") or
    count(xdmp:document-properties($uri)//prop:directory) != 0
  let $parents as xs:string+ := tokenize($path, "/")[. != ""][1 to last() - 1]
  let $name as xs:string := tokenize($path, "/")[. != ""][last()]
  let $oproject :=
    if ($directory and count($parents) = 1 or
        $name = ".project.xml" and count($parents) = 2)
    then
        object-node {
          "Attributes": orion-api:capabilities(base-uri($project),$roles),
          "Directory": false(),
          "ETag": document-hash(document{$project}),
          "Length": document-length(document{$project}),
          "LocalTimeStamp":if (fn:empty($ts)) then 0 else $ts,
          "Name": ".project.xml",
          "Location": 
            concat(
              orion-uri(ml-path($uri, $project)),
              if ($uri=base-uri($project)) then () else ".project.xml")
        }
    else
      ()
  return
    if (count($parents) = 2 and $name = ".project.xml")
    then $oproject
    else
    if ($directory) then
      json:object() !
                map-with(
                  .,
                  "Attributes",orion-api:capabilities($uri,$roles)) !
               map-with(., "Directory", true()) !
             (if ($ts)
              then
                map-with(
                  .,
                  "LocalTimeStamp",
                  number-node {
                    $ts
                  })
              else
                .) !
            map-with(., "Location", orion-uri($path)) !
           map-with(., "Name", $name)  !
            map-with(
              ., "ImportLocation", import-location($uri)) !
            map-with(
              ., "ExportLocation", export-location($uri))
          !
        (if ($depth gt 0)
         then
           map-with(
             .,
             "Children",
             array-node {
               orion-api:children($project,$roles, $uri, $depth),
               $oproject
             })
         else
           .) !
       (if ($include-parents)
        then
          map-with(
            .,
            "Parents",
            array-node {
              for $parent at $pos in $parents
              where $pos gt 1
              order by $pos descending
              return
                object-node {
                  "ChildrenLocation": concat(
                    orion-uri(
                      concat(
                        "/",
                        string-join($parents[1 to $pos], "/"))),
                    "/?depth=1"),
                  "Location": concat(
                    orion-uri(
                      concat(
                        "/",
                        string-join($parents[1 to $pos], "/"))),
                    "/"),
                  "Name": $parent
                }
            })
        else
          .) !
      map-with(
        .,
        if ($directory)
        then "ChildrenLocation"
        else "FileEncoding",
        if ($directory)
        then concat(orion-uri($path), "?depth=1")
        else
          array-node {
            "UTF-8"
          })
    else
      simple-file($project,$uri,doc($uri),$ts,(),$roles,$path,$name,$include-parents,$parents,$depth)
      
};

declare function orion-api:file-get-request(
  $path as xs:string,
  $xpath as xs:string?,
  $frag as xs:string?,
  $project as element(orion:project),
  $roles as xs:unsignedLong*)
{
  let $uri := ml-uri($path, $project)
  let $depth as xs:int :=
    if (fn:empty(xdmp:get-request-field("depth")))
    then 0
    else xs:int(xdmp:get-request-field("depth"))
  let $directory as xs:boolean :=
    ends-with($uri, "/") or
    count(xdmp:document-properties($uri)//prop:directory) != 0
  let $parts as xs:string+ :=
    if (fn:empty(xdmp:get-request-field("parts")))
    then if ($directory or not(fn:empty(xdmp:get-request-field("depth")))) then "meta" else "body"
    else fn:tokenize(xdmp:get-request-field("parts"), "[, ]+")
  let $parents := tokenize($path, "/")[. != ""][1 to last() - 1]
  return
    if ($uri=base-uri($project) or orion-api:amped-uri-exists($uri, true()))
    then
      let $result :=
        for $part in $parts
        return
          switch ($part)
          case "meta" return 
          	if (fn:empty($xpath)) then orion-api:file($project,$roles, $uri, $depth, true(),0)
			else 
			fragments(	doc($uri)/xdmp:unpath($xpath),$project/xdmp:unpath($frag)/parent::orion:fragment-root/orion:fragment,
					map:new($project/orion:namespaces/orion:namespace!map:entry(./@prefix,./@uri/data())),$depth,
					orion-api:capabilities($uri,$roles),orion-uri($path))
          	
          case "body" return
            let $d0 := if ($uri=base-uri($project)) then document{$project} else doc($uri)
            let $d:=if (fn:empty($xpath)) then $d0 else $d0/xdmp:unpath($xpath)
            let $hash := document-hash($d)
            let $_ := xdmp:add-response-header("ETag", $hash)
            let $_ :=
              if ($d0/text() and
                  not(contains(uri-content-type($uri), "xml")))
              then
                xdmp:add-response-header(
                  "Accept-Patch",
                  "application/json-patch; charset=UTF-8")
              else
                ()
            return if (fn:empty($d)) then text { "" } else $d
          default return
            fn:error(
              xs:QName("orion-api:file-get-request"),
              "unsupported part " || $part)
      return
        if (fn:count($parts) = 1)
        then
          let $_ :=
            xdmp:set-response-content-type(
              if ($parts = "meta")
              then "application/json"
              else if (fn:empty($xpath))
              then uri-content-type($path)
	          else "application/xml")
          return
          	if ($parts='meta') then $result
            else if ($result instance of node())
            then format-document($result,$project)
            else text { xdmp:quote($result) }
        else
          xdmp:multipart-encode(
            "boundary10382384-2840",
            <manifest>{
                for $part in $parts
                return
                  <part><headers><Content-Type>{
                          if ($part = "meta")
                          then "application/json"
                          else uri-content-type($path)
                        }</Content-Type></headers></part>
              }</manifest>,
            for $r in $result
            return
              if ($r instance of node())
              then format-document($r,$project)
              else text { xdmp:quote($r) })
    else if (fn:tokenize($path, "/")[last()] =
        (".tern-project",
         ".eslintrc.js",
         ".eslintrc.json",
         "package.json",
         ".eslintrc") and
        $parts = "body" and
        count($parts) = 1)
    then object-node {}
    else
      let $_ := xdmp:set-response-code(404, $uri || " not found (1)")
      return ()
};

declare private  
function orion-api:patch(
  $d as xs:string,
  $start as xs:integer,
  $end as xs:integer,
  $s as xs:string)
as xs:string
{
  concat(
    substring($d, 1, $start),
    $s,
    substring($d, $end + 1, string-length($d)))
};

declare function orion-api:file-post-request(
  $path as xs:string,
  $project as element(orion:project),
  $roles as xs:unsignedLong*)
{
  let $slug as xs:string? := xdmp:get-request-header("Slug")
  let $create-options :=
    xdmp:get-request-header("X-Create-Options") !
    fn:tokenize(., "[ ,]+")
  let $method-override :=
    xdmp:get-request-header("X-HTTP-Method-Override") !
    fn:tokenize(., "[ ,]+")
  let $body :=
    if (fn:empty(xdmp:get-request-body("text")))
    then ()
    else xdmp:unquote(xdmp:get-request-body("text"))
  let $name as xs:string? := if (fn:empty($slug)) then $body/Name/data() else $slug
  let $ts :=
    xdmp:eval(
      "xdmp:request-timestamp()",
      (),
      <options xmlns="xdmp:eval"><transaction-mode>query</transaction-mode></options>) idiv
    10000
  let $directory :=
    if ($body/Directory/data())
    then xs:boolean($body/Directory/data())
    else if ($body/Location/data())
    then ends-with($body/Location/data(), "/")
    else false()
  let $_ := xdmp:add-response-header("ETag", xdmp:integer-to-hex($ts))
  let $parents := tokenize($path, "/")[. != ""]
  let $uri :=
    ml-uri(
      concat(
        $path,
        if (ends-with($path, "/") or fn:empty($name))
        then ()
        else "/",
        $name,
        if ($directory) then "/" else ()),
      $project)
  let $exists as xs:boolean := amped-uri-exists($uri, false())
  return
    if ($create-options = "no-overwrite" and $exists)
    then
      xdmp:set-response-code(
        412, "file " || $uri || " exists")
    else if ($method-override = "PATCH")
    then
      let $ifmatch as xs:string := normalize-space(xdmp:get-request-header("If-Match"))
      let $doc := doc($uri)
      let $hash := if ($ifmatch != "") then document-hash($doc) else ()
      return
        if ($ifmatch = "" or $ifmatch = $hash)
        then
          let $ndoc0 :=
            document {
              text {
                fn:fold-left(
                  function($a, $diff) {
                    orion-api:patch(
                      $a,
                      ($diff/start) ! xs:integer(.),
                      ($diff/end) ! xs:integer(.),
                      $diff/text/data())
                  },
                  xdmp:quote($doc),
                  $body/diff)
              }
            }
          let $ndoc := ensure-type($uri, $ndoc0)
          let $_ := xdmp:node-replace($doc, $ndoc)
          let $nhash := document-hash($ndoc)
          let $_ := xdmp:add-response-header("ETag", $nhash)
          return
          simple-file($project,$uri,$ndoc,$ts,$nhash,$roles,$path,tokenize($uri,'/')[last()],false(),(),1)
        else
          xdmp:set-response-code(
            414,
            "document " || $uri || " changed " || $ifmatch || "!=" || $hash)
    else if ($create-options = ("move", "copy") and
        is-file($body/Location/data()) and
        ends-with($body/Location/data(), "/"))
    then
      let $source :=
        ml-uri(
          substring-after($body/Location/data(), "/file"),
          $project)
      let $sources := cts:uri-match(concat($source, "*"))
      return
        if (fn:empty($sources))
        then xdmp:set-response-code(404, "not found " || $source)
        else
          let $_ :=
            for $uri2 in $sources
            let $d := doc($uri2)
            let $t := concat($uri, substring-after($uri2, $source))
            let $_ :=
              if (fn:empty($d) and
                  count(
                    xdmp:document-properties($uri2)//
                    prop:directory) !=
                  0)
              then
                xdmp:directory-create(
                  $t,
                  default-permissions($t,$project),
                  default-collections($t,$project))
              else
                xdmp:document-insert(
                  $t,
                  $d,
                  default-permissions($t,$project),
                  default-collections($t,$project))
            return
              if ($create-options = "move" and orion-api:amped-uri-exists($uri2,false()) and
                  not(starts-with($uri2, "/orion/workspace/")))
              then xdmp:document-delete($uri2)
              else ()
          let $_ :=
            xdmp:set-response-code(
              if ($exists) then 200 else 201, "created")
          let $_ := xdmp:add-response-header("Location", $uri)
          return
          simple-file($project,$uri,document{()},$ts,(),$roles,$path,$name,false(),(),0) 
    else
      let $uri1 :=
        ml-uri(
          substring-after($body/Location/data(), "/file"),
          $project)
      let $source as node() :=
        if ($create-options = ("move", "copy"))
        then doc($uri1)
        else text { "" }
      let $_ :=
        if ($directory)
        then
          xdmp:directory-create(
            $uri, default-permissions($uri,$project), default-collections($uri,$project))
        else
          xdmp:document-insert(
            $uri,
            ensure-type($uri, $source),
            default-permissions($uri,$project), default-collections($uri,$project))
      let $_ :=
        if ($create-options = "move" and orion-api:amped-uri-exists($uri1,false()) and
            not(starts-with($uri1, "/orion/workspace/")))
        then xdmp:document-delete($uri1)
        else ()
      let $_ :=
        xdmp:set-response-code(
          if ($exists) then 200 else 201, "created")
      let $_ := xdmp:add-response-header("Location", $uri)
      return
      simple-file($project,$uri,$source,$ts,(),$roles,$path,$name,false(),(),0)
};

declare private  
function is-binary($uri as xs:string)
{
  not(
    contains(uri-content-type($uri), "text") or
    contains(uri-content-type($uri), "xml") or
    contains(uri-content-type($uri), "xsl") or
    contains(uri-content-type($uri), "xquery"))
};

declare private  
function document-length($node as node()?)
as xs:integer
{
  if (fn:empty($node))
  then 0
  else if ($node/binary())
  then xdmp:binary-size($node/binary())
  else string-length(xdmp:quote($node))
};

declare private  
function document-hash($node as node()?)
as xs:string
{
  xdmp:integer-to-hex(
    xdmp:hash64(
      if ($node/binary())
      then xs:string(xs:base64Binary($node/binary()))
      else xdmp:quote($node)))
};

declare private function default-permissions($uri as xs:string,$project as element(orion:project)) {
	xdmp:default-permissions($uri)
};

declare private function default-collections($uri as xs:string,$project as element(orion:project)) {
	xdmp:default-permissions($uri)
};

declare function orion-api:file-put-request(
  $path as xs:string,
  $xpath as xs:string?,
  $frag as xs:string?,
  $project as element(orion:project),
  $roles as xs:unsignedLong*)
{
  let $uri as xs:string := ml-uri($path, $project)
  let $directory as xs:boolean :=
    ends-with($uri, "/") or
    count(xdmp:document-properties($uri)//prop:directory) != 0
  let $parts as xs:string+ :=
    if (fn:empty(xdmp:get-request-field("parts")))
    then if ($directory) then "meta" else "body"
    else fn:tokenize(xdmp:get-request-field("parts"), "[, ]+")
  let $exists as xs:boolean := amped-uri-exists($uri, false())
  let $source as xs:string? := xdmp:get-request-field("source")
  let $ts :=
    xdmp:eval(
      "xdmp:request-timestamp()",
      (),
      <options xmlns="xdmp:eval"><transaction-mode>query</transaction-mode></options>)
  let $ifmatch as xs:string := normalize-space(xdmp:get-request-header("If-Match"))
  return
    for $part in $parts
    return
      switch ($part)
      case "body" return
        let $body as node() :=
          if (fn:empty($source))
          then
            if (is-binary($uri))
            then
              document {
                xdmp:get-request-body("binary")
              }
            else
              document {
                text { xdmp:get-request-body("text") }
              }
          else
            xdmp:http-get($source)
        let $doc := if (fn:empty($xpath)) then doc($uri) else doc($uri)/xdmp:unpath($xpath)
        let $hash := if ($ifmatch != "") then document-hash($doc) else ()
        return
          if ($ifmatch = "" or $ifmatch = $hash)
          then
            let $realdoc0 := ensure-type($uri, $body)
            let $realdoc :=
              if (uri-content-type($path) =
                  "application/x-project")
              then
                validate {
                  $realdoc0
                }
              else
                $realdoc0
            let $_ :=
              if ($uri=base-uri($project)) then
              	xdmp:spawn-function(function(){xdmp:node-replace(doc($uri), $realdoc)},<options xmlns="xdmp:eval"><database>{xdmp:server-database(xdmp:server())}</database></options>)
              else if ($exists and not(fn:empty($doc)))
              then if (fn:empty($xpath)) then
              	xdmp:node-replace($doc, $realdoc)
              else 
              	xdmp:node-replace($doc/xdmp:unpath($xpath),$realdoc/node())
              else xdmp:document-insert($uri, $realdoc,default-permissions($uri,$project),default-collections($uri,$project))
            let $nhash := if (fn:empty($xpath)) then document-hash($realdoc) else document-hash($realdoc/node())
            let $_ := xdmp:add-response-header("ETag", $nhash)
            let $_ := xdmp:add-response-header("x-uri", $uri)
            return
            simple-file($project,$uri,$realdoc,$ts,$nhash,$roles,$path,tokenize($uri,'/')[last()],false(),(),0)
          else
            xdmp:set-response-code(
              414,
              "document " || $uri || " changed " || $ifmatch || "!=" || $hash)
      case "meta" return
        if ($exists)
        then ()
        else xdmp:set-response-code(404, $uri || " not found")
      default return
        fn:error(
          xs:QName("orion-api:file-put-request"),
          "invalid part " || $part)
};

declare function orion-api:file-delete-request(
  $path as xs:string,
  $project as element(orion:project))
{
  let $uri := ml-uri($path, $project)
  return
(:    if (starts-with($uri, "/orion/workspace"))
    then
      xdmp:set-response-code(
        403, "cannot delete project file")
    else :)
      let $directory as xs:boolean :=
        ends-with($uri, "/") or
        count(xdmp:document-properties($uri)//prop:directory) !=
        0
      let $ifmatch as xs:string := normalize-space(xdmp:get-request-header("If-Match"))
      let $doc := doc($uri)
      return
        if (not($directory) and fn:empty($doc))
        then xdmp:set-response-code(205, "Ok (not found)")
        else
          let $hash := if ($ifmatch != "") then document-hash($doc) else ()
          return
            if ($ifmatch = "" or $ifmatch = $hash)
            then
              let $count :=
                if ($directory)
                then
                  let $sources :=
                    cts:uri-match(
                      concat(
                        $uri,
                        if (ends-with($uri, "/")) then () else "/",
                        "*"))
                  return
                    count(
                      for $source in $sources
                      return (1, xdmp:document-delete($source)))
                else
                  0
              let $count2 :=
                if (fn:empty($doc))
                then 0
                else (1, xdmp:document-delete($uri))
              return
                xdmp:set-response-code(
                  205, "Deleted " || $count + $count2)
            else
              xdmp:set-response-code(
                414,
                "document " || $uri || " changed " || $ifmatch || "!=" || $hash)
};

declare function orion-api:update-get-request(
  $path as xs:string,
  $project as element(orion:project))
{
  let $uris :=
    cts:uris(
      (),
      (),
      cts:directory-query(
        $project/orion:content-location, "infinity"))
  let $dirs :=
    fn:distinct-values(
      for $uri in
        $uris[not(ends-with(., "/"))][not(starts-with(., "/orion/workspace/"))]
      let $n := fn:tokenize($uri, "/")[1 to last() - 1]
      return
        for $nn at $i in $n
        return string-join($n[1 to $i], "/") ! concat(., "/"))
  let $newdirs := $dirs[not(orion-api:amped-uri-exists(., false()))]
  let $count :=
    sum(
      for $dir in $newdirs
      return
        try {
          xdmp:directory-create(
            $dir, default-permissions($dir,$project),default-collections($dir,$project)),
          1
        } catch ($ex) {
          xdmp:log($ex)
        })
  return $count || " directories created"
};

declare private  
function map-with(
  $map as map:map,
  $key-name as xs:string,
  $value as item())
as map:map
{
  typeswitch ($value)
   case json:array return
     if (json:array-size($value) gt 0)
     then map:put($map, $key-name, $value)
     else ()
   default return
     if (exists($value))
     then map:put($map, $key-name, $value)
     else (),
  $map
};

declare private  
function mark($node as node(), $find as node())
as node()*
{
  let $m := if ($node is $find) then text { "&#x058d;" } else ()
  return
    typeswitch ($node)
     case element() return
       element { node-name($node) } {
         ($node/@*) ! mark(., $find),
         $m,
         ($node/node()) ! mark(., $find)
       }
     case document-node() return
       document {
         ($node/node()) ! mark(., $find)
       }
     case attribute() return
       attribute { node-name($node) } { $m, $node/string(.), $m }
     default return ($m, $node)
};

declare function node-offset($node as node(), $find as node(),$project as element(orion:project))
as xs:int*
{
  let $x := mark($node, $find)
  let $s := format-document($x,$project)
  let $start := substring-before($s, "&#x058d;")
  let $isatr as xs:boolean := ends-with($start, "=&quot;")
  let $line :=
    string-length($start) -
    string-length(translate($start, "&#10;", "")) +
    1
  let $linet := tokenize($s, "&#10;")[$line]
  let $start2 :=
    string-length(
      substring-before(
        if ($isatr)
        then $linet
        else translate($linet, "<", "&#x058d;"),
        "&#x058d;"))
  let $end2 :=
    if ($isatr)
    then
      $start2 +
      string-length(
        substring-before(
          substring(
            $linet, $start2 + 2, string-length($linet)),
          "&#x058d;"))
    else
      string-length($linet)
  return ($line, $start2, $end2)
};

declare function node-offset-xpath($node as node(), $xpath as xs:string,$project as element(orion:project))
as xs:int*
{
  node-offset(
    $node,
    $node/xdmp:value(
        if (contains($xpath, ")"))
        then substring-after($xpath, ")")
        else $xpath),$project)
};
