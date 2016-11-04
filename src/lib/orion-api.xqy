xquery version "1.0-ml";
module namespace orion-api="http://marklogic.com/lib/xquery/orion-api"; 
declare namespace prop="http://marklogic.com/xdmp/property";
declare namespace error="http://marklogic.com/xdmp/error";
declare namespace tidy="xdmp:tidy";
declare option xdmp:mapping "false";

declare function orion-api:main() {
	let $api:=xdmp:get-request-field('api')
	let $path:=xdmp:get-request-field('path')
	let $method:=xdmp:get-request-method()
	return switch($method)
	case 'GET' return
		switch($api)
		case 'file' return orion-api:file-get-request($path)
		case 'validate' return orion-api:validate-get-request($path)
		case 'workspace' return orion-api:workspace-get-request($path)
		case 'filesearch' return orion-api:filesearch-get-request($path)
		default return fn:error(xs:QName('orion-api:error'),'unsupported api '||$api)
	case 'PUT' return
		switch($api)
		case 'file' return orion-api:file-put-request($path)
		case 'workspace' return orion-api:workspace-put-request($path)
		default return fn:error(xs:QName('orion-api:error'),'unsupported api '||$api)
	case 'POST' return
		switch($api)
		case 'file' return orion-api:file-post-request($path)
		case 'workspace' return orion-api:workspace-post-request($path)
		default return fn:error(xs:QName('orion-api:error'),'unsupported api '||$api)
	case 'DELETE' return
		switch($api)
		case 'file' return orion-api:file-delete-request($path)
		case 'workspace' return orion-api:workspace-delete-request($path)
		default return fn:error(xs:QName('orion-api:error'),'unsupported api '||$api)
	default return fn:error(xs:QName('orion-api:error'),'unsupported method '||$method)
};

declare private function ml-uri($path as xs:string) as xs:string {
	if (ends-with($path,'/.project.xml') and count(tokenize($path,'/'))=4) then
		let $parents:=tokenize($path,'/')
		return concat('/orion/workspace/',$parents[2],'/project/',$parents[3])
	else
	concat('/orion/mlfile',xdmp:url-decode($path))
};

declare private function orion-uri($path as xs:string) as xs:string {
	concat('/orion/file',xdmp:url-decode($path))
};

declare private function ml-path($uri as xs:string) as xs:string {
	if (starts-with($uri,'/orion/workspace/')) then
		let $parents:=fn:tokenize(substring-after($uri,'/orion/workspace/'),'/')
		return concat('/',$parents[1],'/',$parents[3],'/.project.xml')
	else
	substring-after($uri,'/orion/mlfile')
};

declare private function uri-content-type($uri as xs:string) as xs:string {
	let $r:=xdmp:uri-content-type($uri)
	return if ($r='application/vnd.marklogic-xdmp') then 'application/xquery' else $r
};

declare private function orion-path($uri as xs:string) as xs:string {
	substring-after($uri,'/orion/file')
};

declare private function is-file($uri as xs:string?) as xs:boolean {
	contains($uri,'/orion/file')
};

declare private function ensure-type($uri as xs:string,$node as node()?) as node()? {
	if (fn:empty($node)) then ()
	else if (($node/binary() or $node/text()) and (contains(uri-content-type($uri),'xml') or contains(uri-content-type($uri),'json'))) then try{document{xdmp:unquote(xdmp:quote($node))}} catch ($ex){$node}
	else if ($node/binary() and contains(uri-content-type($uri),'text')) then try{document{text{xdmp:quote($node)}}} catch ($ex){$node}
	else if (starts-with($uri,'/orion/workspace/')) then try{document{xdmp:unquote(xdmp:quote($node))}} catch ($ex){$node}
	else $node
};

