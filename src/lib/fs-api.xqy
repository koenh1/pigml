xquery version "1.0-ml";
module namespace fs-api="http://marklogic.com/lib/xquery/fs-api"; 


import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace sec="http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";
import module namespace functx   = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";

declare namespace fs="http://marklogic.com/xdmp/status/forest";
declare namespace prop="http://marklogic.com/xdmp/property";
declare namespace db="http://marklogic.com/xdmp/database";
declare namespace wkes="http://www.wolterskluwer.com/schemas/appollo/entity/v1.0";
declare namespace es="http://marklogic.com/entity-services";

declare variable $fs-api:entities-path:='/entity-schemas/';

declare function fs-api:compile() {
	for $s in xdmp:directory($fs-api:entities-path)//wkes:entity-type
	let $m:=xdmp:xslt-invoke('/lib/entity-schema2xqy.xsl',$s)
	let $uri:=concat($s/ancestor::wkes:entity-schema/@at,$s/@name,'.xqy')
	return ($uri,$m,xdmp:invoke-function(function(){xdmp:document-insert($uri,text{$m},(xdmp:permission("entity-role", "execute"),xdmp:permission("entity-role", "read")))},
	  <options xmlns="xdmp:eval"><database>{xdmp:modules-database()}</database></options>))
};

declare function fs-api:resolve-entity($uri as xs:string) as xs:string* {
	for $s in xdmp:directory($fs-api:entities-path)/wkes:entity-schema
		for $et in $s/wkes:entities/wkes:entity-type[starts-with($uri,@directory)]
			return if ($et/@depth='Infinity' or not(fn:contains(substring-after($uri,$et/@directory),'/'))) then (concat($s/@namespace,'#',$et/@name),concat($s/@at,$et/@name,'.xqy')) else ()
};

