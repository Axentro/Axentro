module Views.ApiTransactionConfirmations exposing (..)

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


pageApiTransactionConfirmations : Model -> List (Html Msg)
pageApiTransactionConfirmations model =
    let
        description =
            div [] [ Html.text "This retrieves the number of confirmations for the specified transaction id as Json" ]

        ex = """{"status":"success","result":{"confirmations":2425}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiTransactionConfirmations
            , Grid.col [ Col.md9 ]
                [ documentation ApiTransactionConfirmations model.apiUrlT4 Nothing model.apiResponse "Transaction Confirmations" description "GET" "api/v1/transaction/{:id}/confirmations" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/transaction/{:id}/confirmations" ex model.error
                ]
            ]
        ]
