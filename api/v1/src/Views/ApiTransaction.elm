module Views.ApiTransaction exposing (..)

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


pageApiTransaction : Model -> List (Html Msg)
pageApiTransaction model =
    let
        description =
            div [] [ Html.text "This retrieves the transaction specified by the transaction id as Json" ]

        ex = """{"status":"success","result":{"id":"da2d2ef81e1ca3f4e1fee7ba06bcb93860349d67d93e066554e17b3fc1c4b5bc","action":"head","senders":[],"recipients":[{"address":"VDBjMTlkMWM0NTZhYmE3ZjdmYmVkMDgwMWFhZTMyMDRhMTUzNjFhYWUwYzk3ODQ5","amount":2500},{"address":"VDAxNmM1OGVkNmYyNzI2NzcyYjYzODRmMzJmMDkzODhjMTczNWI0NDFjZGM5ZTIz","amount":7500}],"message":"0","token":"SHARI","prev_hash":"0","sign_r":"0","sign_s":"0"}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiTransaction
            , Grid.col [ Col.md9 ]
                [ documentation ApiTransaction model.apiUrlT1 model.apiResponse "Transaction" description "GET" "api/v1/transaction/{:id}" "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/transaction/{:id}" ex model.error
                ]
            ]
        ]
