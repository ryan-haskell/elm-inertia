module Inertia.HttpRequest exposing (Request, map)

import Http
import Json.Decode


type alias Request msg =
    { method : String
    , url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder msg
    , onFailure : Http.Error -> msg
    , headers : List Http.Header
    , timeout : Maybe Float
    , tracker : Maybe String
    }


map : (a -> b) -> Request a -> Request b
map fn req =
    { method = req.method
    , url = req.url
    , body = req.body
    , decoder = Json.Decode.map fn req.decoder
    , onFailure = fn << req.onFailure
    , headers = req.headers
    , timeout = req.timeout
    , tracker = req.tracker
    }
