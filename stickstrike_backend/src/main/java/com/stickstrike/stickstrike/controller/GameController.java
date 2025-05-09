package com.stickstrike.stickstrike.controller;

import com.stickstrike.stickstrike.model.*;
import com.stickstrike.stickstrike.service.GameService;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Controller;

@Controller
public class GameController {
    private final GameService gameService;

    public GameController(GameService gameService) {
        this.gameService = gameService;
    }

    @MessageMapping("/join")
    @SendTo("/topic/game")
    public GameState joinGame(JoinRequest request) {
        return gameService.addPlayer(request.getPlayerId(), request.getPlayerName());
    }

    @MessageMapping("/move")
    @SendTo("/topic/game")
    public GameState movePlayer(MoveRequest request) {
        return gameService.updatePlayerPosition(
                request.getPlayerId(),
                request.getPosition(),
                request.getVelocity());
    }

    @MessageMapping("/hit")
    @SendTo("/topic/game")
    public GameState handleHit(HitRequest request) {
        return gameService.processHit(
                request.getAttackerId(),
                request.getTargetId(),
                request.getHitPoint());
    }
}