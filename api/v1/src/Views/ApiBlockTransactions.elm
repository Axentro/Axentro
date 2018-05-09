module Views.ApiBlockTransactions exposing (..)

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


pageApiBlockTransactions : Model -> List (Html Msg)
pageApiBlockTransactions model =
    let
        description =
            div [] [ Html.text "This retrieves the transactions for the block specified at index as Json" ]

        ex =
            """{"status":"success","result":[]}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiBlockTransactions
            , Grid.col [ Col.md9 ]
                [ documentation ApiBlockTransactions model.apiUrlB6 model.apiResponse "Block Transactions" description "GET" "api/v1/block/{:index}/transactions" "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/block/0/transactions" ex model.error
                ]
            ]
        ]
