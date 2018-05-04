module Views.CreateNewWallet1 exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Messages exposing (Msg(..), ViewState(..))
import Models exposing (Model)
import Views.Common exposing (title)


view : Model -> Html Msg
view model =
    div []
        [ title
        , h3 [] [ text "create new wallet" ]
        , div [] [ text "Choose a name for the wallet" ]
        , div [] [ input [ onInput SetWalletName ] [] ]
        , br [] []
        , div [] [ text "Choose a password for the wallet" ]
        , div [] [ input [ onInput SetWalletPassword ] [] ]
        , div [] [ text "Repeat the password" ]
        , div [] [ input [ onInput SetWalletPasswordConfirm ] [] ]
        , div [] [ button [ onClick (ChangeViewState CreateNewWallet2) ] [ text "Create"]]
        ]
