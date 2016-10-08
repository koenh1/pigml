<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:x="http://www.wolterskluwer.com/schemas/appollo/entity/v1.0">
	<xsl:output method="text"/>
	<xsl:key match="x:data-type" name="data-type" use="@name"/>
	<xsl:key match="x:data-type[@type]" name="simple-type" use="@name"/>
	<xsl:key match="x:data-type[not(@type)]" name="complex-type" use="@name"/>
	<xsl:key name="state" match="x:state" use="@name"/>
	<xsl:key name="action" match="x:action" use="@name"/>

	<xsl:template match="x:entity-schema"/>

	
	
	<xsl:template match="x:entity-type">
		<xsl:variable name="name" select="@name"/>
		<xsl:for-each select="ancestor::x:entity-schema">
xquery version "1.0-ml";
module namespace ent= "<xsl:value-of select="@namespace"/>#<xsl:value-of select="$name"/>";
declare namespace error="http://marklogic.com/xdmp/error";
declare namespace es="http://marklogic.com/entity-services";
declare namespace state="http://www.wolterskluwer.com/ns/appollo/state/1.0";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";
<xsl:for-each select=".//x:schema[@namespace]|.//x:any-xml[@namespace]">
declare namespace x<xsl:value-of select="count(preceding::*/@namespace)"/>="<xsl:value-of select="@namespace"/>";
</xsl:for-each>
		<xsl:apply-templates select="x:imports/x:module"/>
