module Navi exposing (..)

import Messages exposing (Msg, Page(..))
import Models exposing (Model)
import Navigation exposing (Location)
import UrlParser

urlUpdate : Navigation.Location -> Model -> ( Model, Cmd Msg )
urlUpdate location model =
    case decode location of
        Nothing ->
            ( { model | page = NotFound }, Cmd.none )

        Just route ->
            ( { model | page = route, apiResponse = "", apiBody = "", error = "" }, Cmd.none )


decode : Location -> Maybe Page
decode location =
    UrlParser.parseHash routeParser location


routeParser : UrlParser.Parser (Page -> a) a
routeParser =
    UrlParser.oneOf
        [ UrlParser.map ApiOverview UrlParser.top
        , UrlParser.map GettingStarted (UrlParser.s "getting-started")
        , UrlParser.map ApiOverview (UrlParser.s "api-overview")

        , UrlParser.map ApiBlockchain (UrlParser.s "api-blockchain")
        , UrlParser.map ApiBlockchainHeader (UrlParser.s "api-blockchain-header")
        , UrlParser.map ApiBlockchainSize (UrlParser.s "api-blockchain-size")
        , UrlParser.map ApiBlock (UrlParser.s "api-block")
        , UrlParser.map ApiBlockHeader (UrlParser.s "api-block-header")
        , UrlParser.map ApiBlockTransactions (UrlParser.s "api-block-transactions")

        , UrlParser.map ApiTransaction (UrlParser.s "api-transaction")
        , UrlParser.map ApiTransactionBlock (UrlParser.s "api-transaction-block")
        , UrlParser.map ApiTransactionBlockHeader (UrlParser.s "api-transaction-block-header")
        , UrlParser.map ApiTransactionConfirmations (UrlParser.s "api-transaction-confirmations")
        , UrlParser.map ApiTransactionFees (UrlParser.s "api-transaction-fees")
        , UrlParser.map ApiTransactionCreateUnsigned (UrlParser.s "api-transaction-create-unsigned")
        , UrlParser.map ApiTransactionCreate (UrlParser.s "api-transaction-create")

        , UrlParser.map ApiAddressTransactions (UrlParser.s "api-address-transactions")
        , UrlParser.map ApiAddressAmount (UrlParser.s "api-address-amount")
        , UrlParser.map ApiAddressAmountToken (UrlParser.s "api-address-amount-token")

        , UrlParser.map ApiDomainTransactions (UrlParser.s "api-domain-transactions")
        , UrlParser.map ApiDomainAmount (UrlParser.s "api-domain-amount")
        , UrlParser.map ApiDomainAmountToken (UrlParser.s "api-domain-amount-token")

        , UrlParser.map ApiScarsSales (UrlParser.s "api-scars-sales")
        , UrlParser.map ApiScarsDomain (UrlParser.s "api-scars-domain")

        , UrlParser.map ApiTokenList (UrlParser.s "api-token-list")
        ]