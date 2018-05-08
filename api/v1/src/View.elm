module View exposing (..)

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
import Html exposing (..)
import Html.Attributes exposing (..)
import Messages exposing (Msg(..), Page(..))
import Models exposing (Model)
import Views.ApiAddressConfirmed exposing (pageApiAddressConfirmed)
import Views.ApiAddressConfirmedToken exposing (pageApiAddressConfirmedToken)
import Views.ApiAddressTransactions exposing (pageApiAddressTransactions)
import Views.ApiAddressUnconfirmed exposing (pageApiAddressUnconfirmed)
import Views.ApiAddressUnconfirmedToken exposing (pageApiAddressUnconfirmedToken)
import Views.ApiBlock exposing (pageApiBlock)
import Views.ApiOverview exposing (pageApiOverview)
import Views.ApiBlockChain exposing (pageApiBlockChain)
import Views.ApiBlockChainHeader exposing (pageApiBlockChainHeader)
import Views.ApiBlockChainSize exposing (pageApiBlockChainSize)
import Views.ApiBlockHeader exposing (pageApiBlockHeader)
import Views.ApiBlockTransactions exposing (pageApiBlockTransactions)
import Views.ApiTransaction exposing (pageApiTransaction)
import Views.ApiTransactionBlock exposing (pageApiTransactionBlock)
import Views.ApiTransactionBlockHeader exposing (pageApiTransactionBlockHeader)
import Views.ApiTransactionConfirmations exposing (pageApiTransactionConfirmations)
import Views.ApiTransactionFees exposing (pageApiTransactionFees)


view : Model -> Html Msg
view model =
    div []
        [ CDN.stylesheet
        , menu model
        , mainContent model
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
            , Navbar.itemLink [ href "#api-overview" ] [ text "Api Overview" ]
            ]
        |> Navbar.view model.navState


mainContent : Model -> Html Msg
mainContent model =
    Grid.container [] <|
        case model.page of
            GettingStarted ->
                pageGettingStarted model

            ApiOverview ->
                pageApiOverview model

            ApiBlockchain ->
                pageApiBlockChain model

            ApiBlockchainHeader ->
                pageApiBlockChainHeader model

            ApiBlockchainSize ->
                pageApiBlockChainSize model

            ApiBlock ->
                pageApiBlock model

            ApiBlockHeader ->
                pageApiBlockHeader model

            ApiBlockTransactions ->
                pageApiBlockTransactions model

            ApiTransaction ->
                pageApiTransaction model

            ApiTransactionBlock ->
                pageApiTransactionBlock model

            ApiTransactionBlockHeader ->
                pageApiTransactionBlockHeader model

            ApiTransactionConfirmations ->
                pageApiTransactionConfirmations model

            ApiTransactionFees ->
                pageApiTransactionFees model

            ApiAddressTransactions ->
                pageApiAddressTransactions model

            ApiAddressConfirmed ->
                pageApiAddressConfirmed model

            ApiAddressConfirmedToken ->
                pageApiAddressConfirmedToken model

            ApiAddressUnconfirmed ->
                pageApiAddressUnconfirmed model

            ApiAddressUnconfirmedToken ->
                pageApiAddressUnconfirmedToken model

            NotFound ->
                pageNotFound


pageNotFound : List (Html Msg)
pageNotFound =
    [ h1 [] [ text "Not found" ]
    , text "SOrry couldn't find that page"
    ]


pageGettingStarted : Model -> List (Html Msg)
pageGettingStarted model =
    [ h2 [] [ text "Getting started" ]

    --    , Button.button
    --        [ Button.success
    --        , Button.large
    --        , Button.block
    --        , Button.attrs [ onClick ShowModal ]
    --        ]
    --        [ text "Click me" ]
    ]