declare function orion-api:validate-get-request($path as xs:string) as object-node() {
	let $uri:=ml-uri($path)
	let $type:=uri-content-type($uri)
	return switch($type)
	case 'text/html' return object-node {
		"uri":$uri,
		"problems":array-node {
			xdmp:tidy(xdmp:quote(doc($uri)),<options xmlns="xdmp:tidy">
		<doctype>transitional</doctype></options>)[1]/(tidy:warning|tidy:error)! object-node {
				"description":./data(),
				"severity":local-name(.),
				"line":./@tidy:line/xs:int(.),
				"start":./@tidy:column/xs:int(.),
				"end":./@tidy:column/xs:int(.)+1
			}
		}
	}
	case 'application/xquery' return object-node {
		"uri":$uri,
		"problems":array-node {
			try{let $_:=xdmp:pretty-print(xdmp:quote(doc($uri))) return ()}catch($ex){$ex!object-node { 
					"description":concat(./error:message/data(),' ,',./error:data/error:datum[1]/data()),
					"line":./error:stack/error:frame[1]/error:line/xs:int(.),
					"severity":"warning",
					"start":./error:stack/error:frame[1]/error:column/xs:int(.),
					"end":./error:stack/error:frame[1]/error:column/xs:int(.)+1
				}
			}
		}
	}
	default return object-node {
		"uri":$uri,
		"problems":array-node {
			try{
				let $d0:=doc($uri)
				let $d:=if ($d0/element()) then $d0 else xdmp:unquote(xdmp:quote($d0)) 
				return if (xdmp:describe(sc:type($d))!='(any(lax,!())*)|#PCDATA') then xdmp:validate($d,'strict')/error:error!object-node {
					"description":concat(./error:message/data(),' ,',./error:data/error:datum[last()-1]/data()),
					"line":1,
					"severity":"error",
					"start":0,
					"end":1					
				} else ()
			} catch($ex){$ex!object-node { 
					"description":concat(./error:message/data(),' ,',./error:data/error:datum[1]/data()),
					"line":./error:data/error:datum[3]/xs:int(.),
					"severity":"warning",
					"start":0,
					"end":1
				}
			}
		}
	}
};

declare function orion-api:filesearch-get-request($path as xs:string) as object-node() {
	let $sort as xs:string:=xdmp:get-request-field('sort')
	let $rows as xs:integer:=xs:integer(xdmp:get-request-field('rows'))
	let $start as xs:integer:=xs:integer(xdmp:get-request-field('start'))
	let $q as xs:string:=xdmp:get-request-field('q')
	let $words:=fn:replace($q, '^(("([^"]+)")|([^ ]+))[ ].*$', "$3$4")
	let $names:=fn:tokenize(fn:replace($q, '.+ Name:([^ ]+).*', "$1"),'/')
	let $location:=fn:replace($q, '.+ Location:([^ ]+).*', "$1")
	let $case-sensitive as xs:boolean:=fn:replace($q, '.+ CaseSensitive:([^ ]+).*', "$1")='true'
	let $whole-word as xs:boolean:=fn:replace($q, '.+ WholeWord:([^ ]+).*', "$1")='true'
	let $regex as xs:boolean:=fn:replace($q, '.+ RegEx:([^ ]+).*', "$1")='true'
	let $uris0:=cts:uri-match(ml-uri(orion-path($location)))
	let $uris:=if ($names) then for $uri in $uris0 
		let $n:=fn:tokenize($uri,'/')[last()]
		let $m:=for $name in $names 
			let $p:=fn:replace($name,'[.]','[.]')!fn:replace(.,'[*]','.*')
			return fn:matches($n,concat("^",$p,"$"),"i")
		return if ($m) then $uri else ()
	else $uris0
	let $location-query:=cts:document-query($uris)
	let $word-queries:=for $word in fn:tokenize($words,'[^\w]+')
		let $pat:=if ($whole-word) then $word else concat($word,'*') 
		return cts:word-query($pat,(if ($case-sensitive) then "case-sensitive" else "case-insensitive"))
	let $result:=cts:search(doc(),cts:and-query(($word-queries,$location-query)))[($start+1) to ($start+$rows)]!base-uri(.)
	return object-node {
		"response": object-node {
			"docs":array-node {
				for $r in $result return orion-api:file($r,0,false())
			},
			"numFound":number-node{count($result)},
			"start":$start
		},
		"responseHeader": object-node {
			"params":object-node {
		      "fl": "Name,NameLower,Length,Directory,LastModified,Location,Path,RegEx,CaseSensitive,WholeWord",
		      "fq": array-node {
		        concat("Location:",$location),
		        concat("UserName:",xdmp:get-current-user())
		      },
		      "rows": $rows,
		      "sort": $sort,
		      "start": $start,
		      "wt": "json"				
			},
			"status":0
		}
	}
};

