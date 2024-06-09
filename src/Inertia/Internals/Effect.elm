module Inertia.Internals.Effect exposing (..)

import Inertia.Internals.Request exposing (Request)


type Effect custom msg
    = None
    | Batch (List (Effect custom msg))
    | SendMsg msg
    | Http (Request msg)
    | PushUrl String
    | ReplaceUrl String
    | Back Int
    | Forward Int
    | Load String
    | Reload
    | ReloadAndSkipCache
    | Custom custom


map :
    (custom1 -> custom2)
    -> (msg1 -> msg2)
    -> Effect custom1 msg1
    -> Effect custom2 msg2
map customFn fn effect =
    case effect of
        None ->
            None

        Batch effects ->
            Batch (List.map (map customFn fn) effects)

        SendMsg msg ->
            SendMsg (fn msg)

        Http req ->
            Http (Inertia.Internals.Request.map fn req)

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

        Custom props ->
            Custom (customFn props)
