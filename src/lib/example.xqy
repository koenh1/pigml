xquery version "1.0-ml";
module namespace ex="http://www.wolterskluwer.com/ns/appollo/marklogic/entity/example";
import module namespace message="http://marklogic.com/entity-services/test#Message-0.0.4" at "/entity-schemas/message-model.xqy";

declare private function array-with($a as json:array?,$item as item()) as json:array {
  if (fn:empty($a)) then array-node {$item} else
  let $_:=json:array-push($a,$item)
  return $a
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

declare function ex:create($node as node()) as object-node() {
	object-node {
		"id":"test",
		"subject":string($node),
		"sender":"me"
	}
};


declare function ex:add-receiver($instance as map:map,$attachments as map:map,$triples as map:map,$arg as element(address)) as xs:string* {
	let $_:=map:put($instance,'receiver',array-with(map:get($instance,'receiver'),$arg/data()))
	return if (map:contains($instance,'subject') and map:contains($instance,'receiver')) then 'ready' else ()
};

declare function ex:add-attachment($instance as map:map,$attachments as map:map,$triples as map:map,$arg as xs:base64Binary) as xs:string* {
	let $_:=map:put($instance,'attachments',array-with(map:get($instance,'attachments'),json:object()!map-with(.,"$type","Attachment")!map-with(.,"data",$arg)!map-with(.,"name","attachment")))
	return if (map:contains($instance,'subject') and map:contains($instance,'receiver')) then 'ready' else ()
};

declare function ex:add-message($instance as map:map,$attachments as map:map,$triples as map:map,$arg as element(message)) as xs:string* {
	let $_:=map:put($instance,'message',array-with(map:get($instance,'message'),$arg/data()))
	return if (map:contains($instance,'subject') and map:contains($instance,'receiver')) then 'ready' else ()
};

declare function ex:set-subject($instance as map:map,$attachments as map:map,$triples as map:map,$arg as xs:string) as xs:string* {
	let $_:=map:put($instance,'subject',$arg)
	return if (map:contains($instance,'subject') and map:contains($instance,'receiver')) then 'ready' else ()
};

declare function ex:send($data as map:map,$triples as map:map,$attachments as map:map) as xs:string* {
	let $_:=xdmp:sleep(60000)
	return 'sent'
};
