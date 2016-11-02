xquery version "1.0-ml";
module namespace orion-api="http://marklogic.com/lib/xquery/orion-api"; 
declare namespace prop="http://marklogic.com/xdmp/property";

declare function orion-api:main() {
	let $api:=xdmp:get-request-field('api')
	let $path:=xdmp:get-request-field('path')
	let $method:=xdmp:get-request-method()
	return switch($method)
	case 'GET' return
		switch($api)
		case 'file' return orion-api:file-get-request($path)
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
	concat('/orion/mlfile',xdmp:url-decode($path))
};

declare private function orion-uri($path as xs:string) as xs:string {
	concat('/orion/file',xdmp:url-decode($path))
};

declare private function ml-path($uri as xs:string) as xs:string {
	substring-after($uri,'/orion/mlfile')
};

declare private function orion-path($uri as xs:string) as xs:string {
	substring-after($uri,'/orion/file')
};

declare private function is-file($uri as xs:string?) as xs:boolean {
	contains($uri,'/orion/file')
};

declare private function ensure-type($uri as xs:string,$node as node()?) as node()? {
	if (fn:empty($node)) then ()
	else if (($node/binary() or $node/text()) and (contains(xdmp:uri-content-type($uri),'xml') or contains(xdmp:uri-content-type($uri),'json'))) then try{document{xdmp:unquote(xdmp:quote($node))}} catch ($ex){$node}
	else if ($node/binary() and contains(xdmp:uri-content-type($uri),'text')) then try{document{text{xdmp:quote($node)}}} catch ($ex){$node}
	else $node
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
				for $project in $projects return $project
			},
			"Children": array-node {
				for $project in $projects 
					return object-node {
						"Directory": true(),
						"Id":$project/Id,
						"Name":$project/Name,
						"Location":concat(orion-uri($path),'/',$project/Id/data(),'/'),
						"ChildrenLocation":concat(orion-uri($path),'/',$project/Id/data(),'/?depth=1'),
						"ExportLocation":export-location(concat(orion-uri($path),'/',$project/Id/data())),
						"ImportLocation":import-location(concat(orion-uri($path),'/',$project/Id/data())),
      					"LocalTimeStamp": xdmp:document-timestamp(base-uri($project)) idiv 10000
					}
			}

		}
};

declare function orion-api:workspace-put-request($path as xs:string) {
	()
};

declare function orion-api:amped-uri-exists($uri as xs:string,$dir as xs:boolean) as xs:boolean {
	not(empty(cts:uri-match(if ($dir) then ($uri,concat($uri,if (ends-with($uri,'/')) then () else '/','*')) else $uri)))
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
	       concat('/orion/workspace',$path,'/project/',$id), $d, xdmp:default-permissions(),"/orion/workspaces/")
		let $_:=xdmp:directory-create(ml-uri(orion-path($location)),xdmp:default-permissions(),('/orion/files/','/orion/projects/'))
		return $d
};

declare function orion-api:workspace-delete-request($path as xs:string) {
	let $project:=doc(concat('/orion/workspace',$path))
	let $dir:=if ($project/Id) then ml-uri(concat('/',$project/Workspace/data(),'/',$project/Id/data(),'/')) else ()
	let $_:=if (orion-api:amped-uri-exists(concat('/orion/workspace',$path),false())) then xdmp:document-delete(concat('/orion/workspace',$path)) else ()
	let $_:=if ($dir and orion-api:amped-uri-exists($dir,false())) then xdmp:document-delete($dir) else ()
	return ''
};

declare private function orion-api:children($uri as xs:string,$depth as xs:int) as array-node() {
	let $uris:=cts:uris((),("any"),cts:directory-query($uri,if ($depth=1) then '1' else 'infinity'))[count(tokenize(substring-after(.,$uri),'/')[.!='']) le $depth]
	return array-node {
		$uris!orion-api:file(.,$depth - 1,false())
	}
};

