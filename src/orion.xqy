import module namespace orion-api="http://marklogic.com/lib/xquery/orion-api" at "/lib/orion-api.xqy";

let $user :=
  if (fn:empty(xdmp:get-request-field("user")))
  then xdmp:get-session-field("user")
  else xdmp:get-request-field("user")
let $password :=
  if (fn:empty(xdmp:get-request-field("password")))
  then xdmp:get-session-field("password")
  else xdmp:get-request-field("password")
let $action := xdmp:get-request-field("action")
let $_ := xdmp:set-response-content-type("text/html")
return
  try {
    if (fn:empty($user) or fn:empty($password) or
        not(xdmp:login($user, $password, true())))
    then xdmp:redirect-response("/login")
    else
      let $_ :=
        xdmp:add-response-header(
          "X-ML-User", xdmp:get-current-user())
      return orion-api:main()
  } catch ($ex) {
    xdmp:set-response-code(200, "Server error"), $ex
  }
 