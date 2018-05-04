module Views.View exposing (..)

import Html exposing (..)
import Html.Events exposing (onClick)
import Messages exposing (Msg(..), ViewState(..))
import Models exposing (Model)
import Views.Entry as Entry
import Views.CreateNewWallet1 as CreateNewWallet1
import Views.CreateNewWallet2 as CreateNewWallet2


view : Model -> Html Msg
view model =
    case model.currentViewState of
        CreateNewWallet1 ->
            CreateNewWallet1.view model
        CreateNewWallet2 ->
            CreateNewWallet2.view model
        _ ->
            Entry.view model

