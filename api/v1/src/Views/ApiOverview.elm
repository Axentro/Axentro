module Views.ApiOverview exposing (..)

import Html exposing (..)
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
import Views.Block exposing (overviewBlockSection)
import Views.BlockChain exposing (overviewBlockChainSection)

pageApiOverview : Model -> List (Html Msg)
pageApiOverview model =
    [ br [] []
    , Card.config [ Card.outlineDark ]
        |> Card.headerH4 [] [ text "API Overview" ]
        |> Card.block []
            [ Block.text [] [ text "The following information gives an overview of the SushiChain API" ]
            ]
        |> Card.view
    , hr [] []
    , Grid.row [] [ Grid.col [] overviewBlockChainSection ]
    , Grid.row [] [ Grid.col [] overviewBlockSection ]
    ]


apiOverviewTable : Table.TBody msg -> Html.Html msg
apiOverviewTable tableBody =
    Table.table
        { options = [ Table.bordered ]
        , thead = apiOverviewThead []
        , tbody = tableBody
        }


apiOverviewThead : List (Table.TableHeadOption msg) -> Table.THead msg
apiOverviewThead options =
    Table.thead options
        [ Table.tr []
            [ Table.th [] [ Html.text "Method" ]
            , Table.th [] [ Html.text "Url" ]
            , Table.th [] [ Html.text "Notes" ]
            ]
        ]