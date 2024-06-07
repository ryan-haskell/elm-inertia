module Inertia.Effect exposing
    ( Effect(..)
    , none, batch
    , sendMsg
    , get, post, put, delete
    , request
    , pushUrl, replaceUrl, back, forward
    , load, reload, reloadAndSkipCache
    , map
    )

{-|

@docs Effect
@docs none, batch

@docs sendMsg

@docs get, post, put, delete
@docs request

@docs pushUrl, replaceUrl, back, forward
@docs load, reload, reloadAndSkipCache

@docs map

-}

import Http
import Inertia.HttpRequest
import Json.Decode
import Json.Encode
import Url exposing (Url)


type Effect msg
    = None
    | Batch (List (Effect msg))
    | SendMsg msg
    | Http (Inertia.HttpRequest.Request msg)
    | PushUrl String
    | ReplaceUrl String
    | Back Int
    | Forward Int
    | Load String
    | Reload
    | ReloadAndSkipCache



-- BASICS


none : Effect msg
none =
    None


batch : List (Effect msg) -> Effect msg
batch effects =
    Batch effects



-- MESSAGES


sendMsg : msg -> Effect msg
sendMsg msg =
    SendMsg msg



-- URL NAVIGATION


pushUrl : String -> Effect msg
pushUrl url =
    PushUrl url


replaceUrl : String -> Effect msg
replaceUrl url =
    ReplaceUrl url


back : Int -> Effect msg
back int =
    Back int


forward : Int -> Effect msg
forward int =
    Forward int


load : String -> Effect msg
load url =
    Load url


reload : Effect msg
reload =
    Reload


reloadAndSkipCache : Effect msg
reloadAndSkipCache =
    ReloadAndSkipCache



-- HTTP


{-| Feels like this is only useful if you want to get data without changing the URL.

Prefer `Effect.pushUrl` instead, which does normal inertia things!

-}
get :
    { url : String
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
get options =
    let
        decoder : Json.Decode.Decoder msg
        decoder =
            options.decoder
                |> Json.Decode.map (\props -> options.onResponse (Ok props))

        onFailure : Http.Error -> msg
        onFailure httpError =
            options.onResponse (Err httpError)
    in
    Http
        { method = "GET"
        , url = options.url
        , body = Http.emptyBody
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


post :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
post options =
    let
        decoder : Json.Decode.Decoder msg
        decoder =
            options.decoder
                |> Json.Decode.map (\props -> options.onResponse (Ok props))

        onFailure : Http.Error -> msg
        onFailure httpError =
            options.onResponse (Err httpError)
    in
    Http
        { method = "POST"
        , url = options.url
        , body = options.body
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


put :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
put options =
    let
        decoder : Json.Decode.Decoder msg
        decoder =
            options.decoder
                |> Json.Decode.map (\props -> options.onResponse (Ok props))

        onFailure : Http.Error -> msg
        onFailure httpError =
            options.onResponse (Err httpError)
    in
    Http
        { method = "PUT"
        , url = options.url
        , body = options.body
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


delete :
    { url : String
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect msg
delete options =
    let
        decoder : Json.Decode.Decoder msg
        decoder =
            options.decoder
                |> Json.Decode.map (\props -> options.onResponse (Ok props))

        onFailure : Http.Error -> msg
        onFailure httpError =
            options.onResponse (Err httpError)
    in
    Http
        { method = "DELETE"
        , url = options.url
        , body = Http.emptyBody
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


request : Inertia.HttpRequest.Request msg -> Effect msg
request req =
    Http req



-- MAP


map : (a -> b) -> Effect a -> Effect b
map fn effect =
    case effect of
        None ->
            None

        Batch effects ->
            Batch (List.map (map fn) effects)

        SendMsg msg ->
            SendMsg (fn msg)

        Http req ->
            Http (Inertia.HttpRequest.map fn req)

        PushUrl url ->
            PushUrl url

        ReplaceUrl url ->
            ReplaceUrl url

        Back int ->
            Back int

        Forward int ->
            Forward int

        Load url ->
            Load url

        Reload ->
            Reload

        ReloadAndSkipCache ->
            ReloadAndSkipCache
