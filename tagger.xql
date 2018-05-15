xquery version "3.1";

module namespace spt = "https://github.com/dariok/simplePOKtagger";

declare function spt:person($query as xs:string)  {

    let $req := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;titles=" || $query || "&amp;languages=de"
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
            <occupation>{normalize-space($wbData[1]//*:entity[1]/*:descriptions/*:description[@language='de']/@value)}</occupation>
            <idno type="URL" subtype="GND">{'http://d-nb.info/gnd/' || spt:getWbProp($wbData, 'P227')/@value}</idno>
            <sex>{
                let $reqP := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;ids=" || 
                        spt:getWbProp($wbData, 'P21')/*:value/@id
                        || "&amp;languages=en"
                    
                    return substring(doc($reqP)//*:entity[1]/*:labels/*:label[1]/@value, 1, 1)
            }</sex>
            <birth>{
                let $prop := spt:getWbProp($wbData, 'P569')/*:value
                let $teiDate := spt:getTEIDate($prop)
                    
                return (
                    attribute when {$teiDate},
                    spt:getLongDate($teiDate, 'de')
                )}
                {spt:getPlaceName(spt:getWbProp($wbData, 'P19')/*:value/@id)}
            </birth>
            <death>{
                let $prop := spt:getWbProp($wbData, 'P570')/*:value
                let $teiDate := spt:getTEIDate($prop)
                    
                return (
                    attribute when {$teiDate},
                    spt:getLongDate($teiDate, 'de')
                )}
                {spt:getPlaceName(spt:getWbProp($wbData, 'P20')/*:value/@id)}
            </death>
        </person>
    else
        <person xml:id="a" xmlns="http://www.tei-c.org/ns/1.0">
            <persName>{
                for $part at $pos in tokenize($query, '_')
                    let $el := if ($pos = 1) then 'forename'
                        else if ($pos = count(tokenize($query, '_'))) then 'surname'
                        else if ($part = 'von') then 'nameLink'
                        else 'name'
                    
                    return element {$el} {$part}
            }</persName>
        <!--
            {if (contains($v, '/'))
                then <tei:listBibl>
                    <tei:bibl>
                        <tei:ref target="{$val}" />
                    </tei:bibl>
                </tei:listBibl>
                else ()
            }
        -->
        </person>
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
    <placeName>{
        let $reqP := "https://www.wikidata.org/w/api.php?action=wbgetentities&amp;format=xml&amp;sites=enwiki|dewiki&amp;ids=" || $id || "&amp;languages=de"
            let $doc := doc($reqP)
            
            return ( 
                attribute ref {'http://d-nb.info/gnd/' || spt:getWbProp($doc, 'P227')/@value},
            xs:string($doc//*:entity[1]/*:labels/*:label[1]/@value)
        )
    }</placeName>
};

declare function spt:getNames ($node as node()) as node()* {
    let $parts := tokenize($node/@value, ' ')
    let $vornamen := ('Bernhard', 'Maria')
    
    for $part at $pos in $parts
        let $elem := if ($pos = 1)
            then 'forename'
            else if ($pos = count($parts))
            then 'surname'
            else if ($part = 'von')
            then 'nameLink'
            else if (contains($vornamen, $parts))
            then 'forename'
            else 'surname'
    
        return element {$elem} {$part}
};