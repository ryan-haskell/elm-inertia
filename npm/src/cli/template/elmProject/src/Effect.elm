module Effect exposing
    ( Effect
    , none, batch
    , sendMsg
    , get, post, put, patch, delete
    , request
    , pushUrl, replaceUrl, back, forward
    , load, reload, reloadAndSkipCache
    , reportFlagsDecodeError
    , map
    , CustomEffect(..)
    , mapCustomEffect
    )

{-|

@docs Effect
@docs none, batch
@docs sendMsg

@docs get, post, put, patch, delete
@docs request

@docs pushUrl, replaceUrl, back, forward
@docs load, reload, reloadAndSkipCache

@docs reportFlagsDecodeError

@docs map

@docs CustomEffect
@docs mapCustomEffect

-}

import Http
import Inertia.Effect
import Json.Decode



-- EFFECTS


type alias Effect msg =
    Inertia.Effect.Effect (CustomEffect msg) msg


none : Effect msg
none =
    Inertia.Effect.none


batch : List (Effect msg) -> Effect msg
batch =
    Inertia.Effect.batch


sendMsg : msg -> Effect msg
sendMsg =
    Inertia.Effect.sendMsg



-- HTTP


get :
    { url : String
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
get =
    Inertia.Effect.get


post :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
post =
    Inertia.Effect.post


put :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
put =
    Inertia.Effect.put


patch :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
patch =
    Inertia.Effect.patch


delete :
    { url : String
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
delete =
    Inertia.Effect.delete


request :
    { method : String
    , url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder msg
    , onFailure : Http.Error -> msg
    , headers : List Http.Header
    , timeout : Maybe Float
    , tracker : Maybe String
    }
    -> Effect msg
request =
    Inertia.Effect.request



-- URL NAVIGATION


pushUrl : String -> Effect msg
pushUrl =
    Inertia.Effect.pushUrl


replaceUrl : String -> Effect msg
replaceUrl =
    Inertia.Effect.replaceUrl


back : Int -> Effect msg
back =
    Inertia.Effect.back


forward : Int -> Effect msg
forward =
    Inertia.Effect.forward


load : String -> Effect msg
load =
    Inertia.Effect.load


reload : Effect msg
reload =
    Inertia.Effect.reload


reloadAndSkipCache : Effect msg
reloadAndSkipCache =
    Inertia.Effect.reloadAndSkipCache



-- CUSTOM


reportFlagsDecodeError : Json.Decode.Error -> Effect msg
reportFlagsDecodeError error =
    Inertia.Effect.custom (ReportFlagsDecodeError error)



-- TRANSFORMING EFFECTS


map : (a -> b) -> Effect a -> Effect b
map fn =
    Inertia.Effect.map (mapCustomEffect fn) fn



-- CUSTOM EFFECTS


{-| Define your custom effects here!
-}
type CustomEffect msg
    = ReportFlagsDecodeError Json.Decode.Error


mapCustomEffect : (a -> b) -> CustomEffect a -> CustomEffect b
mapCustomEffect fn customEffect =
    case customEffect of
        ReportFlagsDecodeError error ->
            ReportFlagsDecodeError error
