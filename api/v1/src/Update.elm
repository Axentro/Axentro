module Update exposing (..)

import Messages exposing (Msg(..))
import Models exposing (Model)
import Navi exposing (urlUpdate)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChange location ->
            urlUpdate location model

        NavMsg state ->
            ( { model | navState = state }
            , Cmd.none
            )