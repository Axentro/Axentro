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
            ( { model | page = route }, Cmd.none )


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
        ]