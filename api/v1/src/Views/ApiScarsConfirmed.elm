module Views.ApiScarsConfirmed exposing (..)

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


pageApiScarsConfirmed : Model -> List (Html Msg)
pageApiScarsConfirmed model =
    let
        description =
            div [] [ Html.text "This retrieves the confirmed status of the scars domain as Json" ]

        ex = """{"status":"success","result":{"resolved":false,"domain":{"domain_name":"sushichain.sc","address":"","status":-1,"price":0}}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiScarsConfirmed
            , Grid.col [ Col.md9 ]
                [ documentation ApiScarsConfirmed model.apiUrlS2 model.apiResponse "Address Confirmed" description "GET" "api/v1/scars/{:domain}/confirmed" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/scars/{:domain}/confirmed" ex model.error
                ]
            ]
        ]
