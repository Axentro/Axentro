module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Navigation exposing (Location)
import UrlParser exposing ((</>))
import Bootstrap.Navbar as Navbar
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Button as Button
import Bootstrap.ListGroup as Listgroup
import Bootstrap.Modal as Modal
import Bootstrap.Table as Table
import Bootstrap.CDN as CDN


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { view = view
        , update = update
        , subscriptions = subscriptions
        , init = init
        }


type alias Model =
    { page : Page
    , navState : Navbar.State
    , modalVisibility : Modal.Visibility
    }


type Page
    = Home
    | GettingStarted
    | Modules
    | NotFound
    | ApiOverview


init : Location -> ( Model, Cmd Msg )
init location =
    let
        ( navState, navCmd ) =
            Navbar.initialState NavMsg

        ( model, urlCmd ) =
            urlUpdate location { navState = navState, page = Home, modalVisibility = Modal.hidden }
    in
        ( model, Cmd.batch [ urlCmd, navCmd ] )


type Msg
    = UrlChange Location
    | NavMsg Navbar.State
    | CloseModal
    | ShowModal


subscriptions : Model -> Sub Msg
subscriptions model =
    Navbar.subscriptions model.navState NavMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChange location ->
            urlUpdate location model

        NavMsg state ->
            ( { model | navState = state }
            , Cmd.none
            )

        CloseModal ->
            ( { model | modalVisibility = Modal.hidden }
            , Cmd.none
            )

        ShowModal ->
            ( { model | modalVisibility = Modal.shown }
            , Cmd.none
            )


urlUpdate : Navigation.Location -> Model -> ( Model, Cmd Msg )
urlUpdate location model =
    case decode location of
        Nothing ->
            ( { model | page = NotFound }, Cmd.none )

        Just route ->
            ( { model | page = route }, Cmd.none )


decode : Location -> Maybe Page
decode location =
    UrlParser.parseHash routeParser location


routeParser : UrlParser.Parser (Page -> a) a
routeParser =
    UrlParser.oneOf
        [ UrlParser.map Home UrlParser.top
        , UrlParser.map GettingStarted (UrlParser.s "getting-started")
        , UrlParser.map Modules (UrlParser.s "modules")
        , UrlParser.map ApiOverview (UrlParser.s "api-overview")
        ]


view : Model -> Html Msg
view model =
    div []
        [ CDN.stylesheet
        , menu model
        , mainContent model
        , modal model
        ]


menu : Model -> Html Msg
menu model =
    Navbar.config NavMsg
        |> Navbar.withAnimation
        |> Navbar.container
        |> Navbar.dark
        |> Navbar.brand [ href "#" ] [ text "SushiChain API" ]
        |> Navbar.items
            [ Navbar.itemLink [ href "#getting-started" ] [ text "Getting started" ]
--            , Navbar.itemLink [ href "#modules" ] [ text "Modules" ]
            , Navbar.itemLink [ href "#api-overview" ] [ text "Api Overview" ]
            ]
        |> Navbar.view model.navState


mainContent : Model -> Html Msg
mainContent model =
    Grid.container [] <|
        case model.page of
            Home ->
                pageHome model

            GettingStarted ->
                pageGettingStarted model

            Modules ->
                pageModules model

            ApiOverview ->
                pageApiOverview model

            NotFound ->
                pageNotFound


pageApiOverview : Model -> List (Html Msg)
pageApiOverview model =
    [ br [] []
    , Card.config [ Card.outlineDark ]
        |> Card.headerH4 [] [ text "API Overview" ]
        |> Card.block []
            [ Block.text [] [ text "The following information gives an overview of the SushiChain API" ]
            ]
        |> Card.view
    , hr [] []
    , Grid.row [] [ Grid.col [] overviewBlockChainSection ]
    , Grid.row [] [ Grid.col [] overviewBlockSection ]
    ]


--overviewBlockChainSection
overviewBlockChainSection =
    [ h3 [] [ text "Blockchain" ]
               , apiOverviewTable
                   (Table.tbody []
                       [ Table.tr []
                           [ Table.td [] [ Html.text "GET" ]
                           , Table.td [] [ a [ href "" ] [ Html.text "v1/blockchain" ] ]
                           , Table.td [] [ Html.text "full blockchain" ]
                           ]
                       , Table.tr []
                           [ Table.td [] [ Html.text "GET" ]
                           , Table.td [] [ a [ href "" ] [  Html.text "v1/blockchain/headers" ] ]
                           , Table.td [] [ Html.text "blockchain headers" ]
                           ]
                       , Table.tr []
                           [ Table.td [] [ Html.text "GET" ]
                           , Table.td [] [ a [ href "" ] [  Html.text "v1/blockchain/size" ] ]
                           , Table.td [] [ Html.text "blockchain size" ]
                           ]
                       ]
                   ) ]

