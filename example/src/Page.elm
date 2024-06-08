module Page exposing (Model, Msg, init, onPropsChanged, subscriptions, update, view)

import Browser exposing (Document)
import Html
import Inertia exposing (PageObject)
import Inertia.Effect as Effect exposing (Effect)
import Json.Decode exposing (Value)
import Shared
import Url exposing (Url)


type Model
    = Model_Dashboard {}
    | Model_404 {}


type Msg
    = Msg_Dashboard {}
    | Msg_404 {}


init :
    Shared.Model
    -> Url
    -> PageObject Value
    -> ( Model, Effect Msg )
init shared url pageObject =
    case pageObject.component of
        "Dashboard/Index" ->
            ( Model_Dashboard {}, Effect.none )

        _ ->
            ( Model_404 {}, Effect.none )


update :
    Shared.Model
    -> Url
    -> PageObject Value
    -> Msg
    -> Model
    -> ( Model, Effect Msg )
update shared url pageObject msg model =
    case ( msg, model ) of
        ( Msg_Dashboard pageMsg, Model_Dashboard pageModel ) ->
            -- Pages.Dashboard.update...
            ( model, Effect.none )

        ( Msg_404 pageMsg, Model_404 pageModel ) ->
            -- Pages.Error404.update...
            ( model, Effect.none )

        _ ->
            ( model, Effect.none )


subscriptions : Shared.Model -> Url -> PageObject Value -> Model -> Sub Msg
subscriptions shared url pageObject model =
    case model of
        Model_Dashboard {} ->
            -- Pages.Dashboard.subscriptions...
            Sub.none

        Model_404 {} ->
            -- Pages.404.subscriptions...
            Sub.none


view : Shared.Model -> Url -> PageObject Value -> Model -> Document Msg
view shared url pageObject model =
    case model of
        Model_Dashboard {} ->
            -- Pages.Dashboard.subscriptions...
            { title = "Dashboard", body = [ Html.text "Dashboard " ] }

        Model_404 {} ->
            -- Pages.404.subscriptions...
            { title = "404", body = [ Html.text "404 " ] }


onPropsChanged :
    Shared.Model
    -> Url
    -> PageObject Value
    -> Model
    -> ( Model, Effect Msg )
onPropsChanged shared url pageObject model =
    case model of
        Model_Dashboard pageModel ->
            -- Pages.Dashboard.onPropsChanged...
            ( model, Effect.none )

        Model_404 pageModel ->
            -- Pages.Error404.onPropsChanged...
            ( model, Effect.none )
