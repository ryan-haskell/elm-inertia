port module Interop exposing
    ( Flags, decoder
    , onRefreshXsrfToken, onXsrfTokenRefreshed
    , onFlagsDecodeError
    )

{-|

@docs Flags, decoder
@docs onRefreshXsrfToken, onXsrfTokenRefreshed
@docs onFlagsDecodeError

-}

import Json.Decode



-- FLAGS


type alias Flags =
    { window : WindowSize
    }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.map Flags
        (Json.Decode.field "window" windowSizeDecoder)


type alias WindowSize =
    { width : Float
    , height : Float
    }


windowSizeDecoder : Json.Decode.Decoder WindowSize
windowSizeDecoder =
    Json.Decode.map2 WindowSize
        (Json.Decode.field "width" Json.Decode.float)
        (Json.Decode.field "height" Json.Decode.float)



-- INERTIA PORTS


port onRefreshXsrfToken : () -> Cmd msg


port onXsrfTokenRefreshed : (String -> msg) -> Sub msg



-- CUSTOM PORTS


port onFlagsDecodeError : String -> Cmd msg
