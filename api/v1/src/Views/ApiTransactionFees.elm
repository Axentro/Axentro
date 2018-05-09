module Views.ApiTransactionFees exposing (..)

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


pageApiTransactionFees : Model -> List (Html Msg)
pageApiTransactionFees model =
    let
        description =
            div [] [ Html.text "This gets the current transaction fees as json" ]

        ex = """{"status":"success","result":{"send":1,"scars_buy":100,"scars_sell":10,"scars_cancel":1,"create_token":1000}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiTransactionFees
            , Grid.col [ Col.md9 ]
                [ documentation ApiTransactionFees model.apiUrlT5 model.apiResponse "Transaction Fees" description "GET" "api/v1/transaction/fees" "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/transaction/fees" ex model.error
                ]
            ]
        ]
