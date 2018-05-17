xquery version "3.1";

import module namespace sptp = "https://github.com/dariok/simplePOKtagger" at "tagger.xqm";

let $type := request:get-parameter('type', '')
let $query := request:get-parameter('name', '')

return if ($type = 'person') then sptp:person($query)
    else if ($type = 'place') then sptp:place($query)
    else if ($type = 'org') then sptp:org($query)
    else "ERROR: Wrong type! Supported values are: 'person', 'place'"