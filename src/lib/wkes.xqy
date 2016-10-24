xquery version "1.0-ml";

module namespace wkes="http://www.wolterskluwer.com/schemas/appollo/entity/v1.1"; 
import module namespace es = "http://marklogic.com/entity-services" at "/MarkLogic/entity-services/entity-services.xqy"; 
import module namespace esi = "http://marklogic.com/entity-services-impl" at "/MarkLogic/entity-services/entity-services-impl.xqy";
import module namespace inst = "http://marklogic.com/entity-services-instance" at "/MarkLogic/entity-services/entity-services-instance.xqy";
declare option xdmp:mapping "false";

declare private function wkes:datatype($s as xs:string?) as xs:string {
  if (empty($s)) then 'empty-sequence()' else if (contains($s,'(')) then $s else concat('xs:',$s)
};
declare private function wkes:arg($s) as xs:string {
  if (empty($s)) then '' else concat(',$argument as ',wkes:datatype($s[1]))
};
declare private function wkes:match($wf as element(wkes:work-flows)) as xs:string* {
  for $dir in $wf/wkes:directory 
  let $modeld:=doc(resolve-uri($wf/@model,base-uri($wf)))/es:model
  let $name:=name($modeld//es:definitions/*[1])
  let $model:=es:model-validate($modeld)
    let $info := map:get($model, "info")
    let $title := map:get($info, "title")
    let $prefix := lower-case(substring($title,1,1)) || substring($title,2)
    let $version:= map:get($info, "version")
    let $base-uri := esi:resolve-base-uri($info)
  let $code:=(
  if ($dir/@depth=1) then
  <code>
    if (fn:matches($uri,"^{string($dir/@href)}[^/]*$")) then
  </code>
  else
  <code>
    if (fn:starts-with($uri,"{string($dir/@href)}")) then
  </code>,
  <code>
    element module {{ attribute name {{ "{$name}" }}, attribute namespace {{"{$base-uri}{$title}-wf-{$version}"}}, attribute at {{"{substring-before(base-uri($wf),'.')}.xqy"}}
      {
          for $action at $pos in fn:distinct-values($wf//wkes:event/@action)
            let $actions:=$wf//wkes:event[@action=$action]
          return (<code>, element event {{attribute name {{"{$action}"}}</code>,fn:distinct-values($actions/@argument-type)!(<code>,attribute argument {{"{.}"}} </code>),<code> }}</code>)
      }
    }}
  </code>
  )
  return string-join($code/string(),'&#10;')
};
declare private function wkes:code($wf as element(wkes:work-flows)) as xs:string {
  let $imports:=map:new(for $import in $wf/wkes:import-module
	  let $script:=fn:string-join(("import module namespace ",$import/@prefix,"=""",$import/@namespace,""" at """,$import/@href,""";","for $i in xdmp:functions() where fn:namespace-uri-from-QName(fn:function-name($i))=""",$import/@namespace,""" and fn:function-available(concat('",$import/@prefix,":',fn:local-name-from-QName(fn:function-name($i))),fn:function-arity($i)) return $i"),"")
	  return xdmp:eval($script)!map:entry(fn:local-name-from-QName(fn:function-name(.)),.))
  let $modeld:=doc(resolve-uri($wf/@model,base-uri($wf)))/es:model
  let $name:=name($modeld//es:definitions/*[1])
  let $model:=es:model-validate($modeld)
    let $info := map:get($model, "info")
    let $title := map:get($info, "title")
    let $prefix := lower-case(substring($title,1,1)) || substring($title,2)
    let $version:= map:get($info, "version")
    let $base-uri := esi:resolve-base-uri($info)
  let $code:=<code>
module namespace {$prefix}-wf="{$base-uri}{$title}-wf-{$version}";
import module namespace {$prefix}="{$base-uri}{$title}-{$version}" at "{substring-before(base-uri($modeld),'.')}.xqy";
import module namespace es = "http://marklogic.com/entity-services" at "/MarkLogic/entity-services/entity-services.xqy"; 
import module namespace inst = "http://marklogic.com/entity-services-instance" at "/MarkLogic/entity-services/entity-services-instance.xqy";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";
import schema default element namespace "" at "{substring-before(base-uri($modeld),'.')}.xsd";
{
for $import in $wf/wkes:import-module
return <code>import module namespace {string($import/@prefix)}="{string($import/@namespace)}" at "{string($import/@href)}";</code>
}
declare namespace wkes="http://www.wolterskluwer.com/schemas/appollo/entity/v1.1"; 
declare option xdmp:mapping "false";

declare variable ${$prefix}-wf:model as json:object:=xdmp:unquote('{xdmp:quote($model)}');
(: TODO update this :)
declare private function array-with($a as json:array,$item as item()) as json:array {{
	let $_:=json:array-push($a,$item)
	return $a
}};
declare private function map-with(
    $map as map:map,
    $key-name as xs:string,
    $value as item()
) as map:map
{{
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
}};
declare function {$prefix}-wf:create-{$name}($node as node()) as map:map {{
  {
    if (map:contains($imports,'create')) then 
    <code>{map:get($imports,'create')!fn:function-name(.)}($node)!map-with(.,'$type','{$title}')</code>
    else
   <code>{$prefix}:extract-instance-{$name}(es:model-get-test-instances(es:model-validate(doc('{base-uri($modeld)}')/es:model))[1])</code>
  }
}};

declare function {$prefix}-wf:validate-envelope($document as document-node()) as document-node() {{
  let $_:=validate {{ inst:instance-xml-from-document($document) }} (:todo validate state,etc :)
  return $document
}};

declare function {$prefix}-wf:validate-instance($map as map:map) as element({$title}) {{
  validate {{ {$prefix}:instance-to-canonical-xml($map) }}
}};

declare private function {$prefix}-wf:create-document($inst as map:map,$attachments as map:map,$triples as map:map,$states as map:map) as document-node() {{
  let $_:=map:put($inst,'$attachments',(map:keys($attachments)!(element wkes:attachment{{attribute uri {{.}},map:get($attachments,.)}}),
    map:keys($states)!(element wkes:state {{ attribute work-flow{{.}},attribute state {{map:get($states,.)}}}}),
    map:keys($triples)!(element wkes:triples{{attribute role {{.}},map:get($triples,.)}})))
  return {$prefix}:instance-to-envelope($inst)
}};

declare function {$prefix}-wf:create-{$name}-envelope($node as node()) as document-node() {{
  let $inst as map:map:={$prefix}-wf:create-{$name}($node)
  return {$prefix}-wf:create-document($inst,map:new(),map:new(),map:new(({string-join($wf/wkes:work-flow!concat('map:entry("',./@name,'","',./@initial-state,'")'),',')})))
}};

declare function {$prefix}-wf:valid-events($doc as document-node()) as xs:string* {{
  {$prefix}-wf:valid-events-impl(map:new(es:instance-get-attachments($doc)[self::wkes:state]!map:entry(./@work-flow,./@state)))
}};

declare function {$prefix}-wf:valid-events-impl($states as map:map) as xs:string* {{
  {string-join($wf/wkes:work-flow!concat('let $',./@name,':=map:get($states,"',./@name,'")'),'&#10;  ')}
  return (
  {
   for $w at $i in $wf/wkes:work-flow return
   <code>
   {if ($i!=1) then ',' else ()}
   switch (${string($w/@name)})
   {
     for $s in $w/wkes:state
     return <code>
     case '{string($s/@name)}' return 
       {
         if (empty($s/wkes:event)) then '()' else
         concat('(',
         string-join(for $e at $i in $s/wkes:event return
         (
         if ($i!=1) then ',' else (),
         for $g in $e/wkes:guard 
         let $gg:=$wf//wkes:state[@name=$g/@state]
         return 
         concat('if (',if ($g/@invert='true') then 'not' else '','($',$gg/ancestor::wkes:work-flow/@name,'="',$g/@state,'")) then ')
         ,
         concat('"',$e/@action/string(),'"'),
         for $g in $e/wkes:guard return ' else () '
         ),
         ''),') ')
       }
     </code>
   }
     default return fn:error(xs:QName('state'),'invalid state '||${string($w/@name)})
   </code>
  })
}};

{
  for $action in fn:distinct-values($wf//wkes:event/@action)
  let $actions:=$wf//wkes:event[@action=$action]
  let $workflows:=$actions/ancestor::wkes:work-flow
  let $f:=map:get($imports,$action)
  let $function:=if (fn:empty($f)) then concat($prefix,'-wf:',$action,'-template') else string(fn:function-name($f))
  let $targets:=for $a in $actions return if ($a/wkes:target) then $a/wkes:target/@state else $a/ancestor::wkes:work-flow//wkes:state/@name
  return (
if (fn:empty($f)) then <code>
(:update instance and return optional new state (one of {string-join(distinct-values($targets),',')}) :)
declare function {$prefix}-wf:{$action}-template($entity-instance as map:map,$attachments as map:map,$triples as map:map{wkes:arg($actions/@argument-type[1])}) as xs:string* {{
   {
   let $rand as xs:int:=1+xdmp:random(count(distinct-values($targets/string()))-1)
   return concat("let $_:=map:delete($entity-instance,'sent') ","let $_:=map:put($attachments,'",$action,"','",$action,"')"," let $_:=map:put($triples,'",$action,"',sem:triple('a','b','",$action,"'))",' return ("',string-join(distinct-values($targets),'","'),'")',if (count(distinct-values($targets)) gt 1) then concat('[',$rand,']') else ())
   }
 }};
</code> else (),
<code>
declare {if ($actions/@async='true') then '%wkes:async' else ()} function {$prefix}-wf:{$action}($document as document-node(){wkes:arg($actions/@argument-type[1])}) as document-node() {{
  let $d as map:map:={$prefix}:extract-instance-{$name}($document/es:envelope/es:instance)
  let $_:=map:delete($d,'$attachments')
  let $att:=inst:instance-get-attachments($document)
  let $states as map:map*:=($att[self::wkes:state]!map:entry(./@work-flow,./@state))
  let $valid-events:={$prefix}-wf:valid-events-impl(map:new($states))
  return if ($valid-events[.='{$action}']) then
  let $attachments:=map:new($att[self::wkes:attachment]!map:entry(./@uri,(./@* except @uri,./node())))
  let $triples:=map:new($att[self::wkes:triples]!map:entry(./@role,.//sem:triple))
  let $newstates:={$function}($d,$attachments,$triples{if ($actions/@argument-type) then ',$argument' else ()})
  let $newstate:=map:new(($states,for $s in $newstates return
    switch($s)
    {for $s in $targets return
    concat('case "',$s,'" return map:entry("',$s/ancestor::wkes:work-flow/@name,'","',$s,'")')
    }
    default return fn:error('error','unexpected state '||$s)))
   return {$prefix}-wf:create-document($d,$attachments,$triples,$newstate)
   else fn:error(xs:QName('state'),'unexpected event "{$action}", expecting one of actions'||xdmp:describe($valid-events))
}};
  </code>)
}
  </code>
  return $code/string()
};

declare function wkes:compile-catalog() {
  let $code:=concat(
    "module namespace wkes-catalog='http://www.wolterskluwer.com/schemas/appollo/entity/catalog/v1.1';&#10;",
    "declare function wkes-catalog:catalog($uri as xs:string) as element(module)? { &#10;",
    string-join(
    for $wf in //wkes:work-flows
      return wkes:match($wf)," else "),
    " else ()&#10;};&#10;"
  )
  let $uri:='/entity-schemas/catalog.xqy'
  return ($uri,$code,xdmp:invoke-function(function(){xdmp:document-insert($uri,text{$code})},<options xmlns="xdmp:eval"><transaction-mode>update-auto-commit</transaction-mode><database>{xdmp:modules-database()}</database></options>))
};

declare function wkes:compile-work-flows() {
  for $wf in //wkes:work-flows
    let $code:=wkes:code($wf)
    let $uri:=concat(substring-before(base-uri($wf),'.'),".xqy")
    return ($uri,$code,xdmp:invoke-function(function(){xdmp:document-insert($uri,text{$code})},<options xmlns="xdmp:eval"><database>{xdmp:modules-database()}</database><transaction-mode>update-auto-commit</transaction-mode></options>))
};

declare function wkes:compile-models() {
  for $modeld in //es:model
    let $model:=es:model-validate($modeld)
    let $inst:=es:model-get-test-instances($model)
    let $code:=es:instance-converter-generate($model)
    let $schema:=es:schema-generate($model)
    let $uri:=concat(substring-before(base-uri($modeld),'.'),'.xqy')
    let $uri2:=concat(substring-before(base-uri($modeld),'.'),'.xsd')
    return ($uri,
      xdmp:invoke-function(function(){xdmp:document-insert($uri,text{$code})},<options xmlns="xdmp:eval"><transaction-mode>update-auto-commit</transaction-mode><database>{xdmp:modules-database()}</database></options>),
      xdmp:invoke-function(function(){xdmp:document-insert($uri2,$schema)},<options xmlns="xdmp:eval"><transaction-mode>update-auto-commit</transaction-mode><database>{xdmp:schema-database()}</database></options>))
};


declare function wkes:compile() {
  (wkes:compile-models(),
  wkes:compile-work-flows(),
  wkes:compile-catalog())
};
