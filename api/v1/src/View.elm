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
import Views.ApiDomainConfirmed exposing (pageApiDomainConfirmed)
import Views.ApiDomainConfirmedToken exposing (pageApiDomainConfirmedToken)
import Views.ApiDomainTransactions exposing (pageApiDomainTransactions)
import Views.ApiDomainUnconfirmed exposing (pageApiDomainUnconfirmed)
import Views.ApiDomainUnconfirmedToken exposing (pageApiDomainUnconfirmedToken)
import Views.ApiOverview exposing (pageApiOverview)
import Views.ApiBlockChain exposing (pageApiBlockChain)
import Views.ApiBlockChainHeader exposing (pageApiBlockChainHeader)
import Views.ApiBlockChainSize exposing (pageApiBlockChainSize)
import Views.ApiBlockHeader exposing (pageApiBlockHeader)
import Views.ApiBlockTransactions exposing (pageApiBlockTransactions)
import Views.ApiScarsConfirmed exposing (pageApiScarsConfirmed)
import Views.ApiScarsSales exposing (pageApiScarsSales)
import Views.ApiScarsUnconfirmed exposing (pageApiScarsUnconfirmed)
import Views.ApiTransaction exposing (pageApiTransaction)
import Views.ApiTransactionBlock exposing (pageApiTransactionBlock)
import Views.ApiTransactionBlockHeader exposing (pageApiTransactionBlockHeader)
import Views.ApiTransactionConfirmations exposing (pageApiTransactionConfirmations)
import Views.ApiTransactionCreate exposing (pageApiTransactionCreate)
import Views.ApiTransactionCreateUnsigned exposing (pageApiTransactionCreateUnsigned)
import Views.ApiTransactionFees exposing (pageApiTransactionFees)


view : Model -> Html Msg
view model =
    div []
        [ menu model
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
            [
--            Navbar.itemLink [ href "#getting-started" ] [ text "Getting started" ] This is for later - a guide to creating dApps / stuff using the API
             Navbar.itemLink [ href "#api-overview" ] [ text "Api Overview" ]
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

            ApiTransactionCreateUnsigned ->
                pageApiTransactionCreateUnsigned model

            ApiTransactionCreate ->
                pageApiTransactionCreate model

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

            ApiDomainTransactions ->
                pageApiDomainTransactions model

            ApiDomainConfirmed ->
                pageApiDomainConfirmed model

            ApiDomainConfirmedToken ->
                pageApiDomainConfirmedToken model

            ApiDomainUnconfirmed ->
                pageApiDomainUnconfirmed model

            ApiDomainUnconfirmedToken ->
                pageApiDomainUnconfirmedToken model

            ApiScarsSales ->
                pageApiScarsSales model

            ApiScarsConfirmed ->
                pageApiScarsConfirmed model

            ApiScarsUnconfirmed ->
                pageApiScarsUnconfirmed model

            NotFound ->
                pageNotFound


pageNotFound : List (Html Msg)
pageNotFound =
    [ h1 [] [ text "Not found" ]
    , text "SOrry couldn't find that page"
    ]


pageGettingStarted : Model -> List (Html Msg)
pageGettingStarted model =
    [ h2 [] [ text "Getting started" ] ]
