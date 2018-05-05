module Views.BlockChain exposing (..)

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
import Messages exposing (Msg(..))
import Views.ApiOverview exposing (apiOverviewTable)

overviewBlockChainSection =
    [ h3 [] [ text "Blockchain" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "" ] [ Html.text "v1/blockchain" ] ]
                , Table.td [] [ Html.text "full blockchain" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "" ] [ Html.text "v1/blockchain/headers" ] ]
                , Table.td [] [ Html.text "blockchain headers" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "" ] [ Html.text "v1/blockchain/size" ] ]
                , Table.td [] [ Html.text "blockchain size" ]
                ]
            ]
        )
    ]