module Views.CreateNewWallet2 exposing (..)

import Html exposing (..)
import Html.Attributes exposing (type_)
import Html.Events exposing (..)
import Messages exposing (Msg(..), ViewState(..))
import Models exposing (Model)
import Views.Common exposing (title)


view : Model -> Html Msg
view model =
    div []
        [ title
        , h3 [] [ text "Recovery phrase" ]
        , div [] [ text "On the next screen you will see a 24 word phrase. This is your backup phrase. It can be used to restore a wallet." ]
        , div [] [ text "please make sure nobody views your screen or they could gain access to your funds"]
        , div [] [ input [ type_ "checkbox", onClick Acknowledge1 ] [] ]
        , div [] [ button [  ] [ text "Continue"]]
        ]