declare function orion-api:workspace-get-request($path as xs:string) as object-node()? {
	if ($path='') then
		let $uris:=cts:uris((),(),cts:directory-query('/orion/workspace/','1'))
		let $ts:=fn:max($uris!xdmp:document-timestamp(.))
		let $etag:=xdmp:get-request-header('If-None-Match')
		return if ($etag and xdmp:hex-to-integer($etag)=$ts) then xdmp:set-response-code(304,'not modified')
		else
		let $_:=xdmp:set-response-content-type("application/json")
		let $r:=object-node {
			"UserName":xdmp:get-current-user(),
			"Id":string(xdmp:get-current-userid()),
			"Workspaces": array-node {
			for $x in $uris
			let $d:=document($x)
			return object-node {
					"Id":xdmp:integer-to-hex(xdmp:hash64($x)),
					"Location":$x,
					"LastModified":number-node{xdmp:document-timestamp($x) idiv 10000},
					"Name": $d/Name,
					"Owner":$d/Owner
				}
			}
		}
		let $_:=xdmp:add-response-header('ETag',xdmp:integer-to-hex($ts))
		return $r
	else 
		let $w:=document(concat('/orion/workspace',$path))
		return if (fn:empty($w)) then xdmp:set-response-code(404,"not found")
		else
		let $_:=xdmp:set-response-content-type("application/json")
		let $ts:=xdmp:document-timestamp(concat('/orion/workspace',$path))
		let $_:=xdmp:add-response-header('ETag',xdmp:integer-to-hex($ts))
		let $projects:=xdmp:directory(concat('/orion/workspace',$path,'/project/'),'1')
		return object-node {
			"Id":substring($path,2),
			"Directory": true(),
			"ChildrenLocation":concat("/orion/workspace",$path),
			"Location":concat("/orion/workspace",$path),
			"Name":$w/Name,
			"Projects": array-node {
				for $project in $projects/project return object-node {
					"Id" : $project/@id/data(),
					"Workspace":$project/workspace/data(),
					"Location": $project/location/data(),
					"Name" : $project/name/data(),
					"ContentLocation":$project/content-location/data() 
				}
			},
			"Children": array-node {
				for $project in $projects/project 
					return object-node {
						"Directory": true(),
						"Id":$project/@id/data(),
						"Name" : $project/name/data(),
						"Location":concat(orion-uri($path),'/',$project/@id,'/'),
						"ChildrenLocation":concat(orion-uri($path),'/',$project/@id,'/?depth=1'),
						"ExportLocation":export-location(concat(orion-uri($path),'/',$project/@id)),
						"ImportLocation":import-location(concat(orion-uri($path),'/',$project/@id)),
      					"LocalTimeStamp": xdmp:document-timestamp(base-uri($project)) idiv 10000
					}
			}

		}
};

declare function orion-api:workspace-put-request($path as xs:string) {
	()
};

declare function orion-api:amped-uri-exists($uri as xs:string,$dir as xs:boolean) as xs:boolean {
	let $uris:=if ($dir) then ($uri,concat($uri,if (ends-with($uri,'/')) then () else '/','*')) else $uri
	return not(empty($uris!cts:uri-match(.)))
};