declare private function orion-api:file($uri as xs:string,$depth as xs:int,$include-parents as xs:boolean) as json:object {
	let $ts as xs:integer?:=if (xdmp:document-properties($uri)//prop:last-modified) then (xdmp:document-properties($uri)//prop:last-modified!xs:dateTime(.) - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration("PT0.001S") else xdmp:document-timestamp($uri) idiv 10000
	return orion-api:file($uri,$depth,$include-parents,$ts,document-length(doc($uri)))
};

declare private function import-location($uri as xs:string) as xs:string {
	concat("/xfer/import",substring-after($uri,'/file'))
};

declare private function export-location($uri as xs:string) as xs:string {
	concat("/xfer/export",substring-after(if (ends-with($uri,'/')) then substring($uri,1,string-length($uri)-1) else $uri,'/file'))
};

declare private function orion-api:file($uri as xs:string,$depth as xs:int,$include-parents as xs:boolean,$ts as xs:integer?,$size as xs:integer) as json:object {
	let $path as xs:string:=ml-path($uri)
	let $directory as xs:boolean:=ends-with($uri,'/') or count(xdmp:document-properties($uri)//prop:directory)!=0
	let $parents as xs:string+:=tokenize($path,'/')[.!=''][1 to last()-1]
	let $name as xs:string:=tokenize($path,'/')[.!=''][last()]
	return json:object() 
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
		!(if ($directory) then map-with(.,"ImportLocation", import-location($uri))!map-with(.,"ExportLocation", export-location($uri)) else .)
		!(if ($directory and $depth gt 0) then map-with(.,'Children',orion-api:children($uri,$depth))  else .)
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
			return if (fn:empty($d)) then text{''} else $d
		default return fn:error(xs:QName('orion-api:file-get-request'),'unsupported part '||$part)
		return if (fn:count($parts)=1) then
			let $_:=xdmp:set-response-content-type(if ($parts='meta') then 'application/json' else xdmp:uri-content-type($uri))
			return $result
		else
			xdmp:multipart-encode('boundary10382384-2840',<manifest>{for $part in $parts return <part><headers><Content-Type>{if ($part='meta') then 'application/json' else xdmp:uri-content-type($uri)}</Content-Type></headers></part>}</manifest>,
				for $r in $result return if ($r instance of node()) then $r else text{xdmp:quote($r)}
			)
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
	let $uri:=concat(ml-uri($path),if (ends-with($path,'/') or fn:empty($name)) then () else '/',$name,if ($directory) then '/' else ())
	let $exists as xs:boolean:=amped-uri-exists($uri,false())
	return if ($create-options='no-overwrite' and $exists) then 
		xdmp:set-response-code(412,'file exists')
	else if ($method-override='PATCH') then
		let $ifmatch as xs:string:=normalize-space(xdmp:get-request-header('If-Match'))
		let $doc:=doc($uri)
		let $hash:=if ($ifmatch!='') then document-hash($doc) else ()
		return if ($ifmatch='' or $ifmatch=$hash) then 
			let $ndoc:=document{text{fn:fold-left(function($a,$diff){orion-api:patch($a,$diff/start!xs:integer(.),$diff/end!xs:integer(.),$diff/text/data())},xdmp:quote($doc),$body/diff)}}
			let $_:=xdmp:node-replace($doc,ensure-type($uri,$ndoc))
			return orion-api:file($uri,0,false(),$ts,document-length($ndoc))
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
			return if ($create-options='move') then xdmp:document-delete($uri2) else ()
		let $_:=xdmp:set-response-code(if ($exists) then 200 else 201,'created')
		let $_:=xdmp:add-response-header("Location",$uri)
		return orion-api:file($uri,0,false(),$ts,0)		
	else
		let $source as node():=if ($create-options=('move','copy') and is-file($body/Location/data())) 
			then doc(ml-uri(substring-after($body/Location/data(),'/file')))
			else text{''}
		let $_:=if ($directory) then xdmp:directory-create($uri,xdmp:default-permissions(),('/orion/files/'))
		else xdmp:document-insert($uri,ensure-type($uri,$source),xdmp:default-permissions(),('/orion/files/'))
		let $_:=if ($create-options='move' and is-file($body/Location/data())) 
			then xdmp:document-delete(ml-uri(substring-after($body/Location/data(),'/file')))
			else ()
		let $_:=xdmp:set-response-code(if ($exists) then 200 else 201,'created')
		let $_:=xdmp:add-response-header("Location",$uri)
		return orion-api:file($uri,0,false(),$ts,document-length($source))
};

declare private function is-binary($uri as xs:string) {
	not(contains(xdmp:uri-content-type($uri),'text'))
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
				let $_:=if ($exists) then xdmp:node-replace($doc,ensure-type($uri,$body))
				else xdmp:document-insert($uri,ensure-type($uri,$body))
				return orion-api:file($uri,1,false(),$ts,document-length($body))
			else
				xdmp:set-response-code(414,"document "||$uri||" changed "||$ifmatch||"!="||$hash)
		case 'meta' return if ($exists) then () else xdmp:set-response-code(404,$uri||' not found')
		default return fn:error(xs:QName('orion-api:file-put-request'),'invalid part '||$part)
};

declare function orion-api:file-delete-request($path as xs:string) {
	let $uri:=ml-uri($path)
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

