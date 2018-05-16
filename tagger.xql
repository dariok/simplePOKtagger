xquery version "3.1";

module namespace spt = "https://github.com/dariok/simplePOKtagger";

declare function spt:person($query as xs:string)  {

    let $req := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;titles=" || $query || "&amp;languages=de|en"
    let $resp := doc($req)
    
    return if ($resp//*:entity[@id != '-1']) then
        let $wbData := $resp//*:entity[@id != '-1']
        
        return
        <person xmlns="http://www.tei-c.org/ns/1.0">
            <persName>
                {spt:getNames($wbData[1]/*:labels/*:label[1])}
            </persName>
            {
                for $form in distinct-values($wbData[1]/*:aliases//*:alias/@value)
                    return <persName type="alias">{$form}</persName>
            }
            <occupation>{normalize-space($wbData[1]//*:descriptions/*:description[1]/@value)}</occupation>
            <idno type="URL" subtype="GND">{'http://d-nb.info/gnd/' || spt:getWbProp($wbData, 'P227')/@value}</idno>
            <sex>{
                let $reqP := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;ids=" || 
                        spt:getWbProp($wbData, 'P21')/*:value/@id
                        || "&amp;languages=en"
                    
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
                spt:getNames(text{translate($query, '_', ' ')})
            }</persName>
        </person>
};

declare function spt:getWhen($data) as node()* {
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
    $wbData//*:property[@id = $prop]
};

declare function spt:getWbProp($wbData as node(), $prop as xs:string) as node()* {
    spt:getWbProp($wbData, $prop, 1)
};

declare function spt:getWbProp($wbData as node(), $prop as xs:string, $sel) as node()* {
    $wbData//*:mainsnak[@property = $prop][$sel]/*:datavalue
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

declare function spt:getPlaceName ($id as xs:string) as node() {
    <placeName xmlns="http://www.tei-c.org/ns/1.0">{
        let $reqP := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;ids=" || $id || "&amp;languages=de|en"
        let $doc := doc($reqP)
        
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