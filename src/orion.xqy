import module namespace orion-api="http://marklogic.com/lib/xquery/orion-api" at "/lib/orion-api.xqy"; 

let $user:=xdmp:get-request-field('user')
let $me:=xdmp:get-current-user()

return try{if (fn:empty($user) or $me=$user) then orion-api:main()
else xdmp:invoke-function(orion-api:main#0,<options xmlns="xdmp:eval"><user-id>{xdmp:user($user)}</user-id></options>)
} catch($ex) {
	(xdmp:set-response-code(200,'Server error'),$ex)
}
