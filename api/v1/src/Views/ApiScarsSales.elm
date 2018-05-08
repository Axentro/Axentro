module Views.ApiScarsSales exposing (..)

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


pageApiScarsSales : Model -> List (Html Msg)
pageApiScarsSales model =
    let
        description =
            div [] [ Html.text "This shows the list of domains for sale as Json" ]

        ex = """{"status":"success","result":[{"domain_name":"awesome.sc","address":"VDAxNmM1OGVkNmYyNzI2NzcyYjYzODRmMzJmMDkzODhjMTczNWI0NDFjZGM5ZTIz","status":1,"price":100},{"domain_name":"superdry.sc","address":"VDAxNmM1OGVkNmYyNzI2NzcyYjYzODRmMzJmMDkzODhjMTczNWI0NDFjZGM5ZTIz","status":1,"price":100}]}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiScarsSales
            , Grid.col [ Col.md9 ]
                [ documentation ApiScarsSales model.apiUrlS1 model.apiResponse "Scars Sales" description "GET" "v1/scars/sales" "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/v1/scars/sales" ex
                ]
            ]
        ]