overviewBlockSection =
    [ hr [] [], h3 [] [ text "Block" ]
               , apiOverviewTable
                   (Table.tbody []
                       [ Table.tr []
                           [ Table.td [] [ Html.text "GET" ]
                           , Table.td [] [ a [ href "" ] [ Html.text "v1/block{:index}" ] ]
                           , Table.td [] [ Html.text "full block at index" ]
                           ]
                       , Table.tr []
                           [ Table.td [] [ Html.text "GET" ]
                           , Table.td [] [ a [ href "" ] [  Html.text "v1/block/{:index}/header" ] ]
                           , Table.td [] [ Html.text "block header at index" ]
                           ]
                       , Table.tr []
                           [ Table.td [] [ Html.text "GET" ]
                           , Table.td [] [ a [ href "" ] [  Html.text "v1/block/{:index}/transactions" ] ]
                           , Table.td [] [ Html.text "transactions in block" ]
                           ]
                       ]
                   ) ]


apiOverviewTable : Table.TBody msg -> Html.Html msg
apiOverviewTable tableBody =
    Table.table
        { options = [ Table.bordered ]
        , thead = apiOverviewThead []
        , tbody = tableBody
        }


apiOverviewThead : List (Table.TableHeadOption msg) -> Table.THead msg
apiOverviewThead options =
    Table.thead options
        [ Table.tr []
            [ Table.th [] [ Html.text "Method" ]
            , Table.th [] [ Html.text "Url" ]
            , Table.th [] [ Html.text "Notes" ]
            ]
        ]


pageHome : Model -> List (Html Msg)
pageHome model =
    [ h1 [] [ text "Home" ]
    , Grid.row []
        [ Grid.col []
            [ Card.config [ Card.outlinePrimary ]
                |> Card.headerH4 [] [ text "Getting started" ]
                |> Card.block []
                    [ Block.text [] [ text "Getting started is real easy. Just click the start button." ]
                    , Block.custom <|
                        Button.linkButton
                            [ Button.primary, Button.attrs [ href "#getting-started" ] ]
                            [ text "Start" ]
                    ]
                |> Card.view
            ]
        , Grid.col []
            [ Card.config [ Card.outlineDanger ]
                |> Card.headerH4 [] [ text "Modules" ]
                |> Card.block []
                    [ Block.text [] [ text "Check out the modules overview" ]
                    , Block.custom <|
                        Button.linkButton
                            [ Button.primary, Button.attrs [ href "#modules" ] ]
                            [ text "Module" ]
                    ]
                |> Card.view
            ]
        ]
    ]


pageGettingStarted : Model -> List (Html Msg)
pageGettingStarted model =
    [ h2 [] [ text "Getting started" ]
    , Button.button
        [ Button.success
        , Button.large
        , Button.block
        , Button.attrs [ onClick ShowModal ]
        ]
        [ text "Click me" ]
    ]


pageModules : Model -> List (Html Msg)
pageModules model =
    [ h1 [] [ text "Modules" ]
    , Listgroup.ul
        [ Listgroup.li [] [ text "Alert" ]
        , Listgroup.li [] [ text "Badge" ]
        , Listgroup.li [] [ text "Card" ]
        ]
    ]


pageNotFound : List (Html Msg)
pageNotFound =
    [ h1 [] [ text "Not found" ]
    , text "SOrry couldn't find that page"
    ]


modal : Model -> Html Msg
modal model =
    Modal.config CloseModal
        |> Modal.small
        |> Modal.h4 [] [ text "Getting started ?" ]
        |> Modal.body []
            [ Grid.containerFluid []
                [ Grid.row []
                    [ Grid.col
                        [ Col.xs6 ]
                        [ text "Col 1" ]
                    , Grid.col
                        [ Col.xs6 ]
                        [ text "Col 2" ]
                    ]
                ]
            ]
        |> Modal.view model.modalVisibility
