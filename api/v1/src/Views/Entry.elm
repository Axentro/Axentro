module Views.Entry exposing (..)

import Html exposing (..)
import Html.Events exposing (onClick)
import Messages exposing (Msg(ChangeViewState), ViewState(CreateNewWallet1))
import Models exposing (Model)
import Views.Common exposing (title)


view : Model -> Html Msg
view model =
    div []
        [ title
        , ul []
            [ li [] [ button [ onClick (ChangeViewState CreateNewWallet1) ] [ text "Create new wallet" ] ]
            , li [] [ text "Import wallet from an Address" ]
            , li [] [ text "Import an encrypted wallet" ]
            ]
        ]
