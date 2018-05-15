xquery version "3.1";

import module namespace sptp = "https://github.com/dariok/simplePOKtagger" at "tagger.xql";

let $type := request:get-parameter('type', '')
let $query := request:get-parameter('name', '')

return sptp:person($query)