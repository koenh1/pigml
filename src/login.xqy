let $user :=
  if (fn:empty(xdmp:get-request-field("user")))
  then xdmp:get-session-field("user")
  else xdmp:get-request-field("user")
let $password :=
  if (fn:empty(xdmp:get-request-field("password")))
  then xdmp:get-session-field("password")
  else xdmp:get-request-field("password")
let $remember as xs:boolean :=
  if (fn:empty(xdmp:get-request-field("user")))
  then
    if (fn:empty(xdmp:get-session-field("remember")))
    then false()
    else xdmp:get-session-field("remember")
  else
    xdmp:get-request-field("remember") = "on"
let $action := xdmp:get-request-field("action")
let $_ := xdmp:set-response-content-type("text/html")
return
  try {
    if (fn:empty($user) or fn:empty($password) or
        $action = "logout" or
        not(xdmp:login($user, $password, true())))
    then
      let $_ := xdmp:set-response-code(401, "Please log in")
      return
        <html>
		<head><title>Login</title>
		<style><![CDATA[
form {
    border: 3px solid #f1f1f1;
}

/* Full-width inputs */
input[type=text], input[type=password] {
    width: 100%;
    padding: 12px 20px;
    margin: 8px 0;
    display: inline-block;
    border: 1px solid #ccc;
    box-sizing: border-box;
}

/* Set a style for all buttons */
button {
    background-color: #4CAF50;
    color: white;
    padding: 14px 20px;
    margin: 8px 0;
    border: none;
    cursor: pointer;
    width: 100%;
}

/* Extra style for the cancel button (red) */
.cancelbtn {
    width: auto;
    padding: 10px 18px;
    background-color: #f44336;
}

/* Center the avatar image inside this container */
.imgcontainer {
    text-align: center;
    margin: 24px 0 12px 0;
}

/* Avatar image */
img.avatar {
    width: 40%;
    border-radius: 50%;
}

/* Add padding to containers */
.container {
    padding: 16px;
}

/* The "Forgot password" text */
span.psw {
    float: right;
    padding-top: 16px;
}

/* Change styles for span and cancel button on extra small screens */
@media screen and (max-width: 300px) {
    span.psw {
        display: block;
        float: none;
    }
    .cancelbtn {
        width: 100%;
    }
}]]></style>
		</head>
		<body>
			<form method="POST" action="login">
			  <div class="imgcontainer">
			    <img src="/static/orion/images/avatar.png" alt="Avatar" class="avatar"/>
			  </div>

			  <div class="container">
			    <label><b>Username</b></label>
			    <input type="text" placeholder="Enter Username" name="user" value="{if ($remember) then $user else ()}" required="1"/>

			    <label><b>Password</b></label>
			    <input type="password" placeholder="Enter Password" value="{if ($remember) then $password else ()}" name="password" required="1"/>

			    <button type="submit">Login</button>
			    <input type="checkbox" name="remember">{if ($remember) then attribute checked {'1'} else ()}</input> Remember me
			  </div>

			  <div class="container" style="background-color:#f1f1f1">
			    <button type="button" class="cancelbtn">Cancel</button>
			    <span class="psw">Forgot <a href="#">password?</a></span>
			  </div>
			</form>
		</body>
	</html>
    else
      let $_ :=
        if ($user = xdmp:get-request-field("user"))
        then
          (xdmp:set-session-field("remember", $remember),
           xdmp:set-session-field("user", $user),
           xdmp:set-session-field("password", $password))
        else
          ()
      return
        <html>
		<head><title>Login</title></head>
		<body>
		You are logged in as {xdmp:get-current-user()}<br/>
		<a href="?action=logout">Log in as a different user</a>
		</body>
	</html>
  } catch ($ex) {
    $ex
  }
  