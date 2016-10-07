import module namespace fs-api="http://marklogic.com/lib/xquery/fs-api" at "/lib/fs-api.xqy"; 

let $user:=xdmp:get-request-field('user')
let $me:=xdmp:get-current-user()

return if (fn:empty($user) or $me=$user) then fs-api:main()
else xdmp:invoke-function(fs-api:main#0,<options xmlns="xdmp:eval"><user-id>{xdmp:user($user)}</user-id></options>)
