import module namespace fs-api="http://marklogic.com/lib/xquery/fs-api" at "/lib/fs-api.xqy"; 

declare namespace fs="http://marklogic.com/xdmp/status/forest";
declare namespace prop="http://marklogic.com/xdmp/property";

let $path:=xdmp:get-request-field('path')
let $hpath:=fn:replace($path,'^/http:','http:')!fn:replace(.,'http:/([^/])','http://$1')
let $method:=xdmp:get-request-method()
let $dbname:=xdmp:database-name(xdmp:database())
let $ident:=concat('/fs/',$dbname,$hpath)
let $roles:=fs-api:amped-roles()
let $me:=xdmp:get-current-user()

return if ($method=('GET','HEAD','OPTIONS')) then
if (fn:empty($path)) then
let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.dir')
return fs-api:amped-list-databases()
else if (not(fn:ends-with($hpath,'/')) and fs-api:amped-uri-match($hpath)) then
	let $doc:=doc($hpath)
	return if (fn:empty($doc)) then
		let $_:=xdmp:set-response-code(404,"not existant or nonreadable document "||$hpath)
		return ()
	else
	let $mime0:=xdmp:uri-content-type($hpath)
	let $mime:=if ($mime0='application/x-unknown-content-type') then if ($doc/text()) then 'text/plain' else if ($doc/object-node()) then 'application/json' else if ($doc/*) then 'text/xml' else if ($doc/binary()) then 'application/octet-stream' else $mime0 else $mime0 
	let $op:=xdmp:get-request-field('op')
	return if ($op='stat') then 
		let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.pstyfile')
		let $fcapabilities:=fs-api:amped-capabilities($path,$roles)
		return object-node {
			"name":fn:tokenize($hpath,'/')[last()],
			"ident":$ident,
			"mime":$mime,
			"owner":$me,
			"readable":$fcapabilities='read',
			"writable":$fcapabilities=('insert','delete'),
			"executable":$fcapabilities='execute'
		}
	else 
	let $_:=xdmp:add-response-header('Content-Type',$mime)
	return $doc
else
	let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.dir')
	let $_:=xdmp:add-response-header('Cache-Control','max-age:120')
	let $epath:=if (fn:ends-with($path,'/')) then $path else concat($path,'/')
	let $eepath:=fn:replace($epath,'^/http:','http:')!fn:replace(.,'http:/([^/])','http://$1')
	let $uris:=fs-api:amped-uri-match(concat($eepath,'*'))
	let $uris2:=if ($path='/') then fs-api:amped-uri-match('http://*') else ()
	let $paths:=($uris!substring-after(.,$eepath)!(if (contains(.,'/')) then concat(substring-before(.,'/'),'/') else .)[not(.=('','/'))],
		$uris2!substring-after(.,"http://")!(if (contains(.,'/')) then concat(substring-before(.,'/'),'/') else .)[not(.=('','/'))]!concat('http:/',.))
	let $fcapabilities:=fs-api:amped-capabilities($epath,$roles)
	return object-node {
			"name":if ($path='/') then $dbname else fn:tokenize($path,'/')[.!=''][last()],
			"ident":$ident,
			"mime":'application/vnd.pigshell.dir',
			"readable":$fcapabilities='read',
			"writable":$fcapabilities=('insert','delete'),
			"owner":$me,
			(:"cookie": xdmp:integer-to-hex(xdmp:hash64(string-join($uris))),:)
			"files":array-node{
				for $p in fn:distinct-values($paths) return 
				if (fn:ends-with($p,'/')) then
					let $luris:=$uris!substring-after(.,concat($path,$p))!(if (contains(.,'/')) then concat(substring-before(.,'/'),'/') else .)
					let $count:=fn:count(fn:distinct-values($luris))
					let $priv:=fs-api:find-uri-privilege(concat($path,$p))
					return object-node{"owner":$me,"readable": true(), "writable": $priv,"ident":concat('/fs/',$dbname,$path,$p),"count":$count,"mime": "application/vnd.pigshell.dir","name":substring-before($p,'/'),"mtime":0,"size":0}
				else
					let $uri:=concat($hpath,$p)
					let $doc:=doc($uri)
					let $capabilities:=fs-api:amped-capabilities($uri,$roles)
					let $lm:=if ($capabilities='read') then xdmp:document-get-properties($uri,xs:QName('prop:last-modified')) else ()
					let $size:=if ($doc/binary()) then xdmp:binary-size($doc/binary()) else string-length(xdmp:quote($doc,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
					let $mime0:=xdmp:uri-content-type($uri)
					let $mime:=if ($mime0='application/x-unknown-content-type') then if ($doc/text()) then 'text/plain' else if ($doc/object-node()) then 'application/json' else if ($doc/*) then 'text/xml' else if ($doc/binary()) then 'application/octet-stream' else $mime0 else $mime0 
					return object-node{"owner":$me,"_hidden":not($capabilities='read'),"executable":$capabilities='execute',"readable": $capabilities='read', "writable": $capabilities='update',"uri":$uri,"ident":concat('/fs/',$dbname,$path,$p),"mime": $mime,"name":$p,"mtime":number-node{if (fn:empty($lm)) then 0 else xdmp:wallclock-to-timestamp(xs:dateTime($lm)) div 10000},"size":$size}
			}
		}

else if ($method='POST') then
	let $op:=xdmp:get-request-field('op')
	let $filename:=xdmp:get-request-field("filename")
	let $data:=document{xdmp:get-request-field("data")}
	let $uri:=concat($hpath,$filename)
	let $mime0:=xdmp:uri-content-type($filename)
	let $mime:=if ($mime0='application/x-unknown-content-type') then if ($data/text()) then 'text/plain' else if ($data/object-node()) then 'application/json' else if ($data/*) then 'text/xml' else if ($data/binary()) then 'application/octet-stream' else $mime0 else $mime0 
	let $size:=if ($data/binary()) then xdmp:binary-size($data/binary()) else string-length(xdmp:quote($data,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
	return if ($op='put') then
		if (starts-with($uri,'/') or starts-with($uri,'http:/')) then
			let $_:=xdmp:document-insert($uri,$data)
			let $_:=xdmp:set-response-code(201,"Created")
			let $tm:=fn:current-dateTime()
			return object-node {"owner":$me, "ctype":'application/vnd.pigshell.pstyfile',"ident":concat('/fs/',$dbname,$uri),"name":$filename,"readable":true(),"writable":true(),"size":$size,"mime":$mime,"mtime":number-node{xdmp:wallclock-to-timestamp($tm) div 10000}}
		else 
			let $_:=xdmp:set-response-code(404,"unvalid path")
			return ()
	else if ($op='rm') then
		if (fn:exists(doc($uri))) then
			let $_:=xdmp:document-delete($uri)
			let $_:=xdmp:set-response-code(204,"No Content")
			return ()
		else 
			let $uris:=fs-api:amped-uri-match(concat($uri,'/*'))
			return if (count($uris)=1 and $uris=concat($uri,'/')) then
				let $_:=xdmp:document-delete(concat($uri,'/'))
				let $_:=xdmp:set-response-code(204,"No Content")
				return ()
			else 
				let $_:=if ($uris=$uri or fn:empty($uris)) then xdmp:set-response-code(404,"not found") else  xdmp:set-response-code(400,"not empty")
				return ()
	else if ($op='mkdir') then
		let $_:=xdmp:directory-create(if (fn:ends-with($uri,'/')) then $uri else concat($uri,'/'))
		let $_:=xdmp:set-response-code(204,"No Content")
		return ()
	else if ($op='append') then
		let $x:=doc($hpath)
		let $mime0:=xdmp:uri-content-type($hpath)
		let $mime:=if ($mime0='application/x-unknown-content-type') then if ($x/text()) then 'text/plain' else if ($x/object-node()) then 'application/json' else if ($x/*) then 'text/xml' else if ($x/binary()) then 'application/octet-stream' else $mime0 else $mime0 
		let $size1:=if ($x/binary()) then xdmp:binary-size($x/binary()) else string-length(xdmp:quote($x,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
		let $tm:=fn:current-dateTime()
		let $_:=if ($mime='text/plain') then xdmp:document-insert($hpath,text{concat(xdmp:quote($x,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>),xdmp:quote($data,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))}) else xdmp:node-insert-after($x/node()[last()],$data/node())
		return object-node {"owner":$me, "ctype":'application/vnd.pigshell.pstyfile',"ident":$ident,"name":fn:tokenize($hpath,'/')[last()],"readable":true(),"writable":true(),"size":$size+$size1,"mime":$mime,"mtime":number-node{xdmp:wallclock-to-timestamp($tm) div 10000}}
	else if ($op='rename') then
		let $filename10:=xdmp:get-request-field('src')
		let $filename20:=xdmp:get-request-field('dst')
		let $filename1:=if (starts-with($filename10,'/fs/')) then substring-after($filename10,concat($dbname,'/')) else $filename10
		let $filename2:=if (starts-with($filename20,'/fs/')) then substring-after($filename20,concat($dbname,'/')) else $filename20
		let $x:=doc($hpath)
		return if (fn:empty($x)) then
			xdmp:set-response-code(404,"Not found")
		else
		let $nuri:=concat(substring-before($hpath,$filename1),$filename2)
		let $_:=xdmp:document-insert($nuri,$x)
		let $_:=xdmp:document-delete($uri)
		let $_:=xdmp:set-response-code(204,"No Content")
		return ()

	else ()

else ()