declare function fs-api:amped-get-entity-constructor($uri as xs:string) as function(*)* {
	let $r:=fs-api:resolve-entity($uri)
	return if (fn:empty($r)) then ()
	else 
	let $script:=fn:string-join(("import module namespace ent=""",$r[1],""" at """,$r[2],""";","(ent:generic-create-from-doc#2,ent:valid-events#1)"),"")
	return xdmp:eval($script)
};

declare function fs-api:amped-get-entity-canonical($uri as xs:string) as function(*)* {
	let $r:=fs-api:resolve-entity($uri)
	return if (fn:empty($r)) then ()
	else 
	let $script:=fn:string-join(("import module namespace ent=""",$r[1],""" at """,$r[2],""";","(ent:canonical#1)"),"")
	return xdmp:eval($script)
};

declare function fs-api:amped-get-entity-action($uri as xs:string,$action as xs:string,$args as xs:int) as function(*)* {
	let $r:=fs-api:resolve-entity($uri)
	return if (fn:empty($r)) then ()
	else 
	let $script:=fn:string-join(("import module namespace ent=""",$r[1],""" at """,$r[2],""";","(function-lookup(xs:QName('ent:",$action,"'),1),function-lookup(xs:QName('ent:",$action,"'),2))"),"")
	return xdmp:eval($script)
};


declare function fs-api:amped-roles() as xs:unsignedLong* {
	let $user:=xdmp:get-request-field('user')
	let $me:=if (fn:empty($user)) then xdmp:get-current-user() else $user
	return xdmp:user-roles($me)
(:	return xdmp:invoke-function(function(){sec:get-role-ids(sec:user-get-roles($me))}, <options xmlns="xdmp:eval"><database>{xdmp:security-database()}</database></options>)/data() :)
};

declare function fs-api:amped-capabilities($uri as xs:string,$roles as xs:unsignedLong*) as xs:string* {
	let $admin:=xdmp:role('admin')
	(:xdmp:invoke-function(function(){sec:get-role-ids('admin')}, <options xmlns="xdmp:eval"><database>{xdmp:security-database()}</database></options>)/data() :)
	return if ($admin=$roles) then ('read','update','insert','delete','execute') else xdmp:document-get-permissions($uri)[sec:role-id=$roles]//sec:capability/string()
};

declare function fs-api:amped-uri-match($pattern as xs:string) as xs:string* {
	cts:uri-match($pattern)
};

declare private function fs-api:find-uri-privilege-impl($uri as xs:string) as xs:boolean {
	try{xdmp:has-privilege($uri,'uri')} catch($ex){false()}
};

declare function fs-api:amped-document-get-permissions($uri as xs:string) as json:object {
	let $p:=xdmp:document-get-permissions($uri)
	let $roles:=fn:distinct-values($p//sec:role-id/data())
	let $rolenames:=xdmp:invoke-function(function(){sec:get-role-names($roles)}, <options xmlns="xdmp:eval"><database>{xdmp:security-database()}</database></options>)/data()
	let $map:=map:new(for $role at $i in $roles return map:entry(string($role),$rolenames[$i]))
	return json:object(<json:object>{
			for $role in $roles order by map:get($map,string($role)) 
			return <json:entry key="{map:get($map,string($role))}">
				<json:value><json:array>{for $d in $p[sec:role-id=$role]/sec:capability order by $d return (<json:value>{$d/data()}</json:value>)}</json:array></json:value></json:entry>}</json:object>)
};

declare function fs-api:find-uri-privilege($uri as xs:string) as xs:boolean {
	if (string-length($uri)=0) then false() else
	let $r:=fs-api:find-uri-privilege-impl($uri)
	return if ($r=true()) then $r else if ($uri!='/') then fs-api:find-uri-privilege(concat(string-join(fn:tokenize($uri,'/')[1 to last()-2],'/'),'/'))
	else false()
};

declare function fs-api:amped-last-modified($uri as xs:string,$capabilities as xs:string*) as xs:integer {
	let $lm:=if ($capabilities='read') then xdmp:document-get-properties($uri,xs:QName('prop:last-modified')) else ()
	return if (fn:empty($lm)) then xdmp:document-timestamp($uri) else xdmp:wallclock-to-timestamp(xs:dateTime($lm))
};

declare function fs-api:amped-list-fields() as object-node() {
  let $config := admin:get-configuration()
  return object-node{
	"name":"fields",
	"ident":concat("/fs/",xdmp:database-name(xdmp:database()),'/fields/'),
	"readable":true(),
	"writeable":false(),
	"owner":xdmp:get-current-user(),
	"mime":'application/vnd.pigshell.dir',
	"files":array-node{
	  for $f in admin:database-get-fields($config, xdmp:database())[db:field-name!='']
	  return object-node {
			"mime":'application/vnd.pigshell.dir',
	  		"name":$f/db:field-name/string(),
	  		"ident":concat("/fs/",xdmp:database-name(xdmp:database()),'/fields/',$f/db:field-name/string()),
			"readable":true(),
			"writeable":false(),
			"owner":xdmp:get-current-user()
		}
	  }
	}
};

declare function fs-api:amped-list-databases() as object-node() {
let $fmap:=
	let $config:=admin:get-configuration()
	let $forests:=admin:get-forest-ids($config)
	return map:new(
	for $forest in $forests
	let $fs:=xdmp:forest-status($forest)
	let $db:=$fs/fs:database-id/string()
	return map:entry($db,$fs))

return object-node{
	"name":"fs",
	"ident":"/fs/",
	"readable":true(),
	"writeable":true(),
	"owner":xdmp:get-current-user(),
	"mime":'application/vnd.pigshell.dir',
	"files":array-node{
		for $db in map:keys($fmap) 
			let $fstats:=map:get($fmap,$db)
		    let $size := sum(for $ss in $fstats[fs:state=("open","open replica")]/fs:stands/fs:stand return $ss/fs:disk-size)
		    let $count:=xdmp:eval("cts:count-aggregate(cts:uri-reference(),'document')",(),<options xmlns="xdmp:eval"><database>{$db}</database></options>)
		    let $times := $fstats/fs:last-state-change/string()
		    let $time:=$fstats[fs:state= ('open', 'open replica')]/fs:nonblocking-timestamp/string()
			return 
			object-node{"ident": concat("/fs/",xdmp:database-name(xs:unsignedLong($db)),'/'), "name": xdmp:database-name(xs:unsignedLong($db)),
		 "readable": true(), "writable": true(), "mime": "application/vnd.pigshell.dir", "count":$count,
		 "mtime": number-node{xdmp:wallclock-to-timestamp(xs:dateTime($times)) div 10000}, "atime": number-node{xs:unsignedLong($time) div 10000}, "size": $size*1024*1024}
		}
	}
};

declare function fs-api:entity-dir($ent as element(es:entity),$uri as xs:string,$ident as xs:string,$fcapabilities as xs:string*,$dbname as xs:string,$me as xs:string) as object-node() {
	let $lm:=fs-api:amped-last-modified($uri,$fcapabilities)
	return object-node {
			"name":fn:tokenize($uri,'/')[.!=''][last()],
			"ident":concat($ident,'/'),
			"capabilities":array-node{$fcapabilities},
			"uri":$uri,
			"mime":'application/vnd.pigshell.dir',
			"readable":$fcapabilities='read',
			"writable":$fcapabilities=('update','insert','delete'),
			"owner":$me,
			"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000},
			"count":2,
			"files":array-node {
				object-node {
					"name":"ctl",
					"ident":concat($ident,'/ctl/'),
					"mime":'application/vnd.pigshell.dir',
					"readable":$fcapabilities='read',
					"writable":$fcapabilities=('update','insert','delete'),
					"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000},
					"owner":$me
				},
				object-node {
					"name":"entity.xml",
					"ident":concat($ident,'/entity.xml'),
					"mime":'text/xml',
					"readable":$fcapabilities='read',
					"writable":$fcapabilities=('update','insert','delete'),
					"size":string-length(xdmp:quote($ent)),
					"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000},
					"owner":$me
				}
			}
		}
};

declare function fs-api:entity-ctl-dir($ent as element(es:entity),$uri as xs:string,$ident as xs:string,$fcapabilities as xs:string*,$dbname as xs:string,$me as xs:string) as object-node() {
	let $lm:=fs-api:amped-last-modified($uri,$fcapabilities)
	return object-node {
			"name":'ctl',
			"ident":$ident,
			"mime":'application/vnd.pigshell.dir',
			"readable":$fcapabilities='read',
			"writable":$fcapabilities=('update','insert','delete'),
			"owner":$me,
			"test":"ok",
			"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000},
			"files":array-node {
				let $valid-events:=fs-api:amped-get-entity-constructor($uri)[2]($ent)
				return for $event in $valid-events order by $event
				return object-node {
					"name":$event,
					"ident":concat($ident,$event),
					"mime":"text/plain",
					"size":0,
					"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000}
				}
			}
		}
};

declare function fs-api:files($path,$dbname,$ident,$roles) as array-node() {
	let $vpath:=fn:replace($path,'//','/')
	let $uris:=fs-api:amped-uri-match(concat($path,'*'))
	let $uris2:=if ($path='/') then fs-api:amped-uri-match('http://*') else ()
	let $paths:=($uris!substring-after(.,$path)!(if (contains(.,'/')) then concat(substring-before(.,'/'),'/') else .)[not(.=('','/'))],
		$uris2!substring-after(.,"http://")!(if (contains(.,'/')) then concat(substring-before(.,'/'),'/') else .)[not(.=('','/'))]!concat('http:/',.))
	let $user:=xdmp:get-request-field('user')
	let $me:=if (fn:empty($user)) then xdmp:get-current-user() else $user
	return array-node{
				for $p in fn:distinct-values($paths) return 
				if (fn:ends-with($p,'/')) then
					let $luris:=$uris!substring-after(.,concat($path,$p))!(if (contains(.,'/')) then concat(substring-before(.,'/'),'/') else .)
					let $count:=fn:count(fn:distinct-values($luris))
					let $priv:=fs-api:find-uri-privilege(concat($path,$p))
					return object-node{"owner":$me,"readable": true(), "writable": $priv,"ident":concat('/fs/',$dbname,'/content',$vpath,$p),"count":$count,"mime": "application/vnd.pigshell.dir","name":substring-before($p,'/'),
						"mtime":number-node{0},"size":0}
				else
					let $uri:=concat($path,$p)
					let $doc:=doc($uri)
					let $ident:=concat('/fs/',$dbname,'/content',$vpath,$p)
					let $capabilities:=fs-api:amped-capabilities($uri,$roles)
					return if ($doc/es:entity) then 
						fs-api:entity-dir($doc/es:entity,$uri,$ident,$capabilities,$dbname,$me)
					else
					let $lm:=fs-api:amped-last-modified($uri,$capabilities)
					let $size:=if ($doc/binary()) then xdmp:binary-size($doc/binary()) else string-length(xdmp:quote($doc,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
					let $mime0:=xdmp:uri-content-type($uri)
					let $mime:=if ($mime0='application/x-unknown-content-type') then if ($doc/text()) then 'text/plain' else if ($doc/object-node()) then 'application/json' else if ($doc/*) then 'text/xml' else if ($doc/binary()) then 'application/octet-stream' else $mime0 else $mime0 
					return object-node{"owner":$me,"_hidden":not($capabilities='read'),"executable":$capabilities='execute',"readable": $capabilities='read', "writable": $capabilities='update',"uri":$uri,"ident":$ident,"mime": $mime,"name":$p,
						"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000},"size":$size}
			}
};

declare function fs-api:dir($path,$dbname,$ident,$roles,$stat) {
	if (not(fn:ends-with($path,'/'))) then fn:error(xs:QName('error')) else
	let $user:=xdmp:get-request-field('user')
	let $me:=if (fn:empty($user)) then xdmp:get-current-user() else $user
	let $furi:=if (string-length($path) gt 1) then substring($path,1,string-length($path)-1) else $path
	let $fcapabilities:=fs-api:amped-capabilities($furi,$roles)
	let $ent:=doc($furi)
	return if (fn:empty($ent/es:entity))
	then if ($stat) then object-node {
			"name":if ($path='/') then $dbname else fn:tokenize($path,'/')[.!=''][last()],
			"ident":$ident,
			"mime":'application/vnd.pigshell.dir',
			"readable":$fcapabilities='read',
			"writable":$fcapabilities=('update','insert','delete'),
			"owner":$me
		}
		else object-node {
			"name":if ($path='/') then $dbname else fn:tokenize($path,'/')[.!=''][last()],
			"ident":$ident,
			"mime":'application/vnd.pigshell.dir',
			"readable":$fcapabilities='read',
			"writable":$fcapabilities=('update','insert','delete'),
			"owner":$me,
			"files":fs-api:files($path,$dbname,$ident,$roles)
		}
	else fs-api:entity-dir($ent/es:entity,base-uri($ent),$ident,$fcapabilities,$dbname,$me)
};

declare function fs-api:fieldlistfile($fieldname,$dbname) as object-node()* {
	let $size:=sum(cts:field-values($fieldname)!string-length(.)+1)
	return (object-node {
		"mime":"text/plain",
		"name":"values.txt",
		"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/values.txt'),
		"readable":true(),
		"writable":false(),
		"size":$size,
		"owner":xdmp:get-current-user()
	},
	object-node {
		"mime":"application/json",
		"name":"counts.json",
		"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/counts.json'),
		"readable":true(),
		"writable":false(),
		"size":0,
		"owner":xdmp:get-current-user()
	})
};

declare private function remove-end-slash($s as xs:string) as xs:string {
	if (ends-with($s,'/')) then substring($s,1,string-length($s)-1) else $s
};

declare function fs-api:main() {

let $path:=xdmp:get-request-field('path')
let $op:=xdmp:get-request-field('op')
let $docpath:=if (starts-with($path,'/content')) then substring-after($path,'/content') else ()
let $fieldpath:=if (starts-with($path,'/fields')) then substring-after($path,'/fields') else ()
let $fieldname:=substring-after($fieldpath,'/')!(if (contains(.,'/')) then substring-before(.,'/') else .)
let $fieldvalue:=substring-after($fieldpath,concat($fieldname,'/values/'))!(if (contains(.,'/')) then substring-before(.,'/') else .)
let $fieldvalueuri:=substring-after($fieldpath,concat($fieldname,'/values/'))!substring-after(.,'/')!substring-before(.,'.href')
let $hpath:=fn:replace(if ($docpath='') then '/' else $docpath,'^/http:','http:')!fn:replace(.,'http:/([^/])','http://$1')
let $method:=xdmp:get-request-method()
let $dbname:=xdmp:database-name(xdmp:database())
let $ident:=concat('/fs/',$dbname,'/content',$docpath)
let $roles:=fs-api:amped-roles()
let $user:=xdmp:get-request-field('user')
let $me:=if (fn:empty($user)) then xdmp:get-current-user() else $user
let $mapped-hpath:=
	if (fn:ends-with($hpath,'/entity.xml') and fn:exists(doc(functx:substring-before-last($hpath,'/entity.xml'))))
		then substring-before($hpath,'/entity.xml')
	else if (fn:contains($hpath,'/ctl/') and fn:exists(doc(functx:substring-before-last($hpath,'/ctl/'))))
		then substring-before($hpath,'/ctl/')
	else $hpath

(: let $user:=xdmp:get-request-field("user")
let $_:=if (fn:empty($user)) then ()
	else xdmp:login($user) :)

return try{
if ($method=('GET','HEAD','OPTIONS')) then
if (fn:empty($path)) then
let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.dir')
return fs-api:amped-list-databases()
else if (fn:empty($docpath) and fn:empty($fieldpath)) then
	let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.dir')
	return object-node {
			"name":$dbname,
			"ident":concat('/fs/',$dbname,'/'),
			"mime":'application/vnd.pigshell.dir',
			"readable":true(),
			"writable":false(),
			"owner":$me,
			"files":array-node {
				object-node {
					"mime":'application/vnd.pigshell.dir',
					"name":"content",
					"ident":concat('/fs/',$dbname,'/content/'),
					"readable":true(),
					"writable":true(),
					"owner":$me
				},
				let $f:=fs-api:amped-list-fields()
				return if ($f/files/*) then object-node {
					"mime":'application/vnd.pigshell.dir',
					"name":"fields",
					"ident":concat('/fs/',$dbname,'/fields/'),
					"readable":true(),
					"writable":false(),
					"owner":$me
				} else ()
			}
		}
else if ($fieldpath=('','/')) then fs-api:amped-list-fields()
else if ($fieldvalueuri) then 
	let $uri:=cts:uris((),"document",cts:field-value-query($fieldname,$fieldvalue,"exact"))[xdmp:integer-to-hex(xdmp:hash64(.))=$fieldvalueuri]
	let $doc:=doc($uri)
	return if ($doc/es:entity) then 
		let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.dir')
		return fs-api:entity-dir($doc/es:entity,$uri,concat('/fs/',$dbname,'/content',$uri,'/'),fs-api:amped-capabilities($uri,$roles),$dbname,$me)
		else
			let $_:=xdmp:add-response-header('Content-Type','text/plain')
			return <a target="_blank" href="{xdmp:get-request-protocol()}://{xdmp:get-request-header("Host")}/fs/{$dbname}/content/{replace($uri,'^/','')}">{{{{name}}}}</a>
else if ($fieldpath=concat('/',$fieldname)) then 
	let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.dir')
	return object-node {
		"mime":'application/vnd.pigshell.dir',
		"name":$fieldname,
		"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/'),
		"readable":true(),
		"writable":false(),
		"owner":$me,
		"files": array-node {
			fs-api:fieldlistfile($fieldname,$dbname),
			object-node {
				"mime":'application/vnd.pigshell.dir',
				"name":'values',
				"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/values/'),
				"readable":true(),
				"writable":false(),
				"owner":$me,
				"count":cts:count-aggregate(cts:field-reference($fieldname),"document")
			}
		}
	}
else if ($fieldpath=concat('/',$fieldname,'/values.txt')) then 
	if ($op='stat') then 
		let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.pstyfile')
		return fs-api:fieldlistfile($fieldname,$dbname)[1]
	else 
		let $_:=xdmp:add-response-header('Content-Type','text/plain')
		return string-join(cts:field-values($fieldname),'&#10;')
else if ($fieldpath=concat('/',$fieldname,'/counts.json')) then 
	if ($op='stat') then 
		let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.pstyfile')
		return fs-api:fieldlistfile($fieldname,$dbname)[2]
	else 
		let $_:=xdmp:add-response-header('Content-Type','application/json')
		return array-node {
				for $i in cts:values(cts:field-reference($fieldname),(),("document","frequency-order","limit=1000000"),()) 
				return object-node {
					"key":fn:encode-for-uri($i),
					"data":cts:frequency($i) 
				} 
		}
else if ($fieldpath=concat('/',$fieldname,'/values/')) then
	let $vv:=cts:field-values($fieldname)
	return object-node {
		"mime":'application/vnd.pigshell.dir',
		"name":'data',
		"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/values/'),
		"readable":true(),
		"writable":false(),
		"owner":$me,
		"count":fn:count($vv),
		"files":array-node {
			for $v in $vv return object-node {
				"mime":'application/vnd.pigshell.dir',
				"count":cts:count($v),
				"name":fn:encode-for-uri($v),
				"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/values/',fn:encode-for-uri($v)),
				"readable":true(),
				"writable":false(),
				"owner":$me
			}
		}
	}
else if ($fieldvalue) then 
	object-node {
		"mime":'application/vnd.pigshell.dir',
		"name":$fieldvalue,
		"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/values/',$fieldvalue,'/'),
		"readable":true(),
		"writable":false(),
		"owner":$me,
		"files":array-node {
			for $uri in cts:uris((),"document",cts:field-value-query($fieldname,$fieldvalue,"exact")) 
				let $doc:=doc($uri)
				let $capabilities:=fs-api:amped-capabilities($uri,$roles)
				let $lm:=fs-api:amped-last-modified($uri,$capabilities)
				let $size:=if ($doc/binary()) then xdmp:binary-size($doc/binary()) else string-length(xdmp:quote($doc,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
				let $mime0:=xdmp:uri-content-type($uri)
				let $mime:=if ($mime0='application/x-unknown-content-type') then if ($doc/text()) then 'text/plain' else if ($doc/object-node()) then 'application/json' else if ($doc/*) then 'text/xml' else if ($doc/binary()) then 'application/octet-stream' else $mime0 else $mime0 
			return object-node {
				"mime":if ($doc/es:entity) then 'application/vnd.pigshell.dir' else $mime,
				"uri":$uri,
				"name":concat(xdmp:integer-to-hex(xdmp:hash64($uri)),'.href'),
				"ident":concat('/fs/',$dbname,'/fields/',$fieldname,'/values/',$fieldvalue,'/',xdmp:integer-to-hex(xdmp:hash64($uri)),'.href'),
				"readable":true(),
				"writable":false(),
				"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000},
				"size":$size,
				"owner":$me
			}
		}
	}
else if (not(fn:ends-with($mapped-hpath,'/')) and fs-api:amped-uri-match($mapped-hpath)) then
	let $doc:=doc($mapped-hpath)
	return if (fn:empty($doc)) then
		let $_:=xdmp:set-response-code(404,"not existant or nonreadable document "||$hpath)
		return ()
	else
	if ($doc/es:entity and $hpath=$mapped-hpath) then
		fs-api:entity-dir($doc/es:entity,$mapped-hpath,$ident,fs-api:amped-capabilities($mapped-hpath,$roles),$dbname,$me)
	else if ($doc/es:entity and ends-with($hpath,'/ctl/')) then
		fs-api:entity-ctl-dir($doc/es:entity,$mapped-hpath,$ident,fs-api:amped-capabilities($mapped-hpath,$roles),$dbname,$me)
	else if ($doc/es:entity and contains($hpath,'/ctl/')) then
		let $_:=xdmp:add-response-header('Content-Type',"text/plain")
		return ()
	else
		let $mime0:=xdmp:uri-content-type($hpath)
		let $mime:=if ($mime0='application/x-unknown-content-type') then if ($doc/text()) then 'text/plain' else if ($doc/object-node()) then 'application/json' else if ($doc/*) then 'text/xml' else if ($doc/binary()) then 'application/octet-stream' else $mime0 else $mime0 
		return if ($op='stat') then 
			let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.pstyfile')
			let $fcapabilities:=fs-api:amped-capabilities($mapped-hpath,$roles)
			let $lm:=fs-api:amped-last-modified($mapped-hpath,$fcapabilities)
			let $size:=if ($doc/binary()) then xdmp:binary-size($doc/binary()) else string-length(xdmp:quote($doc,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
			return object-node {
				"name":fn:tokenize($hpath,'/')[last()],
				"ident":$ident,
				"mime":$mime,
				"owner":$me,
				"uri":$mapped-hpath,
				"size":$size,
				"mtime":number-node{if (fn:empty($lm)) then 0 else $lm div 10000},
				"readable":$fcapabilities='read',
				"writable":$fcapabilities=('update','insert','delete'),
				"executable":$fcapabilities='execute',
				"add-collections":array-node{for $i in xdmp:document-get-collections($mapped-hpath) order by $i return $i},
				"add-permissions":fs-api:amped-document-get-permissions($hpath),
				"set-quality":xdmp:document-get-quality($mapped-hpath),
				"properties":json:object(fs-api:properties-to-json(xdmp:document-properties($mapped-hpath)/*/*))
			}
		else 
		let $_:=xdmp:add-response-header('Content-Type',$mime)
		return if ($doc/es:entity) then xdmp:quote($doc,<options xmlns="xdmp:quote"><indent-untyped>yes</indent-untyped></options>) else $doc
else
	let $_:=xdmp:add-response-header('Content-Type','application/vnd.pigshell.dir')
	return fs-api:dir($hpath,$dbname,$ident,$roles,xdmp:get-request-field('op')='stat')
else if ($method='POST') then
	let $filename:=xdmp:get-request-field("filename")
	let $data0b:=document{xdmp:get-request-field("data")}
	let $data0:=if ($data0b/binary()) then xdmp:binary-decode($data0b/binary(),'utf-8') else $data0b/node()
	let $uri:=concat($hpath,$filename)
	let $mime0:=xdmp:uri-content-type($filename)
	let $data:=document{if (contains($mime0,'xml')) then xdmp:unquote($data0,"format-xml") else if (contains($mime0,'json')) then xdmp:unquote($data0,(),('format-json','repair-full')) else  $data0}
	let $mime:=if ($mime0='application/x-unknown-content-type') then if ($data/text()) then 'text/plain' else if ($data/object-node()) then 'application/json' else if ($data/*) then 'text/xml' else if ($data/binary()) then 'application/octet-stream' else $mime0 else $mime0 
	let $size:=string-length(xdmp:quote($data,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
	return if ($op='put') then
		if (fn:empty($filename) or $filename='') then
			let $_:=xdmp:set-response-code(400,"invalid request")
			return ()
		else if (starts-with($uri,'/') or starts-with($uri,'http:/')) then
			if (ends-with($hpath,'/ctl/')) then
				let $ent as element(es:entity):=doc($mapped-hpath)/es:entity
				let $action:=fs-api:amped-get-entity-action($mapped-hpath,$filename,2)
				let $async:=xdmp:annotation($action,xs:QName("es:async"))
				let $f:=
					if (fn:function-arity($action)=1) then
					function() {
						let $data2 as element(es:entity):=$action($ent)
						return xdmp:document-insert($mapped-hpath,$data2)
					}
					else
					function() {
						let $tp:=xdmp:function-parameter-type($action,2)
						let $arg:=if (contains($tp,'element')) then xdmp:unquote($data0,(),"format-xml")/* else $data0
						let $data2 as element(es:entity):=$action($ent,$arg)
						return xdmp:document-insert($mapped-hpath,$data2)
					}
				let $_:=if ($async) then xdmp:spawn-function($f,<options xmlns="xdmp:eval">
					  <transaction-mode>update-auto-commit</transaction-mode>
					</options>) else $f()
				let $_:=xdmp:set-response-code(204,"no content")
				return ()
			else if ($mapped-hpath ne '/' and doc(remove-end-slash($mapped-hpath))/es:entity) then
				if ($filename='entity.xml') then
					let $canonical as function(*):=fs-api:amped-get-entity-canonical(remove-end-slash($mapped-hpath))
					let $ent:=xdmp:unquote($data0,'format-xml')/es:entity
					let $nent:=$canonical($ent)
					let $_:=xdmp:document-insert(remove-end-slash($mapped-hpath),$nent)
					let $_:=xdmp:set-response-code(201,"Updated")
					let $tm:=fn:current-dateTime()
					return object-node {"owner":$me, "uri":remove-end-slash($mapped-hpath),"ctype":'application/vnd.pigshell.pstyfile',"ident":concat('/fs/',$dbname,$uri),"name":$filename,"readable":true(),"writable":true(),"size":$size,"mime":$mime,"mtime":number-node{xdmp:wallclock-to-timestamp($tm) div 10000}}
				else 
					let $_:=xdmp:set-response-code(404,"unvalid path")
					return ()					
			else
				let $constr:=fs-api:amped-get-entity-constructor($uri)
				return if (fn:empty($constr)) then
						let $_:=xdmp:document-insert($uri,$data)
						let $_:=xdmp:set-response-code(201,"Created")
						let $tm:=fn:current-dateTime()
						return object-node {"owner":$me, "uri":$uri,"ctype":'application/vnd.pigshell.pstyfile',"ident":concat('/fs/',$dbname,$uri),"name":$filename,"readable":true(),"writable":true(),"size":$size,"mime":$mime,"mtime":number-node{xdmp:wallclock-to-timestamp($tm) div 10000}}
					else 
						let $data2:=$constr[1]($uri,$data)
						let $_:=xdmp:document-insert($uri,$data2)
						let $_:=xdmp:set-response-code(201,"Created")
						let $tm:=fn:current-dateTime()
						return object-node {
								"owner":$me,
								"mime":"application/vnd.pigshell.dir",
								"entity":fn:namespace-uri-from-QName(xdmp:function-name($constr[1])), 
								"ident":concat('/fs/',$dbname,$uri),
								"name":$filename,"readable":true(),
								"writable":true(),
								"size":$size,
								"mime":$mime,
								"mtime":number-node{xdmp:wallclock-to-timestamp($tm) div 10000}
							}
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
	else if ($op='chmod') then 
		let $furi:=remove-end-slash($uri)
		return if (fn:exists(doc($furi))) then
			let $data0:=xdmp:get-request-field("data")
			return if (fn:empty($data0)) then 
				let $_:=xdmp:set-response-code(200,"OK")
				let $_:=xdmp:add-response-header('Content-Type','application/json')
				return object-node {
						"name" : fn:tokenize($uri,'/')[last()],
						"add-collections":array-node{xdmp:document-get-collections($furi)},
						"add-permissions":fs-api:amped-document-get-permissions($furi),
						"set-quality":xdmp:document-get-quality($furi)
					}
			else
			let $data:=xdmp:unquote($data0,'format-json')
 			let $_:=if ($data/object-node()) then
				(
					$data//remove-collections!xdmp:document-remove-collections($furi,./data()),
					$data//add-collections!xdmp:document-add-collections($furi,./data()),
					$data//remove-permissions!xdmp:document-remove-permissions($furi,for $k in ./node() for $d in $k/text() return xdmp:permission(name($k),$d)),
					$data//add-permissions!xdmp:document-add-permissions($furi,for $k in ./node() for $d in $k/text() return xdmp:permission(name($k),$d)),
					$data//set-properties!xdmp:document-set-properties($furi,fs-api:properties-fromjson((),.)),
					$data//add-properties!xdmp:document-add-properties($furi,fs-api:properties-fromjson((),.)),
					$data//remove-properties!xdmp:document-remove-properties($furi,xs:QName(string(.))),
					$data//set-quality!xdmp:document-set-quality($furi,.//data())
				)
			else ()
			let $_:=xdmp:set-response-code(204,"No Content")
			return ()
		else 
			let $_:=xdmp:set-response-code(404,"not found")
			return ()
	else if ($op='append') then
		let $x:=doc($hpath)
		let $mime0:=xdmp:uri-content-type($hpath)
		let $mime:=if ($mime0='application/x-unknown-content-type') then if ($x/text()) then 'text/plain' else if ($x/object-node()) then 'application/json' else if ($x/*) then 'text/xml' else if ($x/binary()) then 'application/octet-stream' else $mime0 else $mime0 
		let $size1:=if ($x/binary()) then xdmp:binary-size($x/binary()) else string-length(xdmp:quote($x,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))
		let $_:=if ($mime='text/plain') then xdmp:document-insert($hpath,text{concat(xdmp:quote($x,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>),xdmp:quote($data,<options xmlns="xdmp:quote"><encoding>ISO-8859-1</encoding></options>))}) else xdmp:node-insert-after($x/node()[last()],$data/node())
		return object-node {"owner":$me, "ctype":'application/vnd.pigshell.pstyfile',"ident":$ident,"name":fn:tokenize($hpath,'/')[last()],"readable":true(),"writable":true(),"size":$size+$size1,"mime":$mime,
			"mtime":number-node{xdmp:request-timestamp() div 10000}}
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
} catch ($ex) {
	xdmp:set-response-code(500,$ex//error:message/string()),
	$ex
}

};


declare private function fs-api:properties-fromjson($name as xs:string?,$a) {
  typeswitch($a)
  case object-node() return if ($name) then element{$name}{$a/node()!fs-api:properties-fromjson(name(.),.)} else $a/node()!fs-api:properties-fromjson(name(.),.)
  case array-node() return $a/node()!element{$name}{fs-api:properties-fromjson((),.)}
  case null-node() return if ($name) then element{$name}{attribute xsi:nil {true()}} else attribute xsi:nil {true()}
  case text() return if ($name) then element{$name}{$a} else $a
  case item() return if ($name) then element{$name}{attribute xsi:type {'xs:'||xdmp:type($a)},string($a)} else (attribute xsi:type {'xs:'||xdmp:type($a)},string($a))
  default return $a
};

declare private function fs-api:property-tojson($name as xs:string?,$a as item(),$at as item()*) {
  typeswitch($a)
  case element() return if ($name) then <json:entry key="{$name}">{
    if ($a/*) then <json:value>{fs-api:properties-to-json($a/node())}</json:value>
    else if ($a/node()) then $a/node()!fs-api:property-tojson((),.,($at,./@*))
    else <json:value xsi:nil="true"/>}
   </json:entry>
    else <json:value>{$at,$a/node()!fs-api:property-tojson((),.,./@*)}</json:value>
  case text() return <json:value>{$at,$a}</json:value>
  default return $a
};

declare private function fs-api:properties-tojson($a as map:map) {
  <json:object>{for $k in map:keys($a)
    let $v as item()*:=map:get($a,$k)
     order by $k
    return if (fn:count($v)=1) then fs-api:property-tojson($k,$v,$v/@*) else 
      <json:entry key="{$k}"><json:value><json:array>{$v!fs-api:property-tojson((),./node(),./@*)}</json:array></json:value></json:entry>
  }</json:object>
};
declare private function fs-api:properties-to-json($x as element()*) {
  fs-api:properties-tojson(fn:fold-left(function($acc,$i){$acc+map:entry(name($i),$i)}, map:new(), $x))
};



