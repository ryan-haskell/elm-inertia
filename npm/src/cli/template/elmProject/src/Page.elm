module Page exposing (Model, Msg, init, onPropsChanged, subscriptions, update, view)

import Browser exposing (Document)
import Effect exposing (Effect)
import Html
import Inertia exposing (PageObject)
import Json.Decode exposing (Value)
import Page.Dashboard
import Page.Login
import Page.Error404
import Page.Error500
import Shared
import Url exposing (Url)


type Model
    = Model_Dashboard { props : Page.Dashboard.Props, model : Page.Dashboard.Model }
    | Model_Login { props : Page.Login.Props, model : Page.Login.Model }
    | Model_Error404 { model : Page.Error404.Model }
    | Model_Error500 { error : Json.Decode.Error, model : Page.Error500.Model }


type Msg
    = Msg_Dashboard Page.Dashboard.Msg
    | Msg_Login Page.Login.Msg
    | Msg_Error404 Page.Error404.Msg
    | Msg_Error500 Page.Error500.Msg


init : Shared.Model -> Url -> PageObject Value -> ( Model, Effect Msg )
init shared url pageObject =
    case pageObject.component of
        "Dashboard" ->
            initForPage shared url pageObject <|
                { decoder = Page.Dashboard.decoder
                , init = Page.Dashboard.init
                , toModel = Model_Dashboard
                , toMsg = Msg_Dashboard
                }

        "Login" ->
            initForPage shared url pageObject <|
                { decoder = Page.Login.decoder
                , init = Page.Login.init
                , toModel = Model_Login
                , toMsg = Msg_Login
                }

        _ ->
            let
                ( pageModel, pageEffect ) =
                    Page.Error404.init shared url
            in
            ( Model_Error404 { model = pageModel }
            , Effect.map Msg_Error404 pageEffect
            )


update : Shared.Model -> Url -> PageObject Value -> Msg -> Model -> ( Model, Effect Msg )
update shared url pageObject msg model =
    case ( msg, model ) of
        ( Msg_Dashboard pageMsg, Model_Dashboard page ) ->
            let
                ( pageModel, pageEffect ) =
                    Page.Dashboard.update shared url page.props pageMsg page.model
            in
            ( Model_Dashboard { page | model = pageModel }
            , Effect.map Msg_Dashboard pageEffect
            )

        ( Msg_Login pageMsg, Model_Login page ) ->
            let
                ( pageModel, pageEffect ) =
                    Page.Login.update shared url page.props pageMsg page.model
            in
            ( Model_Login { page | model = pageModel }
            , Effect.map Msg_Login pageEffect
            )

        ( Msg_Error404 pageMsg, Model_Error404 page ) ->
            let
                ( pageModel, pageEffect ) =
                    Page.Error404.update shared url pageMsg page.model
            in
            ( Model_Error404 { page | model = pageModel }
            , Effect.map Msg_Error404 pageEffect
            )

        ( Msg_Error500 pageMsg, Model_Error500 page ) ->
            let
                ( pageModel, pageEffect ) =
                    Page.Error500.update shared url page.error pageMsg page.model
            in
            ( Model_Error500 { page | model = pageModel }
            , Effect.map Msg_Error500 pageEffect
            )

        _ ->
            ( model, Effect.none )


subscriptions : Shared.Model -> Url -> PageObject Value -> Model -> Sub Msg
subscriptions shared url pageObject model =
    case model of
        Model_Dashboard page ->
            Page.Dashboard.subscriptions shared url page.props page.model
                |> Sub.map Msg_Dashboard

        Model_Login page ->
            Page.Login.subscriptions shared url page.props page.model
                |> Sub.map Msg_Login

        Model_Error404 page ->
            Page.Error404.subscriptions shared url page.model
                |> Sub.map Msg_Error404

        Model_Error500 page ->
            Page.Error500.subscriptions shared url page.error page.model
                |> Sub.map Msg_Error500


view : Shared.Model -> Url -> PageObject Value -> Model -> Document Msg
view shared url pageObject model =
    case model of
        Model_Dashboard page ->
            Page.Dashboard.view shared url page.props page.model
                |> mapDocument Msg_Dashboard

        Model_Login page ->
            Page.Login.view shared url page.props page.model
                |> mapDocument Msg_Login

        Model_Error404 page ->
            Page.Error404.view shared url page.model
                |> mapDocument Msg_Error404

        Model_Error500 page ->
            Page.Error500.view shared url page.error page.model
                |> mapDocument Msg_Error500


onPropsChanged :
    Shared.Model
    -> Url
    -> PageObject Value
    -> Model
    -> ( Model, Effect Msg )
onPropsChanged shared url pageObject model =
    case model of
        Model_Dashboard page ->
            onPropsChangedForPage shared url pageObject page <|
                { decoder = Page.Dashboard.decoder
                , onPropsChanged = Page.Dashboard.onPropsChanged
                , toModel = Model_Dashboard
                , toMsg = Msg_Dashboard
                }

        Model_Login page ->
            onPropsChangedForPage shared url pageObject page <|
                { decoder = Page.Login.decoder
                , onPropsChanged = Page.Login.onPropsChanged
                , toModel = Model_Login
                , toMsg = Msg_Login
                }

        Model_Error404 page ->
            ( model, Effect.none )

        Model_Error500 page ->
            ( model, Effect.none )



-- HELPERS


mapDocument : (a -> b) -> Browser.Document a -> Browser.Document b
mapDocument fn doc =
    { title = doc.title
    , body = List.map (Html.map fn) doc.body
    }


onPropsChangedForPage shared url pageObject page options =
    case Json.Decode.decodeValue options.decoder pageObject.props of
        Ok props ->
            let
                ( pageModel, pageEffect ) =
                    options.onPropsChanged shared url props page.model
            in
            ( options.toModel { props = props, model = pageModel }
            , Effect.map options.toMsg pageEffect
            )

        Err jsonDecodeError ->
            let
                ( pageModel, pageEffect ) =
                    Page.Error500.init shared url jsonDecodeError
            in
            ( Model_Error500 { error = jsonDecodeError, model = pageModel }
            , Effect.map Msg_Error500 pageEffect
            )


initForPage shared url pageObject options =
    case Json.Decode.decodeValue options.decoder pageObject.props of
        Ok props ->
            let
                ( pageModel, pageEffect ) =
                    options.init shared url props
            in
            ( options.toModel { props = props, model = pageModel }
            , Effect.map options.toMsg pageEffect
            )

        Err jsonDecodeError ->
            let
                ( pageModel, pageEffect ) =
                    Page.Error500.init shared url jsonDecodeError
            in
            ( Model_Error500 { error = jsonDecodeError, model = pageModel }
            , Effect.map Msg_Error500 pageEffect
            )
