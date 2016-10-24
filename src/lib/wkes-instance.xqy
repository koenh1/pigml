xquery version "1.0-ml";

module namespace wkes-instance="http://www.wolterskluwer.com/schemas/appollo/entity/instance/v1.1"; 
declare namespace wkes="http://www.wolterskluwer.com/schemas/appollo/entity/v1.1"; 

import module namespace wkes-catalog='http://www.wolterskluwer.com/schemas/appollo/entity/catalog/v1.1' at '/entity-schemas/catalog.xqy';
import module namespace inst = "http://marklogic.com/entity-services-instance" at "/MarkLogic/entity-services/entity-services-instance.xqy";

declare option xdmp:mapping "false";

declare function wkes-instance:is-instance($uri as xs:string) as xs:boolean {
	fn:count(wkes-catalog:catalog($uri))=1
};

declare function wkes-instance:create-instance($uri as xs:string,$node as node()) {
	wkes-instance:create-instance($uri,$node,fn:false()) 
};

declare function wkes-instance:valid-events($uri as xs:string) as xs:string* {
	let $d:=doc($uri)
	return if (fn:empty($d)) then () 
	else wkes-instance:valid-events($d,$uri)
};

declare function wkes-instance:valid-events($doc as document-node(),$uri as xs:string) as xs:string* {
	let $mod as element(module)?:=wkes-catalog:catalog($uri)
	return if (fn:empty($mod)) then ()
	else
	let $script:=<code>
	import module namespace m="{string($mod/@namespace)}" at "{string($mod/@at)}";
	m:valid-events#1
	</code>/string()
	let $f:=xdmp:eval($script)
	return $f($doc)
};

declare function wkes-instance:instance-json-from-document($doc as document-node()) as object-node() {
	inst:instance-json-from-document($doc)
};

declare function wkes-instance:instance-xml-from-document($doc as document-node()) as element()* {
	inst:instance-xml-from-document($doc)
};

declare function wkes-instance:create-instance($uri as xs:string,$node as node(),$overwrite as xs:boolean) as document-node() {
	if ($overwrite=false() and fn:exists(doc($uri))) then fn:error(xs:QName('overwrite'),$uri)
	else
	let $mod as element(module):=wkes-catalog:catalog($uri)
	let $script:=<code>
	import module namespace m="{string($mod/@namespace)}" at "{string($mod/@at)}";
	m:create-{string($mod/@name)}-envelope#1
	</code>/string()
	let $f:=xdmp:eval($script)
	let $envelope as document-node():=$f($node)
	let $_:=xdmp:document-insert($uri,$envelope,xdmp:default-permissions(),(concat('/entities/',$mod/@name),xdmp:default-permissions()))
	return $envelope
};

declare private function wkes-instance:get-timestamp($uri as xs:string) as xs:unsignedLong {
	xdmp:eval("declare variable $uri as xs:string external;xdmp:document-timestamp($uri)",(xs:QName('uri'),$uri),<options xmlns="xdmp:eval">
	<isolation>different-transaction</isolation>			
	<transaction-mode>query</transaction-mode>
	<prevent-deadlocks>true</prevent-deadlocks>
    </options>)
};

declare function wkes-instance:invoke-event($uri as xs:string,$event as xs:string,$argument as item()?) as document-node()? {
	let $mod as element(module):=wkes-catalog:catalog($uri)
	let $evt as element(event):=$mod/event[@name=$event]
	let $arg:=if (fn:matches($evt/@argument,'^[\w]+$')) then 
		$argument 
	else if ($argument instance of element()) then $argument 
	else if ($argument castable as xs:string) then xdmp:unquote($argument)/node() else $argument
	let $script:=<code>
	import module namespace m="{string($mod/@namespace)}" at "{string($mod/@at)}";
	(m:{$event}#{if ($evt/@argument) then 2 else 1}{if (fn:matches($evt/@argument,'^[\w]+$')) then concat(',xs:',$evt/@argument,'#1') else ()})
	</code>/string()
	let $f:=xdmp:eval($script)
	let $async:=xdmp:annotation($f[1],xs:QName('wkes:async'))
	return if ($async) then
		 xdmp:spawn-function(function() {
			let $envelope as document-node():=if (fn:count($f)=2) then $f[1](doc($uri),$f[2]($arg)) else if (fn:function-arity($f)=1) then $f(doc($uri)) else $f(doc($uri),$arg)
			return xdmp:node-replace(doc($uri),$envelope)
		},<options xmlns="xdmp:eval"><transaction-mode>update-auto-commit</transaction-mode></options>)
	else
		let $envelope as document-node():=if (fn:count($f)=2) then $f[1](doc($uri),$f[2]($arg)) else if (fn:function-arity($f)=1) then $f(doc($uri)) else $f(doc($uri),$arg)
		let $_:=xdmp:node-replace(doc($uri),$envelope)
		return $envelope
};

