module Inertia.Effect exposing
    ( Effect
    , none, batch
    , sendMsg
    , get, post, put, patch, delete
    , request
    , pushUrl, replaceUrl, back, forward
    , load, reload, reloadAndSkipCache
    , custom
    , map
    , switch
    )

{-| This module provides a default `Effect` implementation. It comes with helpers
for working with Inertia HTTP requests.

Most applications will want custom effects, which can be specified using [Inertia.Effect.custom](#custom)

Rather than using `Inertia.Effect` directly, we recommend creating your own `Effect` module, and using this module as a starting point:

    -- module Effect exposing (Effect, ...)
    --     ( Effect
    --     , none, batch
    --     , ...
    --     )


    import Inertia.Effect

    type alias Effect msg =
        Inertia.Effect.Effect () msg

    none : Effect msg
    none =
        Inertia.Effect.none

    batch : List (Effect msg) -> Effect msg
    batch effects =
        Inertia.Effect.batch effects

    -- ...


# **Effects**

@docs Effect
@docs none, batch
@docs sendMsg


# **Inertia HTTP**

Inertia [expects special headers](https://inertiajs.com/the-protocol) to be present when making HTTP requests.

When you use any of the HTTP effects below, those headers (like `X-Inertia`, `X-Inertia-Version`, etc) will be
automatically included with your HTTP request.

Each response expects [Inertia's standard JSON response](https://inertiajs.com/the-protocol#inertia-responses),
and `Inertia.program` automatically handles redirecting to the correct page, when the server responds with a
different `"component"`.

**Note:** Each function below expects a JSON decoder. This decoder will only run if the component hasn't changed.

@docs get, post, put, patch, delete
@docs request


# **Browser Navigation**

@docs pushUrl, replaceUrl, back, forward
@docs load, reload, reloadAndSkipCache


# **Defining custom effects**

@docs custom


# **Transforming effects**

@docs map


# **Testing effects**

@docs switch

-}

import Http
import Inertia.Internals.Effect as Effect
import Inertia.Internals.Request exposing (Request)
import Json.Decode
import Json.Encode
import Url exposing (Url)


{-| Represents a side effect you want to run in an `init` or `update` function.

Just like Elm's core `Cmd` type, but provides the ability to make app-specific
side effects that are fully testable with testing tools like
[elm-program-test](https://package.elm-lang.org/packages/avh4/elm-program-test/latest/).

-}
type alias Effect custom msg =
    Effect.Effect custom msg


{-| Allows you to define custom effects for your application.

    import Inertia.Effect

    type alias Effect msg =
        Inertia.Effect.Effect (CustomEffect msg) msg

    type CustomEffect msg
        = SendDelayedMsg Float msg

    sendDelayedMsg : Float -> msg -> Effect msg
    sendDelayedMsg delay msg =
        Inertia.Effect.custom (SendDelayedMsg delay msg)

-}
custom : custom -> Effect custom msg
custom props =
    Effect.Custom props



-- BASICS


{-| Perform no side effects. Commonly used with `init` and `update` to indicate
no side effects should occur.

    doNothing : Effect custom msg
    doNothing =
        Effect.none

-}
none : Effect custom msg
none =
    Effect.None


{-| Perform multiple effects at once.

    sendHttpGetAndReload : Effect Msg
    sendHttpGetAndReload =
        Effect.batch
            [ Effect.get { ... }
            , Effect.reload
            ]

-}
batch : List (Effect custom msg) -> Effect custom msg
batch effects =
    Effect.Batch effects



-- MESSAGES


{-| Sends a message as a side effect.

    type Msg
        = ReportError Int

    effect : Effect Msg
    effect =
        Effect.sendMsg (ReportError 404)

-}
sendMsg : msg -> Effect custom msg
sendMsg msg =
    Effect.SendMsg msg



-- HTTP


{-| Send a `GET` request to an Inertia endpoint.

**Note:** When navigating programmatically to another
inertia page, prefer the **[pushUrl](#pushUrl)** effect instead.

    type Msg
        = ServerResponded (Result Http.Error ())

    effect : Effect Msg
    effect =
        Effect.get
            { url = "/dashboard"
            , decoder = Json.Decode.succeed ()
            , onResponse = ServerResponded
            }

-}
get :
    { url : String
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect custom msg
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
    Effect.Http
        { method = "GET"
        , url = options.url
        , body = Http.emptyBody
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


{-| Send a `POST` request to an Inertia endpoint.

    type Msg
        = OrganizationCreated (Result Http.Error Props)

    type alias Props =
        { errorName : Maybe String
        , errorEmail : Maybe String
        }

    decoder : Json.Decode.Decoder Props
    decoder =
        Json.Decode.map Props
            (Json.Decode.at [ "errors", "name" ]
                (Json.Decode.maybe Json.Decode.string)
            )
            (Json.Decode.at [ "errors", "email" ]
                (Json.Decode.maybe Json.Decode.string)
            )

    createOrganization : Model -> Effect Msg
    createOrganization model =
        let
            form : Json.Encode.Value
            form =
                Json.Encode.object
                    [ ( "name", model.name )
                    , ( "email", model.email )
                    , ( "phone", model.phone )
                    ]
        in
        Effect.post
            { url = "/organizations"
            , body = Http.jsonBody form
            , decoder = decoder
            , onResponse = OrganizationCreated
            }

-}
post :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect custom msg
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
    Effect.Http
        { method = "POST"
        , url = options.url
        , body = options.body
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


{-| Send a `PUT` request to an Inertia endpoint.

    type Msg
        = UserUpdated (Result Http.Error Props)

    updateUser : Props -> Model -> Effect Msg
    updateUser props model =
        let
            form : Json.Encode.Value
            form =
                Json.Encode.object
                    [ ( "name", model.name )
                    , ( "email", model.email )
                    , ( "phone", model.phone )
                    ]
        in
        Effect.put
            { url =
                Url.Builder.absolute
                    [ "users", props.id ]
                    []
            , body = Http.jsonBody form
            , decoder = decoder
            , onResponse = UserUpdated
            }

    type alias Props =
        { id : Int
        , name : String
        , email : Maybe String
        , phone : Maybe String
        }

    decoder : Json.Decode.Decoder Props
    decoder =
        Json.Decode.map Props
            (Json.Decode.at [ "user", "id" ] Json.Decode.int)
            (Json.Decode.at [ "user", "name" ] Json.Decode.string)
            (Json.Decode.at [ "user", "email" ]
                (Json.Decode.maybe Json.Decode.string)
            )
            (Json.Decode.at [ "user", "phone" ]
                (Json.Decode.maybe Json.Decode.string)
            )

-}
put :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect custom msg
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
    Effect.Http
        { method = "PUT"
        , url = options.url
        , body = options.body
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


{-| Send a `PATCH` request to an Inertia endpoint.

    type Msg
        = ContactUpdated (Result Http.Error Props)

    updateContact : Props -> Model -> Effect Msg
    updateContact props model =
        let
            form : Json.Encode.Value
            form =
                Json.Encode.object
                    [ ( "name", model.name )
                    , ( "email", model.email )
                    ]
        in
        Effect.patch
            { url =
                Url.Builder.absolute
                    [ "contacts", props.id ]
                    []
            , body = Http.jsonBody form
            , decoder = decoder
            , onResponse = ContactUpdated
            }

    type alias Props =
        { id : Int
        , name : String
        , email : Maybe String
        }

    decoder : Json.Decode.Decoder Props
    decoder =
        Json.Decode.map Props
            (Json.Decode.at [ "contact", "id" ] Json.Decode.int)
            (Json.Decode.at [ "contact", "name" ] Json.Decode.string)
            (Json.Decode.at [ "contact", "email" ]
                (Json.Decode.maybe Json.Decode.string)
            )

-}
patch :
    { url : String
    , body : Http.Body
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect custom msg
patch options =
    let
        decoder : Json.Decode.Decoder msg
        decoder =
            options.decoder
                |> Json.Decode.map (\props -> options.onResponse (Ok props))

        onFailure : Http.Error -> msg
        onFailure httpError =
            options.onResponse (Err httpError)
    in
    Effect.Http
        { method = "PATCH"
        , url = options.url
        , body = options.body
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


{-| Send a `DELETE` request to an Inertia endpoint.

    type Msg
        = OrganizationDeleted (Result Http.Error ())

    deleteOrganization : Props -> Effect Msg
    deleteOrganization props =
        Effect.delete
            { url = Url.Builder.absolute [ "organizations", props.id ] []
            , decoder = Json.Decode.succeed ()
            , onResponse = OrganizationDeleted
            }

-}
delete :
    { url : String
    , decoder : Json.Decode.Decoder props
    , onResponse : Result Http.Error props -> msg
    }
    -> Effect custom msg
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
    Effect.Http
        { method = "DELETE"
        , url = options.url
        , body = Http.emptyBody
        , decoder = decoder
        , onFailure = onFailure
        , headers = []
        , tracker = Nothing
        , timeout = Nothing
        }


{-| If you want to work with a different HTTP method, extra headers, specify timeouts, or track the progress
of a file upload, this function has the flexibility.

**Note:** This will still include the Inertia headers, any headers you specify will be added to
the request.

    type Msg
        = UserCreateProgress Http.Progress
        | UserCreated (Result Http.Error ())

    createUser : Model -> Effect Msg
    createUser model =
        Effect.request
            { method = "POST"
            , url = "/users"
            , body =
                Http.multipartBody
                    [ Http.stringPart "name" model.name
                    , Http.stringPart "email" model.email
                    , Http.filePart "avatar" model.avatar
                    ]
            , decoder = Json.Decode.succeed (UserCreated (Ok ()))
            , onFailure = Err >> UserCreated
            , headers = []
            , timeout = Nothing
            , tracker = Just "user-create"
            }

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Http.track "user-create" UserCreateProgress

-}
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
    -> Effect custom msg
request options =
    Effect.Http options



-- URL NAVIGATION


{-| Change the URL, but do not trigger a page load.

This will add a new entry to the browser history.

    gotoDashboardPage : Effect custom msg
    gotoDashboardPage =
        Effect.pushUrl "/dashboard"

See [Browser.Navigation.pushUrl](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation#pushUrl).

-}
pushUrl : String -> Effect custom msg
pushUrl url =
    Effect.PushUrl url


{-| Change the URL, but do not trigger a page load.

This will not add a new entry to the browser history.

    gotoSettingsPage : Effect custom msg
    gotoSettingsPage =
        Effect.replaceUrl "/settings"

See [Browser.Navigation.replaceUrl](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation#replaceUrl)

-}
replaceUrl : String -> Effect custom msg
replaceUrl url =
    Effect.ReplaceUrl url


{-| Go back some number of pages. So back 1 goes back one page, and back 2 goes back two pages.

    goBack : Effect custom msg
    goBack =
        Effect.back 1

See [Browser.Navigation.back](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation#back)

-}
back : Int -> Effect custom msg
back int =
    Effect.Back int


{-| Go forward some number of pages. So forward 1 goes forward one page, and forward 2 goes forward two pages. If there are no more pages in the future, this will do nothing.

    goForwardThreePages : Effect custom msg
    goForwardThreePages =
        Effect.forward 3

See [Browser.Navigation.forward](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation#forward)

-}
forward : Int -> Effect custom msg
forward int =
    Effect.Forward int


{-| Leave the current page and load the given URL. **This always results in a page load**, even if the provided URL is the same as the current one.

    loadDashboard : Effect custom msg
    loadDashboard =
        Effect.load "/dashboard"

See [Browser.Navigation.load](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation#load)

-}
load : String -> Effect custom msg
load url =
    Effect.Load url


{-| Reload the current page. **This always results in a page load!**

    reloadCurrentPage : Effect custom msg
    reloadCurrentPage =
        Effect.reload

See [Browser.Navigation.reload](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation#reload)

-}
reload : Effect custom msg
reload =
    Effect.Reload


{-| Reload the current page without using the browser cache. **This always results in a page load!**

    hardReloadCurrentPage : Effect custom msg
    hardReloadCurrentPage =
        Effect.reloadAndSkipCache

See [Browser.Navigation.reloadAndSkipCache](https://package.elm-lang.org/packages/elm/browser/latest/Browser-Navigation#reloadAndSkipCache)

-}
reloadAndSkipCache : Effect custom msg
reloadAndSkipCache =
    Effect.ReloadAndSkipCache



-- TRANSFORMING EFFECTS


{-| Transform an effect of one type into another. Common when working with effects from pages.

    import Effect exposing (Effect)
    import Pages.Dashboard

    type Msg
        = Dashboard Pages.Dashboard.Msg

    dashboardPageEffect : Effect Pages.Dashboard.Msg
    dashboardPageEffect =
        Effect.none

    effect : Effect Msg
    effect =
        Effect.map Dashboard dashboardPageEffect

**Rather than using `Inertia.Effect.map` directly**, you'll want to create
your own map function in your custom `Effect` module.

Here's an example of implementing your own `Effect.map` when you're using a `CustomEffect`:

    import Inertia.Effect

    type alias Effect msg =
        Inertia.Effect.Effect (CustomEffect msg) msg

    map : (a -> b) -> Effect a -> Effect b
    map fn effect =
        Inertia.Effect.map (mapCustomEffect fn) fn

    type CustomEffect msg
        = SendDelayedMsg Float msg

    mapCustomEffect : (a -> b) -> CustomEffect a -> CustomEffect b
    mapCustomEffect fn customEffect =
        case customEffect of
            SendDelayedMsg delay msg ->
                SendDelayedMsg delay (fn msg)

-}
map :
    (custom1 -> custom2)
    -> (msg1 -> msg2)
    -> Effect custom1 msg1
    -> Effect custom2 msg2
map customFn fn effect =
    Effect.map customFn fn effect


{-| This function allows you to pattern match on the `Effect` type, without exposing the custom type variants.

It was created for folks that need to convert the `Effect Msg` into a simulated effect for use
with [elm-program-test](https://package.elm-lang.org/packages/avh4/elm-program-test/latest/ProgramTest#SimulatedEffect).

    import SimulatedEffect.Cmd

    toSimulatedEffect : Effect Msg -> ProgramTest.SimulatedEffect Msg
    toSimulatedEffect effect =
        Effect.switch effect
            { onNone = Cmd.none
            , onBatch = Cmd.batch (List.map toSimulatedEffect effects)
            , ...
            , onReloadAndSkipCache = ...
            }

-}
switch :
    Effect custom msg
    ->
        { onNone : value
        , onBatch : List (Effect custom msg) -> value
        , onSendMsg : msg -> value
        , onHttp : Request msg -> value
        , onPushUrl : String -> value
        , onReplaceUrl : String -> value
        , onBack : Int -> value
        , onForward : Int -> value
        , onLoad : String -> value
        , onReload : value
        , onReloadAndSkipCache : value
        , onCustom : custom -> value
        }
    -> value
switch effect handlers =
    case effect of
        Effect.None ->
            handlers.onNone

        Effect.Batch effects ->
            handlers.onBatch effects

        Effect.SendMsg msg ->
            handlers.onSendMsg msg

        Effect.Http req ->
            handlers.onHttp req

        Effect.PushUrl url ->
            handlers.onPushUrl url

        Effect.ReplaceUrl url ->
            handlers.onReplaceUrl url

        Effect.Back int ->
            handlers.onBack int

        Effect.Forward int ->
            handlers.onForward int

        Effect.Load url ->
            handlers.onLoad url

        Effect.Reload ->
            handlers.onReload

        Effect.ReloadAndSkipCache ->
            handlers.onReloadAndSkipCache

        Effect.Custom props ->
            handlers.onCustom props
