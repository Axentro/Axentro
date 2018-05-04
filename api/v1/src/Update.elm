module Update exposing (..)

import Messages exposing (Msg(..))
import Models exposing (Model, newModel)


init : ( Model, Cmd Msg )
init =
    ( newModel, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ChangeViewState state ->
            ( { model | currentViewState = state }, Cmd.none )

        SetWalletName name ->
            let
                m =
                    model.newWalletModel

                u =
                    { m | name = name }
            in
                ( { model | newWalletModel = u }, Cmd.none )

        SetWalletPassword password ->
            let
                m =
                    model.newWalletModel

                u =
                    { m | password = password }
            in
                ( { model | newWalletModel = u }, Cmd.none )

        SetWalletPasswordConfirm passwordConfirm ->
            let
                m =
                    model.newWalletModel

                u =
                    { m | passwordConfirm = passwordConfirm }
            in
                ( { model | newWalletModel = u }, Cmd.none )

        Acknowledge1 ->
             let
              _ = Debug.log "ack: " ""
             in
             (model, Cmd.none)