declare variable $directories as xs:string*:=(<xsl:text/>
<xsl:for-each select="x:entities/x:entity-type">
	<xsl:if test="position()!=1">,</xsl:if>
	<xsl:text>'</xsl:text>
	<xsl:value-of select="@directory"/>
	<xsl:text>'</xsl:text>
</xsl:for-each>);
<xsl:variable name="simple-constructors" select=".//x:constructor[key('simple-type',@argument-type)]"/>
<xsl:variable name="complex-constructors" select=".//x:constructor[key('complex-type',@argument-type)]"/>
declare function ent:generic-create-from-doc($uri as xs:string,$doc as document-node()) as element(es:entity) {
	let $asxml as element()?:=try{if ($doc/*) then $doc/* else xdmp:unquote($doc,(),'format-xml')/*}catch($ex){()}
	return if (fn:empty($asxml)) then
		<xsl:for-each select="$simple-constructors">
			if (string($doc/text()) castable as <xsl:value-of select="key('simple-type',@argument-type)/@type"/>) then 
				ent:<xsl:value-of select="@name"/>($uri,<xsl:value-of select="key('simple-type',@argument-type)/@type"/>(string($doc/text())))
			else
		</xsl:for-each>
		ent:error('unexpected-content',xdmp:describe($doc))
	else 
		typeswitch($asxml)
		<xsl:for-each select="$complex-constructors">
			case element(<xsl:apply-templates select="key('complex-type',@argument-type)" mode="qname"/>) return 
				ent:<xsl:value-of select="@name"/>($uri,$asxml)
		</xsl:for-each>
			default return ent:error('unexpected-content',xdmp:describe($asxml))
};

		</xsl:for-each>
	
		<xsl:apply-templates select="x:canonizer"/>
		<xsl:apply-templates select="x:constructors/x:constructor"/>
		<xsl:apply-templates select="x:actions/x:action"/>
		<xsl:apply-templates select="." mode="valid-events"/>

declare private function ent:error($name as xs:string,$message as item()*) {
	fn:error(fn:QName("http://marklogic.com/entity-services",$name),string-join($message!string(.)))
};

declare private function ent:has-role($names as xs:string*) as xs:boolean {
	let $me:=xdmp:get-current-user()
	let $admin:=xdmp:role('admin')
	let $myroles:=xdmp:user-roles($me)
	return if ($myroles=$admin) then true()
	else
	let $requiredroles:=$names!xdmp:role(.)
	return if ($requiredroles[.=$myroles]) then true()
	else false()
};
declare private function ent:role-assert($names as xs:string*) {
	if (ent:has-role($names)) then ()
	else ent:error('security',string-join(('required one of ',$names),' '))
};

	</xsl:template>
	<xsl:template match="x:data-type" mode="qname">
		<xsl:apply-templates mode="qname"/>
	</xsl:template>
	<xsl:template match="x:any-xml|x:schema" mode="qname">
		<xsl:if test="@namespace">
			<xsl:text>x:</xsl:text>
			<xsl:value-of select="count(preceding::*/@namespace)"/>
		</xsl:if>
		<xsl:value-of select="@element"/>
	</xsl:template>

	<xsl:template match="x:module">
import module namespace <xsl:value-of select="@name"/>="<xsl:value-of select="@namespace"/>" at "<xsl:value-of select="@at"/>";
</xsl:template>

<xsl:template match="x:entity-type" mode="valid-events">
declare function ent:valid-events($ent as element(es:entity)) as xs:string* {
	ent:valid-events-impl(map:new($ent/es:states/state:state!map:entry(./@fsm,@name)))
};
declare private function ent:valid-states($ent as element(es:entity),$event as xs:string) as xs:string* {
	ent:valid-states-impl(map:new($ent/es:states/state:state!map:entry(./@fsm,@name)),$event)
};
declare private function ent:update-states($state as map:map,$newstates as xs:string*) as map:map {
	let $_:=for $s in $newstates
	return switch($s)
	<xsl:for-each select=".//x:state">
	case '<xsl:value-of select="@name"/>' return map:put($state,'<xsl:value-of select="ancestor::x:state-machine/@name"/>',$s)
	</xsl:for-each>
	default return ()
	return $state
};
declare private function ent:valid-events-impl($states as map:map) as xs:string* {
	<xsl:for-each select="x:state-machine">
		let $<xsl:value-of select="@name"/>:=map:get($states,'<xsl:value-of select="@name"/>')
	</xsl:for-each>
	return (<xsl:apply-templates select="x:state-machine" mode="switch-state"/>)
};
declare private function ent:valid-states-impl($states as map:map,$event as xs:string) as xs:string* {
	<xsl:for-each select="x:state-machine">
		let $<xsl:value-of select="@name"/>:=map:get($states,'<xsl:value-of select="@name"/>')
	</xsl:for-each>
	return (<xsl:apply-templates select="x:state-machine" mode="switch-state2"/>)
};
</xsl:template>

<xsl:template match="x:state-machine" mode="switch-state">
	<xsl:if test="position()!=1">,</xsl:if>
	switch($<xsl:value-of select="@name"/>)
	<xsl:for-each select="x:state">
	case '<xsl:value-of select="@name"/>' return (<xsl:apply-templates select="x:event"/>)
	</xsl:for-each>
	default return ent:error('invalid-state','<xsl:value-of select="@name"/> has invalid state '||$<xsl:value-of select="@name"/>)
</xsl:template>

<xsl:template match="x:state-machine" mode="switch-state2">
	<xsl:if test="position()!=1">,</xsl:if>
	switch($<xsl:value-of select="@name"/>)
	<xsl:for-each select="x:state">
	case '<xsl:value-of select="@name"/>' return (
			<xsl:choose>
				<xsl:when test="x:event">
						switch($event)
						<xsl:for-each select="x:event">
						case '<xsl:value-of select="@action"/>' return (
						<xsl:choose>
							<xsl:when test="x:target"><xsl:apply-templates select="x:target"/></xsl:when>
							<xsl:otherwise><xsl:for-each select="ancestor::x:state-machine//x:state">
								<xsl:if test="position()!=1">,</xsl:if>
								'<xsl:value-of select="@name"/>'
							</xsl:for-each></xsl:otherwise>
						</xsl:choose>)
					</xsl:for-each>
					default return ()
				</xsl:when>
				<xsl:otherwise><xsl:for-each select="ancestor::x:state-machine//x:state">
					<xsl:if test="position()!=1">,</xsl:if>
					'<xsl:value-of select="@name"/>'
				</xsl:for-each></xsl:otherwise>
			</xsl:choose>
	)
	</xsl:for-each>
	default return ent:error('invalid-state','<xsl:value-of select="@name"/> has invalid state '||$<xsl:value-of select="@name"/>)
</xsl:template>

<xsl:template match="x:target">
	<xsl:if test="fn:position()!=1">,</xsl:if>
	'<xsl:value-of select="@state"/>'
</xsl:template>

<xsl:template match="x:event">
	<xsl:if test="fn:position()!=1">,</xsl:if>
	<xsl:call-template name="guards">
		<xsl:with-param name="guards" select="x:guard"/>
		<xsl:with-param name="sm" select="ancestor::x:state-machine"/>
	</xsl:call-template>
	<xsl:variable name="action" select="key('action',@action)"/>
	<xsl:for-each select="$action/x:match-security-role">
		<xsl:text>if (ent:has-role((</xsl:text><xsl:apply-templates select="."/><xsl:text>))) then </xsl:text>
	</xsl:for-each>
	'<xsl:value-of select="@action"/>'
	<xsl:if test="x:guard"> else ()</xsl:if>
	<xsl:for-each select="$action/x:match-security-role">
		<xsl:text> else ()</xsl:text>
	</xsl:for-each>
</xsl:template>

<xsl:template name="guards">
	<xsl:param name="guards"/>
	<xsl:param name="sm"/>
	<xsl:variable name="x">
	<xsl:for-each select="ancestor::x:entity-type/x:state-machine">
		<xsl:variable name="sm2" select="."/>
		<xsl:variable name="t">
			<xsl:call-template name="guards2">
				<xsl:with-param name="guards" select="$guards[key('state',@state)[ancestor::x:state-machine/@name=$sm2/@name]]"/>
				<xsl:with-param name="sm" select="$sm2"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:if test="$t!=''"> and (<xsl:text/><xsl:value-of select="$t"/>)</xsl:if>
	</xsl:for-each>
	</xsl:variable>
	<xsl:if test="$x!=''">
		<xsl:text>if (</xsl:text>
		<xsl:value-of select="substring-after($x,'and')"/>
		<xsl:text>) then </xsl:text>
	</xsl:if>
</xsl:template>

<xsl:template name="guards2">
	<xsl:param name="guards"/>
	<xsl:param name="sm"/>
	<xsl:for-each select="$guards">
		<xsl:if test="position()!=1"> or </xsl:if>
		<xsl:if test="string(@invert)='true'">not</xsl:if>
		($<xsl:value-of select="$sm/@name"/>='<xsl:value-of select="@state"/>')
	</xsl:for-each>
</xsl:template>

<xsl:template match="x:constructor">
declare function ent:<xsl:value-of select="@name"/>($uri as xs:string,<xsl:apply-templates select="@argument-type"/>)<xsl:text> as element(es:entity) {</xsl:text>
    let $data as map:map:=map:new()
    let $triples as map:map:=map:new()
    let $attachments as map:map:=map:new()
    let $states:=map:new((
			<xsl:for-each select="ancestor::x:entity-type//x:state-machine"><xsl:if test="position()!=1">,</xsl:if>
				map:entry('<xsl:value-of select="@name"/>','<xsl:value-of select="@initial-state"/>')
			</xsl:for-each>
		))
	let $_:=<xsl:apply-templates select="." mode="invoke"><xsl:with-param name="args">$arg,$data,$triples,$attachments</xsl:with-param></xsl:apply-templates>
	let $r:=element es:entity {
		namespace xs {"http://www.w3.org/2001/XMLSchema/"},
		attribute xml:base {$uri},
		attribute entity-type {"<xsl:value-of select="ancestor::x:entity-schema/@namespace"/>#<xsl:value-of select="ancestor::x:entity-type/@name"/>"}
	}
	return ent:canonical($r,$data,$triples,$attachments,$states,map:new(),map:new(map:keys($states)!map:entry(.,fn:current-dateTime())))
};
</xsl:template>

<xsl:template match="x:match-execute-privilege|x:match-security-role">
	<xsl:for-each select="tokenize(@any-of,' ')">
		<xsl:if test="position()!=1">,</xsl:if>
		<xsl:text>'</xsl:text>
		<xsl:value-of select="."/>
		<xsl:text>'</xsl:text>
	</xsl:for-each>
</xsl:template>

<xsl:template match="x:action">
declare function ent:<xsl:value-of select="@name"/>($ent as element(es:entity)<xsl:if test="@argument-type">,<xsl:apply-templates select="@argument-type"/></xsl:if><xsl:text>) as element(es:entity) {</xsl:text>
	<xsl:for-each select="x:match-execute-privilege">let $_:=xdmp:security-assert((<xsl:apply-templates select="."/>),'execute')</xsl:for-each>
	<xsl:for-each select="x:match-security-role">let $_:=ent:role-assert((<xsl:apply-templates select="."/>))</xsl:for-each>
    let $states as map:map:=map:new($ent/es:states/state:state!map:entry(./@fsm,@name))
    let $stateupd as map:map:=map:new($ent/es:states/state:state!map:entry(./@fsm,@updated))
    let $events as xs:string+:=ent:valid-events-impl($states)
    return if (not($events='<xsl:value-of select="@name"/>')) then ent:error('invalid-event','<xsl:value-of select="@name"/> is an invalid event, expected one of '||string-join($events,','))
    else
    let $targets as xs:string+:=ent:valid-states-impl($states,'<xsl:value-of select="@name"/>')
    let $data as map:map:=map:new($ent/es:data/*!map:entry(local-name(.),./node()))
    let $triples as map:map:=map:new($ent/es:triples/*!map:entry(local-name(.),./node()//sem:triple!sem:triple(.)))
    let $attachments as map:map:=map:new($ent/es:attachments/es:attachment!map:entry(local-name(.),(./@*[name()!='href'],./node())))
	let $newstates as xs:string*:=<xsl:apply-templates select="." mode="invoke"><xsl:with-param name="args"><xsl:if test="@argument-type">$arg,</xsl:if>$data,$triples,$attachments</xsl:with-param></xsl:apply-templates>
	let $_:=($newstates[not($targets=.)])!ent:error('invalid-event',.||' is an invalid state for event <xsl:value-of select="@name"/>, expected one of '||string-join($targets,','))
	return ent:canonical($ent,$data,$triples,$attachments,ent:update-states($states,$newstates),$states,$stateupd)	
};
</xsl:template>

<xsl:template match="x:canonizer">
declare private function ent:canonical($node as node(),$data as map:map,$triples as map:map,$attachments as map:map,$state as map:map,$oldstates as map:map,$stateupd as map:map) as node()? {
	typeswitch($node)
	case element(es:entity) return element es:entity {attribute version {"<xsl:value-of select="ancestor::x:entity-type/@version"/>"},namespace xs {"http://www.w3.org/2001/XMLSchema/"}, $node/@*[name()!='version'] ,$node/node()!ent:canonical(.,$data,$triples,$attachments,$state,$oldstates,$stateupd) ,
		if (map:count($data)) then element es:data {
			for $k in map:keys($data) return element{xs:QName($k)}{map:get($data,$k)}
		} else(),
		if (map:count($triples)) then element es:triples {
			for $k in map:keys($triples) 
				let $t as element(sem:triples):=sem:rdf-serialize(map:get($triples,$k),'triplexml')
				return element{xs:QName($k)}{$t}
		} else (),
		if (map:count($attachments)) then element es:attachments {
			for $k in map:keys($attachments) return element es:attachment { attribute href {$k},map:get($attachments,$k)}
		} else (),
		element es:states {
			for $s in map:keys($state) return element state:state{
				attribute name {map:get($state,$s)},
				attribute fsm {$s},
				attribute updated {if (map:get($oldstates,$s)=map:get($state,$s)) then map:get($stateupd,$s) else fn:current-dateTime()}
			} 
		},
		element es:canonical {
		let $m as map:map:=<xsl:apply-templates select="." mode="invoke"><xsl:with-param name="args">$data,$triples,$attachments</xsl:with-param></xsl:apply-templates>
		return for $k in map:keys($m) return 
			element{xs:QName($k)}{map:get($m,$k)}
	}
	}
    case element(es:states) return ()
    case element(es:canonical) return ()
    case element(es:attachments) return ()
    case element(es:data) return ()
    case element(es:triples) return ()	
	case element() return element{fn:node-name($node)}{$node/@*,$node/node()!ent:canonical(.,$data,$triples,$attachments,$state,$oldstates,$stateupd)}
	case document-node() return document{$node/node()!ent:canonical(.,$data,$triples,$attachments,$state,$oldstates,$stateupd)}
	default return $node
};
</xsl:template>

	<xsl:template match="x:canonizer|x:constructor|x:action" mode="invoke">
		<xsl:param name="args"/>
		<xsl:value-of select="@module"/>:<xsl:value-of select="@function"/>(<xsl:value-of select="$args"/>)<xsl:text/>
	</xsl:template>

	<xsl:template match="@argument-type">
		<xsl:text>$arg as </xsl:text><xsl:apply-templates select="key('data-type',.)"/>
	</xsl:template>
	<xsl:template match="x:data-type">
		<xsl:choose>
			<xsl:when test="@type">
				<xsl:value-of select="@type"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:apply-templates select="*"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template match="x:any-xml|x:schema">
		<xsl:choose>
			<xsl:when test="@namespace">
				<xsl:text>element(x</xsl:text>
				<xsl:value-of select="count(preceding-sibling::*)"/>:<xsl:value-of select="@element"/>
				<xsl:text>)</xsl:text>
			</xsl:when>
			<xsl:otherwise>
			<xsl:text>element(</xsl:text><xsl:value-of select="@element"/><xsl:text>)</xsl:text>
		</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>
