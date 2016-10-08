xquery version "1.0-ml";
module namespace ex="http://www.wolterskluwer.com/ns/appollo/marklogic/entity/example";

declare function ex:canonical($data as map:map,$triples as map:map,$attachments as map:map) as map:map {
	map:new((
		if (map:contains($data,'subject')) then map:entry('title',map:get($data,'subject'))
		else map:entry('title','untitled message')
	))
};

declare function ex:create-message($sender as element(address),$data as map:map,$triples as map:map,$attachments as map:map) as empty-sequence() {
	map:put($data,'sender',$sender/data())
};

declare function ex:create-message-from-subject($subject as xs:string,$data as map:map,$triples as map:map,$attachments as map:map) as empty-sequence() {
	map:put($data,'subject',$subject)
};

declare function ex:add-receiver($receiver as element(address),$data as map:map,$triples as map:map,$attachments as map:map) as xs:string* {
	let $_:=map:put($data,'receiver',(map:get($data,'receiver'),$receiver/data()))
	return if (map:contains($data,'subject') and map:contains($data,'message')) then 'ready' else ()
};

declare function ex:add-message($message as element(message),$data as map:map,$triples as map:map,$attachments as map:map) as xs:string* {
	let $_:=map:put($data,'message',(map:get($data,'message'),$message/data()))
	return if (map:contains($data,'subject') and map:contains($data,'receiver')) then 'ready' else ()
};

declare function ex:set-subject($subject as xs:string,$data as map:map,$triples as map:map,$attachments as map:map) as xs:string* {
	let $_:=map:put($data,'subject',$subject)
	return if (map:contains($data,'message') and map:contains($data,'receiver')) then 'ready' else ()
};

declare function ex:send($data as map:map,$triples as map:map,$attachments as map:map) as xs:string* {
	'sent'
};