declare private function project-xml($id as xs:string,$name as xs:string,$ws as xs:string,$location as xs:string,$content-location as xs:string) as element() {
	<project id="{$id}">
		<name>{$name}</name>
		<workspace>{$ws}</workspace>
		<location>{$location}</location>
		<content-location>{$content-location}</content-location>
		<creator>{xdmp:get-current-user()}</creator>
		<created>{fn:current-dateTime()}</created>
	</project>
};

declare function orion-api:workspace-post-request($path as xs:string) as object-node() {
	let $slug as xs:string?:=xdmp:get-request-header('Slug')
	let $create-options:=xdmp:get-request-header('X-Create-Options')!fn:tokenize(.,'[ ,]+')
	let $body:=if (fn:empty(xdmp:get-request-body("text"))) then () else xdmp:unquote(xdmp:get-request-body("text"))
	let $name as xs:string:=if (fn:empty($slug)) then $body/Name/data() else $slug
	let $ts:=xdmp:eval("xdmp:request-timestamp()",(),<options xmlns="xdmp:eval"><transaction-mode>query</transaction-mode></options>)
	let $_:=xdmp:add-response-header('ETag',xdmp:integer-to-hex($ts))
	return if ($path='') then
		let $id:=(for $i in 1 to 1000000 where orion-api:amped-uri-exists('/orion/workspace/E'||$i,false())=false() return concat('E',$i))[1]
		let $_:=xdmp:document-insert(
	       "/orion/workspace/"||$id, object-node{"Id" : $id,"Name" : $name, "Owner" : xdmp:get-current-user() },
	       xdmp:default-permissions(),
	       "/orion/workspaces/")
		return object-node {
			"Id" : $id,"Name" : $slug,
			"Location":concat("/orion/workspace/"||$id),
			"Projects":array-node{},
			"Children":array-node{}
		}
	else 
		let $create:=$body/CreateIfDoesntExist/data()
		let $id as xs:string:=if ($create-options='move' and $body/Location) then tokenize($body/Location/data(),'/')[last()]
			else
			(for $i in 1 to 1000000 where orion-api:amped-uri-exists(concat('/orion/workspace',$path,'/project/A',$i),false())=false() 
			and orion-api:amped-uri-exists(concat(ml-uri($path),'/A',$i),true())=false() return concat('A',$i))[1]
		let $location as xs:string:=if (fn:empty($body/ContentLocation/data())) then concat(orion-uri($path),'/',$id,'/')
			else $body/ContentLocation/data()
		let $ws:=substring-after($path,'/')
		let $d:=object-node{"Id" : $id,"Workspace":$ws,"Location": concat('/orion/workspace',$path,'/project/',$id), "Name" : $name, "Owner" : xdmp:get-current-user(),"ContentLocation":$location }
		let $_:=xdmp:document-insert(
	       concat('/orion/workspace',$path,'/project/',$id), project-xml($id,$name,$ws, concat('/orion/workspace',$path,'/project/',$id),$location), xdmp:default-permissions())
		let $_:=try{xdmp:directory-create(ml-uri(orion-path($location)),xdmp:default-permissions())} catch ($ex) {xdmp:log($ex)}
		return $d
};

declare function orion-api:workspace-delete-request($path as xs:string) {
	let $project:=doc(concat('/orion/workspace',$path))
	let $dir:=if ($project/Id) then ml-uri(concat('/',$project/Workspace/data(),'/',$project/Id/data(),'/')) else ()
	let $_:=if (orion-api:amped-uri-exists(concat('/orion/workspace',$path),false())) then xdmp:document-delete(concat('/orion/workspace',$path)) else ()
	let $_:=if ($dir and orion-api:amped-uri-exists($dir,false())) then xdmp:document-delete($dir) else ()
	return ''
};

declare private function orion-api:children($uri as xs:string,$depth as xs:int) as json:object* {
	let $uris:=cts:uris((),("any"),cts:directory-query($uri,if ($depth=1) then '1' else 'infinity'))[count(tokenize(substring-after(.,$uri),'/')[.!='']) le $depth]
	return $uris!orion-api:file(.,$depth - 1,false())
};

