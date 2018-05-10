module Views.ApiAddressUnconfirmedToken exposing (..)

import Html.Events exposing (onClick, onInput)
import Json.PrettyPrint
import Views.TableHelper exposing (docTable)
import Views.ApiLeftNav exposing (apiLeftNav)
import Html exposing (..)
import Html.Attributes exposing (..)
import Models exposing (Model)
import Bootstrap.Navbar as Navbar
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Button as Button
import Bootstrap.ListGroup as Listgroup
import Bootstrap.Modal as Modal
import Bootstrap.Table as Table
import Bootstrap.Alert as Alert
import Bootstrap.Form.Textarea as TextArea
import Bootstrap.Form.Input as Input
import Messages exposing (Method(GET), Msg(..), Page(..))
import Views.ApiDocumentationHelper exposing (documentation)


pageApiAddressUnconfirmedToken : Model -> List (Html Msg)
pageApiAddressUnconfirmedToken model =
    let
        description =
            div [] [ Html.text "This retrieves amounts of unconfirmed tokens for the specified token for an address as Json" ]

        ex = """{"status":"success","result":{"confirmed":false,"pairs":[{"token":"EAGLE","amount":100000}]}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiAddressUnconfirmedToken
            , Grid.col [ Col.md9 ]
                [ documentation ApiAddressUnconfirmedToken model.apiUrlA5 Nothing model.apiResponse "Address Unconfirmed Token" description "GET" "api/v1/address/{:address}/unconfirmed/{:token}" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/address/{:address}/unconfirmed/{:token}" ex model.error
                ]
            ]
        ]
