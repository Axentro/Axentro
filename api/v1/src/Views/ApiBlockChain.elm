module Views.ApiBlockChain exposing (..)

import Views.TableHelper exposing (docTable)
import Views.ApiLeftNav exposing (apiLeftNav)
import Html exposing (..)
import Html.Attributes exposing (href)
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
import Messages exposing (Msg(..), Page(..))


pageApiBlockChain : Model -> List (Html Msg)
pageApiBlockChain model =
    [ br [] []
    , Grid.row []
        [ apiLeftNav ApiBlockchain
        , Grid.col [ Col.md9 ] [ documentation ]
        ]
    ]


documentation =
    Card.config [ Card.outlineDark ]
        |> Card.headerH4 [] [ text "Blockchain" ]
        |> Card.block []
            [ Block.text [] [ div [] [
              p [] [ Html.text "This retrieves the entire blockchain as Json" ]
              , Html.h5 [] [ Html.text "Request" ]
              , docTable (callTableHeader []) (tBody "GET" "v1/blockchain")
              ]]
            ]
        |> Card.view



callTableHeader : List (Table.TableHeadOption msg) -> Table.THead msg
callTableHeader options =
    Table.thead options
        [ Table.tr []
            [ Table.th [] [ Html.text "Method" ]
            , Table.th [] [ Html.text "Url" ]
            ]
        ]

tBody req url =
 (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text req ]
                , Table.td [] [ Html.text url ]
                ]
            ]
        )


--Alert.simpleDark [] [ Alert.link [] [ Html.text "link" ] ]