declare private function orion-api:file($uri as xs:string,$depth as xs:int,$include-parents as xs:boolean) as json:object {
	let $ts as xs:integer?:=if (xdmp:document-properties($uri)//prop:last-modified) then (xdmp:document-properties($uri)//prop:last-modified!xs:dateTime(.) - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration("PT0.001S") else xdmp:document-timestamp($uri) idiv 10000
	return orion-api:file($uri,$depth,$include-parents,$ts,document-length(doc($uri)),document-hash(doc($uri)))
};

declare private function import-location($uri as xs:string) as xs:string {
	concat("/xfer/import",substring-after($uri,'/file'))
};

declare private function export-location($uri as xs:string) as xs:string {
	concat("/xfer/export",substring-after(if (ends-with($uri,'/')) then substring($uri,1,string-length($uri)-1) else $uri,'/file'))
};

declare function ser($key as xs:string?, $node as item(),$indent as xs:string) as xs:string* {
  concat(
  if ($key) then concat($indent,'"',$key,'":') else $indent,
  typeswitch($node)
  case object-node() return concat('{&#10;',string-join($node/node()!ser(name(.),.,$indent||' '),',&#10;'),"&#10;",$indent,"}")
  case array-node() return concat("[",$indent,"&#10;",string-join($node/node()!ser((),.,$indent||'  '),',&#10;'),'&#10; ',$indent,"]")
  case text() return concat('"',replace($node/data(),'"','\\"'),'"')
  case null-node() return 'null'
  case number-node() return $node/data()
  case boolean-node() return $node/data()
  default 
  return if ($node instance of xs:string) then concat('"',replace($node/data(),'"','\\"'),'"') else string($node))
};

declare private function format-document($node as node()) as item() {
	if ($node/element()) then xdmp:quote($node,<options xmlns="xdmp:quote"><indent-tabs>yes</indent-tabs><default-attributes>yes</default-attributes><omit-xml-declaration>yes</omit-xml-declaration><indent>yes</indent><indent-untyped>yes</indent-untyped></options>)
	else if ($node/object-node()) then ser((),$node/object-node(),'')
	else $node
};

declare private function orion-api:file($uri as xs:string,$depth as xs:int,$include-parents as xs:boolean,$ts as xs:integer?,$size as xs:integer,$etag as xs:string?) as json:object {
	let $path as xs:string:=ml-path($uri)
	let $directory as xs:boolean:=ends-with($uri,'/') or count(xdmp:document-properties($uri)//prop:directory)!=0
	let $parents as xs:string+:=tokenize($path,'/')[.!=''][1 to last()-1]
	let $name as xs:string:=tokenize($path,'/')[.!=''][last()]
	let $project:=if (($directory and count($parents)=1) or ($name='.project.xml' and count($parents)=2)) then 
		let $puri:=concat('/orion/workspace/',$parents[1],'/project/',if (count($parents)=1) then $name else $parents[2])
		let $pdoc:=doc($puri)
		return object-node {
		"Attributes":object-node {
		    "Executable": $directory,
		    "Immutable": false(),
		    "ReadOnly": false(),
		    "SymLink": false()
		 },
		"Directory":false(),
		"ETag":document-hash($pdoc),
		"Length":document-length($pdoc),
		"Name":".project.xml",
		"Location":if ($directory) then concat(orion-uri(ml-path($uri)),'.project.xml') else orion-uri(ml-path($uri))
	} else ()
	return if (count($parents)=2 and $name='.project.xml') then $project
	else json:object() 
		!map-with(.,'Attributes', object-node {
		    "Executable": $directory,
		    "Immutable": false(),
		    "ReadOnly": false(),
		    "SymLink": false()})
		!map-with(.,"Directory", $directory)
		!map-with(.,"Length", $size)
		!(if ($ts) then map-with(.,"LocalTimeStamp", number-node{$ts}) else .)
		!map-with(.,"Location", orion-uri($path))
		!map-with(.,"Name", $name)
		!(if ($etag) then map-with(.,"ETag",$etag) else .)
		!(if ($directory) then map-with(.,"ImportLocation", import-location($uri))!map-with(.,"ExportLocation", export-location($uri)) else .)
		!(if ($directory and $depth gt 0) then map-with(.,'Children',array-node{orion-api:children($uri,$depth),$project})  else .)
		!(if ($include-parents) then map-with(.,"Parents", array-node {
		  	for $parent at $pos in $parents where $pos gt 1 order by $pos descending return object-node {
		    	"ChildrenLocation": concat(orion-uri(concat('/',string-join($parents[1 to $pos],'/'))),"/?depth=1"),
		    	"Location": concat(orion-uri(concat('/',string-join($parents[1 to $pos],'/'))),'/'),
		    	"Name": $parent
			} 
		  }) else .)
		!map-with(.,if ($directory) then "ChildrenLocation" else "FileEncoding",if ($directory) then concat(orion-uri($path),"?depth=1") else array-node {"UTF-8"})
};

declare function orion-api:file-get-request($path as xs:string) {
	let $uri:=ml-uri($path)
	let $depth as xs:int:=if (fn:empty(xdmp:get-request-field('depth'))) then 0 else xs:int(xdmp:get-request-field('depth'))
	let $directory as xs:boolean:=ends-with($uri,'/') or count(xdmp:document-properties($uri)//prop:directory)!=0
	let $parts as xs:string+:=if (fn:empty(xdmp:get-request-field('parts'))) then if ($directory) then 'meta' else 'body' else fn:tokenize(xdmp:get-request-field('parts'),'[, ]+')
	let $parents:=tokenize($path,'/')[.!=''][1 to last()-1]
	return if (orion-api:amped-uri-exists($uri,true())) then
		let $result:=for $part in $parts
		return switch($part)
		case 'meta' return orion-api:file($uri,$depth,true())
		case 'body' return 
			let $d:=doc($uri)
			let $hash:=document-hash($d)
			let $_:=xdmp:add-response-header('ETag',$hash)
			let $_:=if ($d/text()) then xdmp:add-response-header('Accept-Patch','application/json-patch; charset=UTF-8') else ()
			return if (fn:empty($d)) then text{''} else $d
		default return fn:error(xs:QName('orion-api:file-get-request'),'unsupported part '||$part)
		return if (fn:count($parts)=1) then
			let $_:=xdmp:set-response-content-type(if ($parts='meta') then 'application/json' else uri-content-type($path))
			return if ($result instance of node()) then format-document($result) else text{xdmp:quote($result)}
		else
			xdmp:multipart-encode('boundary10382384-2840',<manifest>{for $part in $parts return <part><headers><Content-Type>{if ($part='meta') then 'application/json' else uri-content-type($path)}</Content-Type></headers></part>}</manifest>,
				for $r in $result return if ($r instance of node()) then format-document($r) else text{xdmp:quote($r)}
			)
	else if (fn:tokenize($path,'/')[last()]=('.tern-project','.eslintrc.js','.eslintrc.json','package.json','.eslintrc') and $parts='body' and count($parts)=1) then object-node{}
	else 
		let $_:=xdmp:set-response-code(404,$uri||' not found')
		return ()
};

declare private function orion-api:patch($d as xs:string,$start as xs:integer,$end as xs:integer,$s as xs:string) as xs:string {
	concat(substring($d,1,$start),$s,substring($d,$end+1,string-length($d)))
};

declare function orion-api:file-post-request($path as xs:string) {
	let $slug as xs:string?:=xdmp:get-request-header('Slug')
	let $create-options:=xdmp:get-request-header('X-Create-Options')!fn:tokenize(.,'[ ,]+')
	let $method-override:=xdmp:get-request-header('X-HTTP-Method-Override')!fn:tokenize(.,'[ ,]+')
	let $body:=if (fn:empty(xdmp:get-request-body("text"))) then () else xdmp:unquote(xdmp:get-request-body("text"))
	let $name as xs:string?:=if (fn:empty($slug)) then $body/Name/data() else $slug
	let $ts:=xdmp:eval("xdmp:request-timestamp()",(),<options xmlns="xdmp:eval"><transaction-mode>query</transaction-mode></options>) idiv 10000
	let $directory:=if ($body/Directory/data()) then xs:boolean($body/Directory/data()) else if ($body/Location/data()) then ends-with($body/Location/data(),'/') else false()
	let $_:=xdmp:add-response-header('ETag',xdmp:integer-to-hex($ts))
	let $parents:=tokenize($path,'/')[.!='']
	let $uri:=ml-uri(concat($path,if (ends-with($path,'/') or fn:empty($name)) then () else '/',$name,if ($directory) then '/' else ()))
	let $exists as xs:boolean:=amped-uri-exists($uri,false())
	return if ($create-options='no-overwrite' and $exists) then 
		xdmp:set-response-code(412,'file exists')
	else if ($method-override='PATCH') then
		let $ifmatch as xs:string:=normalize-space(xdmp:get-request-header('If-Match'))
		let $doc:=doc($uri)
		let $hash:=if ($ifmatch!='') then document-hash($doc) else ()
		return if ($ifmatch='' or $ifmatch=$hash) then 
			let $ndoc0:=document{text{fn:fold-left(function($a,$diff){orion-api:patch($a,$diff/start!xs:integer(.),$diff/end!xs:integer(.),$diff/text/data())},xdmp:quote($doc),$body/diff)}}
			let $ndoc:=ensure-type($uri,$ndoc0)
			let $_:=xdmp:node-replace($doc,$ndoc)
			return orion-api:file($uri,0,false(),$ts,document-length($ndoc),document-hash($ndoc))
		else
			xdmp:set-response-code(414,"document "||$uri||" changed "||$ifmatch||"!="||$hash)
	else
	if ($create-options=('move','copy') and is-file($body/Location/data()) and ends-with($body/Location/data(),'/')) then
		let $source:=ml-uri(substring-after($body/Location/data(),'/file'))
		let $sources:=cts:uri-match(concat($source,'*'))
		return if (fn:empty($sources)) then xdmp:set-response-code(404,'not found '||$source)
		else
		let $_:=for $uri2 in $sources 
			let $d:=doc($uri2)
			let $t:=concat($uri,substring-after($uri2,$source))
			let $_:=if (fn:empty($d) and count(xdmp:document-properties($uri2)//prop:directory)!=0) 
				then xdmp:directory-create($t,xdmp:default-permissions(),('/orion/files/'))
				else xdmp:document-insert($t,$d,xdmp:default-permissions(),('/orion/files/'))
			return if ($create-options='move' and not(starts-with($uri2,'/orion/workspace/'))) then xdmp:document-delete($uri2) else ()
		let $_:=xdmp:set-response-code(if ($exists) then 200 else 201,'created')
		let $_:=xdmp:add-response-header("Location",$uri)
		return orion-api:file($uri,0,false(),$ts,0,())		
	else
		let $uri1:=ml-uri(substring-after($body/Location/data(),'/file'))
		let $source as node():=if ($create-options=('move','copy') and is-file($uri1)) 
			then doc($uri1)
			else text{''}
		let $_:=if ($directory) then xdmp:directory-create($uri,xdmp:default-permissions(),('/orion/files/'))
		else xdmp:document-insert($uri,ensure-type($uri,$source),xdmp:default-permissions(),('/orion/files/'))
		let $_:=if ($create-options='move' and is-file($uri1) and not(starts-with($uri1,'/orion/workspace/')))
			then xdmp:document-delete($uri1)
			else ()
		let $_:=xdmp:set-response-code(if ($exists) then 200 else 201,'created')
		let $_:=xdmp:add-response-header("Location",$uri)
		return orion-api:file($uri,0,false(),$ts,document-length($source),document-hash($source))
};

declare private function is-binary($uri as xs:string) {
	not(contains(uri-content-type($uri),'text') or contains(uri-content-type($uri),'xml') or contains(uri-content-type($uri),'xquery'))
};

declare private function document-length($node as node()?) as xs:integer {
	if (fn:empty($node)) then 0 else if ($node/binary()) then xdmp:binary-size($node/binary()) else string-length(xdmp:quote($node))
};

declare private function document-hash($node as node()?) as xs:string {
	xdmp:integer-to-hex(xdmp:hash64(if ($node/binary()) then xs:string(xs:base64Binary($node/binary())) else xdmp:quote($node)))
};

declare function orion-api:file-put-request($path as xs:string) {
	let $uri:=ml-uri($path)
	let $directory as xs:boolean:=ends-with($uri,'/') or count(xdmp:document-properties($uri)//prop:directory)!=0
	let $parts as xs:string+:=if (fn:empty(xdmp:get-request-field('parts'))) then if ($directory) then 'meta' else 'body' else fn:tokenize(xdmp:get-request-field('parts'),'[, ]+')
	let $exists as xs:boolean:=amped-uri-exists($uri,false())
	let $source as xs:string?:=xdmp:get-request-field('source')
	let $ts:=xdmp:eval("xdmp:request-timestamp()",(),<options xmlns="xdmp:eval"><transaction-mode>query</transaction-mode></options>)
	let $ifmatch as xs:string:=normalize-space(xdmp:get-request-header('If-Match'))
	return 
		for $part in $parts
		return switch($part)
		case 'body' return
			let $body as node():=if (fn:empty($source)) then 
				if (is-binary($uri)) then document{xdmp:get-request-body('binary')}
				else
				document{text{xdmp:get-request-body('text')}} else xdmp:http-get($source) 
			let $doc:=doc($uri)
			let $hash:=if ($ifmatch!='') then document-hash($doc) else ()
			return if ($ifmatch='' or $ifmatch=$hash) then 
				let $realdoc:=ensure-type($uri,$body)
				let $_:=if ($exists) then xdmp:node-replace($doc,$realdoc)
				else xdmp:document-insert($uri,$realdoc)
				return orion-api:file($uri,1,false(),$ts,document-length($realdoc),document-hash($realdoc))
			else
				xdmp:set-response-code(414,"document "||$uri||" changed "||$ifmatch||"!="||$hash)
		case 'meta' return if ($exists) then () else xdmp:set-response-code(404,$uri||' not found')
		default return fn:error(xs:QName('orion-api:file-put-request'),'invalid part '||$part)
};

declare function orion-api:file-delete-request($path as xs:string) {
	let $uri:=ml-uri($path)
	return if (starts-with($uri,'/orion/workspace')) then
		xdmp:set-response-code(403,"cannot delete project file")
	else
	let $directory as xs:boolean:=ends-with($uri,'/') or count(xdmp:document-properties($uri)//prop:directory)!=0
	let $ifmatch as xs:string:=normalize-space(xdmp:get-request-header('If-Match'))
	let $doc:=doc($uri)
	return if (not($directory) and fn:empty($doc)) then xdmp:set-response-code(205,'Ok (not found)')
	else
	let $hash:=if ($ifmatch!='') then document-hash($doc) else ()
	return if ($ifmatch='' or $ifmatch=$hash) then 
		let $count:=if ($directory) then
			let $sources:=cts:uri-match(concat($uri,if (ends-with($uri,'/')) then () else '/','*'))

			return count(for $source in $sources return (1,xdmp:document-delete($source)))
		else 0
		let $count2:=if (fn:empty($doc)) then 0 else (1,xdmp:document-delete($uri))
		return xdmp:set-response-code(205,'Deleted '||($count +$count2))
	else
		xdmp:set-response-code(414,"document "||$uri||" changed "||$ifmatch||"!="||$hash)
};


declare private function map-with(
    $map as map:map,
    $key-name as xs:string,
    $value as item()
) as map:map
{
    typeswitch($value)
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

