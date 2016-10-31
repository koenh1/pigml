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
						"Location":concat('/orion/file',$path,'/',$project/Id/data(),'/'),
						"ChildrenLocation":concat('/orion/file',$path,'/',$project/Id/data(),'/?depth=1'),
						"ExportLocation":concat('/xfer/export',$path,'/',$project/Id/data(),'.zip'),
						"ImportLocation":concat('/xfer/import',$path,'/',$project/Id/data()),
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
			and orion-api:amped-uri-exists(concat('/orion/file',$path,'/A',$i),true())=false() return concat('A',$i))[1]
		let $location as xs:string:=if (fn:empty($body/ContentLocation/data())) then concat('/orion/file',$path,'/',$id,'/')
			else $body/ContentLocation/data()
		let $d:=object-node{"Id" : $id,"Location": concat('/orion/workspace',$path,'/project/',$id), "Name" : $name, "Owner" : xdmp:get-current-user(),"ContentLocation":$location }
		let $_:=xdmp:document-insert(
	       concat('/orion/workspace',$path,'/project/',$id), $d, xdmp:default-permissions(),"/orion/workspaces/")
		let $_:=xdmp:directory-create($location,xdmp:default-permissions(),('/orion/files/','/orion/projects/'))
		return $d
};

declare function orion-api:workspace-delete-request($path as xs:string) {
	let $_:=if (orion-api:amped-uri-exists(concat('/orion/workspace',$path),false())) then xdmp:document-delete(concat('/orion/workspace',$path)) else ()
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
	return orion-api:file($uri,$depth,$include-parents,$ts,string-length(xdmp:quote(doc($uri))))
};

declare private function orion-api:file($uri as xs:string,$depth as xs:int,$include-parents as xs:boolean,$ts as xs:integer?,$size as xs:integer) as json:object {
	let $path as xs:string:=substring-after($uri,'/orion/file')
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
		!map-with(.,"Location", concat('/orion/file',$path))
		!map-with(.,"Name", $name)
		!(if ($depth gt 0 and $directory) then map-with(.,"ImportLocation", concat("/xfer/import/",substring-after($uri,'/file/')))!map-with(.,'Children',orion-api:children($uri,$depth)) else .)
		!(if ($include-parents) then map-with(.,"Parents", array-node {
		  	for $parent at $pos in $parents where $pos gt 1 order by $pos descending return object-node {
		    	"ChildrenLocation": concat('/orion/file/',string-join($parents[1 to $pos],'/'),"/?depth=1"),
		    	"Location": concat("/orion/file/",string-join($parents[1 to $pos],'/'),'/'),
		    	"Name": $parent
			} 
		  }) else .)
		!map-with(.,if ($directory) then "ChildrenLocation" else "FileEncoding",if ($directory) then concat('/orion/file',$path,"?depth=1") else array-node {"UTF-8"})
};

