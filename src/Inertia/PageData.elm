module Inertia.PageData exposing
    ( PageData
    , decoder
    )

import Json.Decode


type alias PageData props =
    { component : String
    , props : props
    , url : String
    , version : String
    }


decoder : Json.Decode.Decoder props -> Json.Decode.Decoder (PageData props)
decoder propsDecoder =
    Json.Decode.map4 PageData
        (Json.Decode.field "component" Json.Decode.string)
        (Json.Decode.field "props" propsDecoder)
        (Json.Decode.field "url" Json.Decode.string)
        (Json.Decode.field "version" Json.Decode.string)
