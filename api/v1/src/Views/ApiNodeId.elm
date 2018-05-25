module Views.ApiNodeId exposing (..)

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


pageApiNodeId : Model -> List (Html Msg)
pageApiNodeId model =
    let
        description =
            div [] [ Html.text "Show information about the specified node id" ]

        ex = """{"status":"success","result":{"id":"5756a3ed2b062e2f471de4bcccf5128c","host":"","port":-1,"ssl":false,"type":"testnet","is_private":true}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiNodeId
            , Grid.col [ Col.md9 ]
                [ documentation ApiNodeId model.apiUrlN2 Nothing model.apiResponse "Node Id" description "GET" "api/v1/node/{:id}" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/node/{:id}" ex model.error
                ]
            ]
        ]
