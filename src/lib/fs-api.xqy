xquery version "1.0-ml";
module namespace fs-api="http://marklogic.com/lib/xquery/fs-api"; 


import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module "http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

declare namespace fs="http://marklogic.com/xdmp/status/forest";
declare namespace prop="http://marklogic.com/xdmp/property";


declare function fs-api:amped-roles() as xs:unsignedLong* {
	xdmp:invoke-function(function(){sec:get-role-ids(sec:user-get-roles(xdmp:get-current-user()))}, <options xmlns="xdmp:eval"><database>{xdmp:security-database()}</database></options>)/data()
};

declare function fs-api:amped-capabilities($uri as xs:string,$roles as xs:unsignedLong*) as xs:string* {
	let $admin:=xdmp:invoke-function(function(){sec:get-role-ids('admin')}, <options xmlns="xdmp:eval"><database>{xdmp:security-database()}</database></options>)/data()
	return if ($admin=$roles) then ('read','update','insert','delete','execute') else xdmp:document-get-permissions($uri)[sec:role-id=$roles]//sec:capability/string()
};

declare function fs-api:amped-uri-match($pattern as xs:string) as xs:string* {
	cts:uri-match($pattern)
};

declare private function fs-api:find-uri-privilege-impl($uri as xs:string) as xs:boolean {
	try{xdmp:has-privilege($uri,'uri')} catch($ex){false()}
};

declare function fs-api:find-uri-privilege($uri as xs:string) as xs:boolean {
	if (string-length($uri)=0) then false() else
	let $r:=fs-api:find-uri-privilege-impl($uri)
	return if ($r=true()) then $r else if ($uri!='/') then fs-api:find-uri-privilege(concat(string-join(fn:tokenize($uri,'/')[1 to last()-2],'/'),'/'))
	else false()
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
