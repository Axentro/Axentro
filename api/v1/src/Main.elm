module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Messages exposing (Msg(..),Page(..))
import Navi exposing (urlUpdate)
import Navigation exposing (Location)
import Update exposing (update)
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

import Models exposing (Model)
import View exposing (view)


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { view = view
        , update = update
        , subscriptions = subscriptions
        , init = init
        }


init : Location -> ( Model, Cmd Msg )
init location =
    let
        ( navState, navCmd ) =
            Navbar.initialState NavMsg

        prefix = "http://localhost:3000/api/v1/"

        ( model, urlCmd ) =
            urlUpdate location { navState = navState, page = ApiOverview, error = "", apiResponse = ""
               , apiUrlB1 = (prefix ++ "blockchain")
               , apiUrlB2 = (prefix ++ "blockchain/header")
               , apiUrlB3 = (prefix ++ "blockchain/size")
               , apiUrlB4 = (prefix ++ "block/0")
               , apiUrlB5 = (prefix ++ "block/0/header")
               , apiUrlB6 = (prefix ++ "block/0/transactions")
               , apiUrlT1 = (prefix ++ "transaction/{:id}")
               , apiUrlT2 = (prefix ++ "transaction/{:id}/block")
               , apiUrlT3 = (prefix ++ "transaction/{:id}/block/header")
               , apiUrlT4 = (prefix ++ "transaction/{:id}/confirmations")
               , apiUrlT5 = (prefix ++ "transaction/fees")
               , apiUrlA1 = (prefix ++ "address/{:address}/transactions")
               , apiUrlA2 = (prefix ++ "address/{:address}/confirmed")
               , apiUrlA3 = (prefix ++ "address/{:addresss}/confirmed/{:token}")
               , apiUrlA4 = (prefix ++ "address/{:address}/unconfirmed")
               , apiUrlA5 = (prefix ++ "address/{:address}/unconfirmed/{:token}")
               , apiUrlD1 = (prefix ++ "domain/{:domain}/unconfirmed/{:token}")
               , apiUrlD2 = (prefix ++ "domain/{:domain}/unconfirmed/{:token}")
               , apiUrlD3 = (prefix ++ "domain/{:domain}/unconfirmed/{:token}")
               , apiUrlD4 = (prefix ++ "domain/{:domain}/unconfirmed/{:token}")
               , apiUrlD5 = (prefix ++ "domain/{:domain}/unconfirmed/{:token}")
               , apiUrlS1 = (prefix ++ "scars/sales")
               , apiUrlS2 = (prefix ++ "scars/{:domain}/confirmed")
               , apiUrlS3 = (prefix ++ "scars/{:domain}/unconfirmed")

                }
    in
        ( model, Cmd.batch [ urlCmd, navCmd ] )


subscriptions : Model -> Sub Msg
subscriptions model =
    Navbar.subscriptions model.navState NavMsg






