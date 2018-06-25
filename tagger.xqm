xquery version "3.1";

module namespace spt = "https://github.com/dariok/simplePOKtagger";

declare variable $spt:normNames := map {'P214' := "VIAF", 'P227' := "GND", 'P1566' := "Geonames"};
declare variable $spt:normLinks := map {'P214' := "https://viaf.org/viaf/", 'P227' := "https://d-nb.info/gnd/", 'P1566' := "http://geonames.org/"};
declare variable $spt:req := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;languages=de|en&amp;titles=";
declare variable $spt:reqP := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;languages=de|en&amp;ids=";

declare function spt:org ($query as xs:string) {
    let $resp := doc($spt:req || $query)
    
    return if ($resp//*:entity[not(starts-with(@id, '-'))]) then
        let $wbData := $resp//*:entity[not(starts-with(@id, '-'))]
        
        (: return nothing if result is a disambiguation page :)
        return if ($wbData[1]//*:property[@id='P31']//*:value[@id='Q4167410']) then () else
        <org xmlns="http://www.tei-c.org/ns/1.0">
            <orgName>{xs:string($wbData[1]/*:labels/*:label[1]/@value)}</orgName>
            {
                for $form in distinct-values($wbData[1]/*:aliases//*:alias/@value)
                    return <orgName type="alt">{$form}</orgName>
            }
            {
                let $props := spt:getWbProps($wbData, ('P227', 'P214', 'P1566'))
                return if ($props) then 
                    for $idno in ()
                        let $name := $spt:normNames($idno/@id)
                        let $link := $spt:normLinks($idno/@id)
                        
                        for $no in $idno//*:mainsnak/*:datavalue
                            return <idno type="URL" subtype="{$name}">{$link || $no/@value}</idno>
                else ()
            }
            {
                if ($wbData[1]//*:description[@language = 'de']) then
                    <desc type="short">{normalize-space($wbData[1]//*:description[@language = 'de']/@value)}</desc>
                else if ($wbData[1]//*:description) then
                    <desc>{normalize-space($wbData[1]//*:description[1]/@value)}</desc>
                else ()
            }
            {
                if (spt:getWbProp($wbData, 'P31')) then
                    let $top := spt:getWbProp($wbData, 'P31')
                    let $doc := doc($spt:reqP || $top//*:value/@id)
                    return
                        <desc type="type">{
                            ( 
                                attribute ref {$spt:normLinks("P227") || spt:getWbProp($doc, 'P227')/@value},
                                if ($wbData[1]//*:description[@language = 'de'])
                                    then xs:string($doc//*:entity[1]/*:labels/*:label[@language = 'de']/@value)
                                    else xs:string($doc//*:entity[1]/*:labels/*:label[1]/@value)
                            )
                        }</desc>
                else ()
            }
            {
                let $top := spt:getWbProp($wbData, 'P452')
                return if ($top) then
                    let $doc := doc($spt:reqP || $top//*:value/@id)
                    return
                        <desc type="industry">{
                            ( 
                                attribute ref {$spt:normLinks("P227") || spt:getWbProp($doc, 'P227')/@value},
                                if ($wbData[1]//*:description[@language = 'de'])
                                    then xs:string($doc//*:entity[1]/*:labels/*:label[@language = 'de']/@value)
                                    else xs:string($doc//*:entity[1]/*:labels/*:label[1]/@value)
                            )
                        }</desc>
                else ()
            }
            {
                if (spt:getWbProp($wbData, 'P159')) then
                    <location>
                        {spt:getPlaceName(spt:getWbProp($wbData, 'P159')//*:value/@id)}
                        {
                            let $country := spt:getWbProp($wbData, 'P17')
                            return if ($country) then
                                let $doc := doc($spt:reqP || $country//*:value/@id)
                                
                                return
                                <country>{
                                    ( 
                                        attribute ref {'http://geonames.org/' || spt:getWbProp($doc, 'P1566')/@value},
                                        xs:string($doc//*:entity[1]/*:labels/*:label[1]/@value)
                                    )
                                }</country>
                            else ()
                        }
                    </location>
                else ()
            }
            {
                let $owners := spt:getWbProp($wbData, 'P17', 'descendant::*:value')
                return for $owner in $owners
                    let $doc := doc($spt:reqP || $owner//*:value/@id)
                    
                    return
                    <state type="owner">{
                        ( 
                            attribute ref {$spt:normLinks("P227") || spt:getWbProp($doc, 'P227')/@value},
                            <name>{xs:string($doc//*:entity[1]/*:labels/*:label[1]/@value)}</name>
                        )
                    }</state>
            }
            {
                let $from := spt:getWbProp($wbData, 'P571')
                let $to := spt:getWbProp($wbData, 'P576')
                
                return if ($from or $to) then
                    <state type="existence">{
                        (
                            if ($from) then attribute from {spt:getTEIDate($from//*:value)} else (),
                            if ($to) then attribute to {spt:getTEIDate($to//*:value)} else ()
                        )
                    }</state>
                else()
            }
        </org>
    else
        <org xmlns="http://www.tei-c.org/ns/1.0">
            <orgName>{translate($query, '_', ' ')}</orgName>
        </org>
};

declare function spt:place ($query as xs:string) {
    let $resp := doc($spt:req || $query)
    
    return if ($resp//*:entity[not(starts-with(@id, '-'))]) then
        let $wbData := $resp//*:entity[not(starts-with(@id, '-'))]
        
        (: return nothing if result is a disambiguation page :)
        return if ($wbData[1]//*:property[@id='P31']//*:value[@id='Q4167410']) then () else
        <place xmlns="http://www.tei-c.org/ns/1.0">
            <placeName>{xs:string($wbData[1]/*:labels/*:label[1]/@value)}</placeName>
            {
                for $form in distinct-values($wbData[1]/*:aliases//*:alias/@value)
                    return <placeName type="alt">{$form}</placeName>
            }
            {
                for $idno in (spt:getWbProps($wbData, ('P227', 'P214', 'P1566')))
                    let $name := $spt:normNames($idno/@id)
                    let $link := $spt:normLinks($idno/@id)
                    
                    for $no in $idno//*:mainsnak/*:datavalue
                        return <idno type="URL" subtype="{$name}">{$link || $no/@value}</idno>
            }
            {
                if ($wbData[1]//*:description[@language = 'de']) then
                    <desc>{normalize-space($wbData[1]//*:description[@language = 'de']/@value)}</desc>
                else if ($wbData[1]//*:description) then
                    <desc>{normalize-space($wbData[1]//*:description[1]/@value)}</desc>
                else ()
            }
            {
                let $countries := spt:getFullProp($wbData, 'P17')
                return
                <location type="country">{
                    for $loc in $countries/*:claim[*:mainsnak/@property = 'P17']
                        return
                        <country>{
                            let $doc := doc($spt:reqP || $loc//*:value/@id)
                            
                            return (
                                if (spt:getWbProp($doc, 'P1566')/@value) then attribute ref {'http://geonames.org/' || spt:getWbProp($doc, 'P1566')/@value} else (),
                                if ($loc//*:property[@id = 'P580']) then attribute not-before {spt:getTEIDate($loc//*:property[@id = 'P580']//*:value)} else (),
                                if ($loc//*:property[@id = 'P582']) then attribute not-after {spt:getTEIDate($loc//*:property[@id = 'P582']//*:value)} else (),
                                xs:string($doc//*:entity[1]/*:labels/*:label[1]/@value)
                            )
                        }</country>
                }</location>
            }
            {
                let $coords := spt:getWbProps($wbData, ('P1332', 'P1333', 'P1334', 'P1335'))
                return if (count($coords) > 0) then
                    <location type="coords">{
                        for $coord in $coords
                            return <geo>{$coord//*:value/@longitude || ' ' || $coord//*:value/@latitude}</geo>
                    }</location>
                else()
            }
        </place>
    else
        <place xmlns="http://www.tei-c.org/ns/1.0">
            <placeName>{$query}</placeName>
        </place>
};

declare function spt:person ($query as xs:string) {
    let $resp := doc($spt:req || $query)
    
    return if ($resp//*:entity[not(starts-with(@id, '-'))]) then
        let $wbData := $resp//*:entity[not(starts-with(@id, '-'))]
        
        (: return nothing if result is a disambiguation page :)
        return if ($wbData[1]//*:property[@id='P31']//*:value[@id='Q4167410']) then () else
        <person xmlns="http://www.tei-c.org/ns/1.0">
            <persName>
                {spt:getNames($wbData[1]/*:labels/*:label[1])}
            </persName>
            {
                for $form in distinct-values($wbData[1]/*:aliases//*:alias/@value)
                    return <persName type="alias">{$form}</persName>
            }
            {
                if ($wbData[1]//*:description[@language = 'de']) then
                    <occupation>{normalize-space($wbData[1]//*:description[@language = 'de']/@value)}</occupation>
                else if ($wbData[1]//*:description) then
                    <occupation>{normalize-space($wbData[1]//*:description[1]/@value)}</occupation>
                else ()
            }
            {
                for $idno in (spt:getWbProps($wbData, ('P227', 'P214')))
                    let $name := if ($idno/@id = 'P227') then "GND" else "VIAF"
                    let $link := if ($idno/@id = 'P227') then "https://d-nb.info/gnd/" else "https://viaf.org/viaf/"
                    
                    return <idno type="URL" subtype="{$name}">{$link || $idno//*:datavalue/@value}</idno>
            }
            <sex>{
                let $reqP := $spt:reqP || spt:getWbProp($wbData, 'P21')/*:value/@id
                    
                    return substring(doc($reqP)//*:entity[1]/*:labels/*:label[1]/@value, 1, 1)
            }</sex>
            <birth>{
                spt:getWhen(spt:getFullProp($wbData, 'P569')),
                spt:getPlaceName(spt:getWbProp($wbData, 'P19')/*:value/@id)}
            </birth>
            <death>{
                spt:getWhen(spt:getFullProp($wbData, 'P570')),
                spt:getPlaceName(spt:getWbProp($wbData, 'P20')/*:value/@id)}
            </death>
        </person>
    else
        <person xml:id="a" xmlns="http://www.tei-c.org/ns/1.0">
            <persName>{
                spt:getNames(<name value="{translate($query, '_', ' ')}"/>)
            }</persName>
        </person>
};

declare function spt:getWhen($data) as node()* {
    if (count($data//*:mainsnak) > 1) then
    (
        let $dates := for $date in $data//*:mainsnak
            group by $dateVal := $date//*:value/@time
            order by $dateVal
            return $date
            
        return (
            attribute not-before {spt:getTEIDate($dates[1]//*:value)},
            attribute not-after {spt:getTEIDate($dates[last()]//*:value)},
            for $date at $pos in $dates
                return (
                    text {spt:getLongDate(spt:getTEIDate($date//*:value), 'de')},
                    if ($pos = count($data//*:mainsnak)) then ()
                    else if ($pos = count($data//*:mainsnak) - 1) then text {" oder "}
                    else text {", "}
            )
        )
    )
    else
    (
        if ($data//*:mainsnak//*:value) then
            attribute when {spt:getTEIDate($data//*:mainsnak//*:value)}
        else (),
        if ($data//*:qualifiers/*:property[@id='P1319']) then
            attribute not-before {spt:getTEIDate($data//*:qualifiers/*:property[@id='P1319']//*:value)}
        else(),
        if ($data//*:qualifiers/*:property[@id='P1326']) then
            attribute not-after {spt:getTEIDate($data//*:qualifiers/*:property[@id='P1326']//*:value)}
        else(),
        if ($data//*:mainsnak//*:value) then
            text {spt:getLongDate(spt:getTEIDate($data//*:mainsnak//*:value), 'de')}
        else if ($data//*:qualifiers/*:property[@id='P1319'] and $data//*:qualifiers/*:property[@id='P1326']) then
            text {"zwischen " || spt:getLongDate(spt:getTEIDate($data//*:qualifiers/*:property[@id='P1319']//*:value), 'de') ||
            " und " || spt:getLongDate(spt:getTEIDate($data//*:qualifiers/*:property[@id='P1326']//*:value), 'de')}
        else if ($data//*:qualifiers/*:property[@id='P1319']) then
            text {"vor " || spt:getLongDate(spt:getTEIDate($data//*:qualifiers/*:property[@id='P1319']//*:value), 'de')}
        else if ($data//*:qualifiers/*:property[@id='P1326']) then
            text {"vor " || spt:getLongDate(spt:getTEIDate($data//*:qualifiers/*:property[@id='P1326']//*:value), 'de')}
        else text {"unbekannt"}
    )
};

declare function spt:getFullProp ($wbData as node(), $prop as xs:string) as node()* {
    $wbData//*:claims/*:property[@id = $prop]
};
declare function spt:getWbProp($wbData as node(), $prop as xs:string) as node()* {
    spt:getWbProp($wbData, $prop, 1)
};
declare function spt:getWbProp($wbData as node(), $prop as xs:string, $sel) as node()* {
    $wbData//*:claims/*:property//*:mainsnak[@property = $prop][$sel]/*:datavalue
};
declare function spt:getWbProps($wbData as node(), $props as xs:string+) as node()* {
    for $prop in $props
        return spt:getFullProp($wbData, $prop)
};

declare function spt:getLongDate ($dateString as xs:string, $lang as xs:string) as xs:string {
    if (string-length($dateString) = 4)
    then format-date(xs:date($dateString || '-01-01'), "[Y]")
    else if (string-length($dateString) = 7)
    then format-date(xs:date($dateString || '-01'), "[MNn] [Y]", $lang, (), ())
    else if (string-length($dateString) = 10)
    then format-date(xs:date($dateString), "[D0]. [MNn] [Y]", $lang, (), ())
    else "error"
};

declare function spt:getTEIDate ($prop as node()) as xs:string {
    if ($prop/@precision = '9')
        then substring($prop/@time, 2, 4)
        else if ($prop/@precision = '10' )
        then substring($prop/@time, 2, 7)
        else if ($prop/@precision = '11' )
        then substring($prop/@time, 2, 10)
        else '0'
};

declare function spt:getPlaceName ($id as xs:string?) as node()? {
	if (count($id) = 0) then () else 
    <placeName xmlns="http://www.tei-c.org/ns/1.0">{
        let $doc := doc($spt:reqP || $id)
        
        return ( 
            attribute ref {'http://geonames.org/' || spt:getWbProp($doc, 'P1566')/@value},
        xs:string($doc//*:entity[1]/*:labels/*:label[1]/@value)
        )
    }</placeName>
};

declare function spt:getNames ($node as node()) as node()* {
    let $parts := tokenize($node/@value, ' ')
    let $vornamen := doc('/db/apps/spt/forenames.xml')
    
    for $part at $pos in $parts
        let $elem := if ($pos = 1)
            then 'forename'
            else if ($pos = count($parts))
            then 'surname'
            else if ($part = 'von')
            then 'nameLink'
            else if ($vornamen//*:forename[. = lower-case($part)])
            then 'forename'
            else 'surname'
    
        return element {fn:QName("http://www.tei-c.org/ns/1.0", $elem)} {$part}
};