declare function orion-api:file-get-request($path as xs:string) {
	let $uri:=concat('/orion/file',$path)
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
			let $hash:=xdmp:hash64(xdmp:quote($d))
			let $_:=xdmp:add-response-header('ETag',xdmp:integer-to-hex($hash))
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
	let $uri:=concat('/orion/file',$path,if (ends-with($path,'/') or fn:empty($name)) then () else '/',$name,if ($directory) then '/' else ())
	let $exists as xs:boolean:=amped-uri-exists($uri,false())
	return if ($create-options='no-overwrite' and $exists) then 
		xdmp:set-response-code(412,'file exists')
	else if ($method-override='PATCH') then
		let $ifmatch as xs:string:=normalize-space(xdmp:get-request-header('If-Match'))
		let $doc:=doc($uri)
		let $hash:=if ($ifmatch!='') then xdmp:integer-to-hex(xdmp:hash64(xdmp:quote($doc))) else ()
		return if ($ifmatch='' or $ifmatch=$hash) then 
			let $ndoc:=fn:fold-left(function($a,$diff){orion-api:patch($a,$diff/start!xs:integer(.),$diff/end!xs:integer(.),$diff/text/data())},xdmp:quote($doc),$body/diff) 
			let $_:=xdmp:node-replace($doc,document{text{$ndoc}})
			return orion-api:file($uri,0,false(),$ts,string-length($ndoc))
		else
			xdmp:set-response-code(414,"document "||$uri||" changed "||$ifmatch||"!="||$hash)
	else
	if ($create-options=('move','copy') and contains($body/Location/data(),'/orion/file/') and ends-with($body/Location/data(),'/')) then
		let $source:=concat('/orion/file',substring-after($body/Location/data(),'/file'))
		let $sources:=cts:uri-match(concat($source,'*'))
		return if (fn:empty($sources)) then xdmp:set-response-code(404,'not found '||$source)
		else
		let $_:=for $uri2 in $sources 
			let $d:=doc($uri2)
			let $t:=concat($uri,substring-after($uri2,$source))
			let $_:=xdmp:document-insert($t,$d,xdmp:default-permissions(),('/orion/files/'))
			return if ($create-options='move') then xdmp:document-delete($uri2) else ()
		let $_:=xdmp:set-response-code(if ($exists) then 200 else 201,'created')
		let $_:=xdmp:add-response-header("Location",$uri)
		return orion-api:file($uri,0,false(),$ts,0)		
	else
		let $source as node():=if ($create-options=('move','copy') and contains($body/Location/data(),'/orion/file/')) 
			then doc(concat('/orion/file',substring-after($body/Location/data(),'/file')))
			else text{''}
		let $_:=if ($directory) then xdmp:directory-create($uri,xdmp:default-permissions(),('/orion/files/'))
		else xdmp:document-insert($uri,$source,xdmp:default-permissions(),('/orion/files/'))
		let $_:=if ($create-options='move' and starts-with($body/Location/data(),'/file/')) 
			then xdmp:document-delete(concat('/orion/file',substring-after($body/Location/data(),'/file')))
			else ()
		let $_:=xdmp:set-response-code(if ($exists) then 200 else 201,'created')
		let $_:=xdmp:add-response-header("Location",$uri)
		return orion-api:file($uri,0,false(),$ts,string-length(xdmp:quote($source)))
};

declare function orion-api:file-put-request($path as xs:string) {
	let $uri:=concat('/orion/file',$path)
	let $directory as xs:boolean:=ends-with($uri,'/') or count(xdmp:document-properties($uri)//prop:directory)!=0
	let $parts as xs:string+:=if (fn:empty(xdmp:get-request-field('parts'))) then if ($directory) then 'meta' else 'body' else fn:tokenize(xdmp:get-request-field('parts'),'[, ]+')
	let $exists as xs:boolean:=amped-uri-exists($uri,false())
	let $source as xs:string?:=xdmp:get-request-field('source')
	let $ts:=xdmp:eval("xdmp:request-timestamp()",(),<options xmlns="xdmp:eval"><transaction-mode>query</transaction-mode></options>)
	let $ifmatch as xs:string:=normalize-space(xdmp:get-request-header('If-Match'))
	return if ($exists) then 
		for $part in $parts
		return switch($part)
		case 'body' return
			let $body:=if (fn:empty($source)) then xdmp:get-request-body('text') else xdmp:http-get($source) 
			let $doc:=doc($uri)
			let $hash:=if ($ifmatch!='') then xdmp:integer-to-hex(xdmp:hash64(xdmp:quote($doc))) else ()
			return if ($ifmatch='' or $ifmatch=$hash) then 
				let $_:=xdmp:node-replace($doc,document{text{$body}})
				return orion-api:file($uri,1,false(),$ts,string-length($body))
			else
				xdmp:set-response-code(414,"document "||$uri||" changed "||$ifmatch||"!="||$hash)
		case 'meta' return ()
		default return fn:error(xs:QName('orion-api:file-put-request'),'invalid part '||$part)
	else xdmp:set-response-code(404,$uri||' not found')
};

declare function orion-api:file-delete-request($path as xs:string) {
	let $uri:=concat('/orion/file',$path)
	let $directory as xs:boolean:=ends-with($uri,'/') or count(xdmp:document-properties($uri)//prop:directory)!=0
	let $ifmatch as xs:string:=normalize-space(xdmp:get-request-header('If-Match'))
	let $doc:=doc($uri)
	return if (not($directory) and fn:empty($doc)) then xdmp:set-response-code(205,'Ok (not found)')
	else
	let $hash:=if ($ifmatch!='') then xdmp:integer-to-hex(xdmp:hash64(xdmp:quote($doc))) else ()
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

